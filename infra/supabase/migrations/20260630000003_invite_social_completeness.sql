-- Invite email binding, creator-to-creator invites, TikTok on signup

ALTER TABLE public.referral_codes
    ADD COLUMN IF NOT EXISTS invite_email TEXT;

CREATE INDEX IF NOT EXISTS idx_referral_codes_invite_email
    ON public.referral_codes (lower(invite_email))
    WHERE invite_email IS NOT NULL;

-- Redeem invite: optional email lock when code was emailed to a specific address
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
    v_user_email TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_code := upper(trim(p_code));
    IF v_code = '' THEN
        RAISE EXCEPTION 'Invite code required';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND referral_code IS NOT NULL
    ) THEN
        RETURN;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid invite code';
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RAISE EXCEPTION 'Invite code has reached its limit';
    END IF;

    IF v_row.invite_email IS NOT NULL AND trim(v_row.invite_email) <> '' THEN
        SELECT lower(trim(email)) INTO v_user_email
        FROM public.profiles
        WHERE id = auth.uid();

        IF v_user_email IS NULL OR v_user_email <> lower(trim(v_row.invite_email)) THEN
            RAISE EXCEPTION 'This invite was sent to a different email address';
        END IF;
    END IF;

    UPDATE public.referral_codes
    SET uses_count = uses_count + 1
    WHERE id = v_row.id;

    UPDATE public.profiles
    SET referral_code = v_code
    WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT) TO authenticated;

-- Creator invites a friend by email (single-use code bound to recipient email)
CREATE OR REPLACE FUNCTION public.send_creator_invite(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email TEXT;
    v_code TEXT;
    v_locale TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_email := lower(trim(p_email));
    IF v_email = '' OR position('@' IN v_email) = 0 THEN
        RAISE EXCEPTION 'Valid email required';
    END IF;

    IF v_email = lower(trim((SELECT email FROM public.profiles WHERE id = auth.uid()))) THEN
        RAISE EXCEPTION 'You cannot invite yourself';
    END IF;

    v_code := 'MARVI-' || upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8));

    INSERT INTO public.referral_codes (code, owner_user_id, owner_type, max_uses, invite_email)
    VALUES (v_code, auth.uid(), 'creator', 1, v_email);

    SELECT coalesce(preferred_locale, 'en') INTO v_locale
    FROM public.profiles
    WHERE id = auth.uid();

    PERFORM public.queue_transactional_email(
        NULL,
        v_email,
        'invite_code',
        v_locale,
        jsonb_build_object(
            'email', v_email,
            'invite_code', v_code,
            'site_url', 'https://marvisociety.com',
            'deep_link', 'marvisociety://invite?code=' || v_code
        )
    );

    RETURN jsonb_build_object('email', v_email, 'invite_code', v_code);
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_creator_invite(TEXT) TO authenticated;

-- Admin invite: also bind recipient email
CREATE OR REPLACE FUNCTION public.admin_send_invite(
    p_email TEXT,
    p_invite_code TEXT DEFAULT NULL,
    p_max_uses INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_email TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_email := lower(trim(p_email));
    IF v_email = '' OR position('@' IN v_email) = 0 THEN
        RAISE EXCEPTION 'Valid email required';
    END IF;

    v_code := upper(coalesce(nullif(trim(p_invite_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8)));

    INSERT INTO public.referral_codes (code, owner_type, max_uses, invite_email)
    VALUES (v_code, 'creator', greatest(1, coalesce(p_max_uses, 1)), v_email)
    ON CONFLICT (code) DO UPDATE
        SET max_uses = EXCLUDED.max_uses,
            invite_email = EXCLUDED.invite_email;

    PERFORM public.queue_transactional_email(
        NULL,
        v_email,
        'invite_code',
        'en',
        jsonb_build_object(
            'email', v_email,
            'invite_code', v_code,
            'site_url', 'https://marvisociety.com',
            'deep_link', 'marvisociety://invite?code=' || v_code
        )
    );

    RETURN jsonb_build_object('email', v_email, 'invite_code', v_code);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_send_invite(TEXT, TEXT, INTEGER) TO authenticated;

-- Store TikTok handle from signup metadata
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
    v_tiktok TEXT;
    v_is_review BOOLEAN := lower(coalesce(NEW.email, '')) = 'review@marvisociety.com';
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_tiktok := coalesce(NEW.raw_user_meta_data ->> 'tiktok_handle', '');
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

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, tiktok_handle, city, languages, status)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_tiktok,
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
