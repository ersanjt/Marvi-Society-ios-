-- Fix invite redeem normalization + auto-queue invite email when creating a code with recipient email.
-- Also harden validate/redeem against unicode dashes and casing.

CREATE OR REPLACE FUNCTION public.normalize_invite_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT upper(
        trim(
            replace(
                replace(
                    replace(coalesce(p_code, ''), E'\u2013', '-'), -- en-dash
                    E'\u2014', '-' -- em-dash
                ),
                E'\u2212', '-' -- minus
            )
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
BEGIN
    v_code := public.normalize_invite_code(p_code);
    IF v_code = '' THEN
        RETURN FALSE;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon, authenticated;

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

    v_code := public.normalize_invite_code(p_code);
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

    -- Prefer auth email; fall back to profiles.email for binding checks.
    SELECT lower(trim(coalesce(au.email, p.email))) INTO v_user_email
    FROM auth.users au
    LEFT JOIN public.profiles p ON p.id = au.id
    WHERE au.id = auth.uid();

    IF v_row.invite_email IS NOT NULL AND trim(v_row.invite_email) <> '' THEN
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

-- Creating an invite code with a recipient email also queues the invite email.
CREATE OR REPLACE FUNCTION public.admin_create_invite_code(
    p_code TEXT DEFAULT NULL,
    p_owner_type TEXT DEFAULT 'creator',
    p_max_uses INTEGER DEFAULT 1,
    p_invite_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_email TEXT;
    v_max INTEGER;
    v_type TEXT;
    v_uses INTEGER;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_code := public.normalize_invite_code(
        coalesce(nullif(trim(p_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8))
    );
    v_type := lower(coalesce(nullif(trim(p_owner_type), ''), 'creator'));
    IF v_type NOT IN ('creator', 'venue') THEN
        RAISE EXCEPTION 'owner_type must be creator or venue';
    END IF;

    v_max := greatest(1, coalesce(p_max_uses, 1));
    v_email := nullif(lower(trim(p_invite_email)), '');

    INSERT INTO public.referral_codes (code, owner_type, max_uses, invite_email)
    VALUES (v_code, v_type, v_max, v_email)
    ON CONFLICT (code) DO UPDATE
    SET max_uses = EXCLUDED.max_uses,
        invite_email = coalesce(EXCLUDED.invite_email, public.referral_codes.invite_email),
        owner_type = EXCLUDED.owner_type;

    SELECT uses_count INTO v_uses FROM public.referral_codes WHERE code = v_code;

    IF v_email IS NOT NULL THEN
        PERFORM public.queue_transactional_email(
            NULL,
            v_email,
            'invite_code',
            'tr',
            jsonb_build_object(
                'email', v_email,
                'invite_code', v_code,
                'site_url', 'https://marvisociety.com',
                'deep_link', 'marvisociety://invite?code=' || v_code
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'code', v_code,
        'owner_type', v_type,
        'max_uses', v_max,
        'uses_count', coalesce(v_uses, 0),
        'invite_email', v_email,
        'email_queued', (v_email IS NOT NULL)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_invite_code(TEXT, TEXT, INTEGER, TEXT) TO authenticated;

-- Admin send invite: normalize code + Turkish email by default for Istanbul product.
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

    v_code := public.normalize_invite_code(
        coalesce(nullif(trim(p_invite_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8))
    );

    INSERT INTO public.referral_codes (code, owner_type, max_uses, invite_email)
    VALUES (v_code, 'creator', greatest(1, coalesce(p_max_uses, 1)), v_email)
    ON CONFLICT (code) DO UPDATE
        SET max_uses = EXCLUDED.max_uses,
            invite_email = EXCLUDED.invite_email;

    PERFORM public.queue_transactional_email(
        NULL,
        v_email,
        'invite_code',
        'tr',
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

-- When dispatch settings are missing, mark pending rows so admins see the failure instead of silent queue.
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

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 OR v_key = 'YOUR_SERVICE_ROLE_KEY' THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured — set marvi.edge_function_url + marvi.service_role_key or Database Webhook'
        WHERE id = NEW.id AND status = 'pending';
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
    SET error_message = left('Dispatch error: ' || SQLERRM, 500)
    WHERE id = NEW.id AND status = 'pending';
    RETURN NEW;
END;
$$;
