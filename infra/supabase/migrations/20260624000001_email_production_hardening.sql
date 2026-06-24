-- Email production hardening: dispatch diagnostics, review account skip, contact log, retry helper

-- ---------------------------------------------------------------------------
-- 1. Contact messages (audit trail; notification goes to email_outbox)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.contact_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    subject TEXT NOT NULL DEFAULT 'General support',
    message TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'web',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS contact_messages_insert_public ON public.contact_messages;
CREATE POLICY contact_messages_insert_public ON public.contact_messages
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS contact_messages_admin_read ON public.contact_messages;
CREATE POLICY contact_messages_admin_read ON public.contact_messages
    FOR SELECT USING (public.is_admin());

GRANT INSERT ON public.contact_messages TO anon, authenticated;
GRANT SELECT ON public.contact_messages TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Dispatch: record config errors instead of silent no-op
-- ---------------------------------------------------------------------------
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
        v_url := NULL;
        v_key := NULL;
    END;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured: set marvi.edge_function_url and marvi.service_role_key (see docs/EMAIL_SETUP.md)'
        WHERE id = NEW.id;
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
    UPDATE public.email_outbox
    SET status = 'failed', error_message = SQLERRM
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Skip welcome/admin task noise for Apple review account
-- ---------------------------------------------------------------------------
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
    v_is_review BOOLEAN := lower(coalesce(NEW.email, '')) = 'review@marvisociety.com';
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
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END,
        v_locale
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, languages, status)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END,
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END
    );

    IF NOT v_is_review THEN
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
    END IF;

    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Retry failed/pending outbox rows (run manually or via cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.retry_pending_emails(p_limit INTEGER DEFAULT 20)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    v_row RECORD;
    v_count INTEGER := 0;
BEGIN
    IF NOT public.is_admin() AND auth.role() <> 'service_role' THEN
        RAISE EXCEPTION 'Admin or service role required';
    END IF;

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Email dispatch not configured';
    END;

    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE EXCEPTION 'Email dispatch not configured';
    END IF;

    FOR v_row IN
        SELECT id FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
        ORDER BY created_at ASC
        LIMIT p_limit
    LOOP
        UPDATE public.email_outbox SET status = 'pending', error_message = NULL WHERE id = v_row.id;

        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            body := jsonb_build_object('outbox_id', v_row.id::TEXT)
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.retry_pending_emails(INTEGER) TO service_role;
