-- Transactional email: locale on profiles, outbox queue, signup + approval emails

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS preferred_locale TEXT NOT NULL DEFAULT 'en';

CREATE TABLE IF NOT EXISTS public.email_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
    to_email TEXT NOT NULL,
    template TEXT NOT NULL,
    locale TEXT NOT NULL DEFAULT 'en',
    variables JSONB NOT NULL DEFAULT '{}'::JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_outbox_pending
    ON public.email_outbox (status, created_at)
    WHERE status = 'pending';

ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY email_outbox_admin ON public.email_outbox
    FOR SELECT USING (public.is_admin());

-- Infer tr for Istanbul / Turkish preference, otherwise en
CREATE OR REPLACE FUNCTION public.infer_user_locale(
    p_meta_locale TEXT,
    p_city TEXT,
    p_languages TEXT[]
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN lower(coalesce(p_meta_locale, '')) IN ('tr', 'turkish', 'türkçe') THEN 'tr'
        WHEN lower(coalesce(p_city, '')) LIKE '%istanbul%'
            OR lower(coalesce(p_city, '')) IN ('kadıköy', 'kadikoy', 'beşiktaş', 'besiktas', 'şişli', 'sisli') THEN 'tr'
        WHEN p_languages IS NOT NULL AND EXISTS (
            SELECT 1 FROM unnest(p_languages) AS lang
            WHERE lower(lang) LIKE '%turk%'
        ) THEN 'tr'
        ELSE 'en'
    END;
$$;

CREATE OR REPLACE FUNCTION public.queue_transactional_email(
    p_user_id UUID,
    p_to_email TEXT,
    p_template TEXT,
    p_locale TEXT,
    p_variables JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF coalesce(trim(p_to_email), '') = '' THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.email_outbox (user_id, to_email, template, locale, variables, status)
    VALUES (
        p_user_id,
        lower(trim(p_to_email)),
        p_template,
        CASE WHEN lower(coalesce(p_locale, 'en')) LIKE 'tr%' THEN 'tr' ELSE 'en' END,
        coalesce(p_variables, '{}'::JSONB),
        'pending'
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.queue_transactional_email(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.queue_transactional_email(UUID, TEXT, TEXT, TEXT, JSONB) TO service_role;

-- Dispatch pending row to Edge Function (optional — set DB settings in EMAIL_SETUP.md)
CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        RETURN NEW;
    END;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 THEN
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/send-email',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object('outbox_id', NEW.id::TEXT)
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS email_outbox_dispatch ON public.email_outbox;
CREATE TRIGGER email_outbox_dispatch
    AFTER INSERT ON public.email_outbox
    FOR EACH ROW
    EXECUTE FUNCTION public.dispatch_email_outbox();

-- Signup: profile + creator + admin task + welcome email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_locale TEXT;
    v_city TEXT;
    v_name TEXT;
    v_handle TEXT;
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_locale := public.infer_user_locale(
        NEW.raw_user_meta_data ->> 'locale',
        v_city,
        NULL
    );

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (
        NEW.id,
        NEW.email,
        'creator',
        'under_review',
        v_locale
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, languages)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END
    );

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
    VALUES (
        'creator_application',
        NEW.id,
        'New creator application',
        coalesce(nullif(v_handle, ''), NEW.email, 'Unknown'),
        'High'
    );

    PERFORM public.queue_transactional_email(
        NEW.id,
        NEW.email,
        'welcome_application',
        v_locale,
        jsonb_build_object(
            'name', v_name,
            'city', v_city,
            'site_url', 'https://marvisociety.com'
        )
    );

    RETURN NEW;
END;
$$;

-- Approval email when admin approves creator application
CREATE OR REPLACE FUNCTION public.resolve_admin_task(p_task_id UUID, p_action TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task public.admin_tasks%ROWTYPE;
    v_approve BOOLEAN := lower(trim(p_action)) IN ('approve', 'approved');
    v_email TEXT;
    v_locale TEXT;
    v_name TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    SELECT * INTO v_task FROM public.admin_tasks WHERE id = p_task_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    IF v_task.status <> 'open' THEN
        RETURN;
    END IF;

    UPDATE public.admin_tasks
    SET
        status = CASE WHEN v_approve THEN 'approved'::public.admin_task_status ELSE 'rejected'::public.admin_task_status END,
        resolved_at = now(),
        assigned_admin_id = auth.uid()
    WHERE id = p_task_id;

    CASE v_task.type
        WHEN 'creator_application' THEN
            UPDATE public.profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

            UPDATE public.creator_profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE user_id = v_task.subject_id;

            IF v_approve THEN
                SELECT p.email, p.preferred_locale, cp.full_name
                INTO v_email, v_locale, v_name
                FROM public.profiles p
                LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
                WHERE p.id = v_task.subject_id;

                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Üyeliğiniz onaylandı' ELSE 'Membership approved' END,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr'
                        THEN 'Marvi Society başvurunuz onaylandı. Keşfet sekmesinden canlı etkinliklere göz atın.'
                        ELSE 'Your Marvi Society creator application was approved. Explore live events now.'
                    END,
                    'membership',
                    'checkmark.seal.fill',
                    'emerald',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );

                PERFORM public.queue_transactional_email(
                    v_task.subject_id,
                    v_email,
                    'membership_approved',
                    coalesce(v_locale, 'en'),
                    jsonb_build_object(
                        'name', coalesce(nullif(v_name, ''), 'Creator'),
                        'site_url', 'https://marvisociety.com',
                        'app_url', 'https://marvisociety.com/creators'
                    )
                );
            END IF;

        WHEN 'venue_application' THEN
            UPDATE public.venue_profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

        WHEN 'campaign_review' THEN
            UPDATE public.offers
            SET status = CASE WHEN v_approve THEN 'live'::public.offer_status ELSE 'draft'::public.offer_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

        WHEN 'proof_review' THEN
            UPDATE public.proof_submissions
            SET
                status = CASE WHEN v_approve THEN 'approved'::public.proof_status ELSE 'flagged'::public.proof_status END,
                reviewed_at = now()
            WHERE booking_id = v_task.subject_id
              AND status = 'pending';

            UPDATE public.bookings
            SET proof_status = CASE WHEN v_approve THEN 'approved'::public.proof_status ELSE 'flagged'::public.proof_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;
    END CASE;
END;
$$;
