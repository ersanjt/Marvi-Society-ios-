-- Invite codes are admin-managed secrets: hide from app users, expose stats to admins only.

DROP POLICY IF EXISTS referral_read ON public.referral_codes;

-- Admin-only listing and management RPCs
CREATE OR REPLACE FUNCTION public.admin_list_invite_codes()
RETURNS TABLE (
    id UUID,
    code TEXT,
    owner_type TEXT,
    uses_count INTEGER,
    max_uses INTEGER,
    invite_email TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    RETURN QUERY
    SELECT
        rc.id,
        rc.code,
        rc.owner_type,
        rc.uses_count,
        rc.max_uses,
        rc.invite_email,
        rc.created_at
    FROM public.referral_codes rc
    ORDER BY rc.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_invite_codes() TO authenticated;

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
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_code := upper(coalesce(nullif(trim(p_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8)));
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

    RETURN jsonb_build_object(
        'code', v_code,
        'owner_type', v_type,
        'max_uses', v_max,
        'uses_count', (SELECT uses_count FROM public.referral_codes WHERE code = v_code)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_invite_code(TEXT, TEXT, INTEGER, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_update_invite_code(
    p_code TEXT,
    p_max_uses INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_max INTEGER;
    v_row public.referral_codes%ROWTYPE;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_code := upper(trim(p_code));
    IF v_code = '' THEN
        RAISE EXCEPTION 'Invite code required';
    END IF;

    v_max := greatest(1, coalesce(p_max_uses, 1));

    UPDATE public.referral_codes
    SET max_uses = v_max
    WHERE upper(code) = v_code
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invite code not found';
    END IF;

    RETURN jsonb_build_object(
        'code', v_row.code,
        'max_uses', v_row.max_uses,
        'uses_count', v_row.uses_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_invite_code(TEXT, INTEGER) TO authenticated;
