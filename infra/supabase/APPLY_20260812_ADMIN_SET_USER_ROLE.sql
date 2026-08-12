-- Paste in Supabase SQL Editor if CLI push is unavailable.
-- Admin role changes: creator ↔ venue (business) ↔ admin + safer membership pause.

CREATE OR REPLACE FUNCTION public.admin_set_membership_status(
    p_user_id UUID,
    p_status public.membership_status
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot change your own status';
    END IF;

    UPDATE public.profiles
    SET
        status = p_status,
        paused_by_self = CASE WHEN p_status = 'paused' THEN false ELSE paused_by_self END,
        updated_at = now()
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE public.creator_profiles
    SET status = p_status, updated_at = now()
    WHERE user_id = p_user_id;

    UPDATE public.venue_profiles
    SET status = CASE
            WHEN p_status = 'approved' THEN 'approved'::public.membership_status
            ELSE 'paused'::public.membership_status
        END,
        updated_at = now()
    WHERE owner_user_id = p_user_id;

    PERFORM public.log_activity_event(
        'admin_membership_status',
        'profile',
        p_user_id,
        jsonb_build_object('status', p_status)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_membership_status(UUID, public.membership_status) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_user_role(
    p_user_id UUID,
    p_role public.user_role
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile public.profiles;
    v_from public.user_role;
    v_email TEXT;
    v_venue_id UUID;
    v_name TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User required';
    END IF;

    IF p_role IS NULL THEN
        RAISE EXCEPTION 'Role required';
    END IF;

    IF p_user_id = auth.uid() AND p_role IS DISTINCT FROM 'admin'::public.user_role THEN
        RAISE EXCEPTION 'Cannot remove your own admin role';
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    v_from := v_profile.role;
    v_email := coalesce(nullif(trim(v_profile.email), ''), 'user');

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, status)
    VALUES (
        p_user_id,
        split_part(v_email, '@', 1),
        '',
        'istanbul',
        coalesce(v_profile.status, 'under_review'::public.membership_status)
    )
    ON CONFLICT (user_id) DO NOTHING;

    IF p_role = 'venue' THEN
        SELECT id INTO v_venue_id
        FROM public.venue_profiles
        WHERE owner_user_id = p_user_id
        ORDER BY created_at ASC
        LIMIT 1;

        IF v_venue_id IS NULL THEN
            SELECT coalesce(nullif(trim(full_name), ''), split_part(v_email, '@', 1), 'Business')
            INTO v_name
            FROM public.creator_profiles
            WHERE user_id = p_user_id;

            INSERT INTO public.venue_profiles (
                owner_user_id,
                venue_name,
                area,
                category,
                address,
                contact_name,
                status
            )
            VALUES (
                p_user_id,
                coalesce(nullif(trim(v_name), ''), 'Business'),
                'Istanbul',
                'dining'::public.offer_category,
                '',
                coalesce(nullif(trim(v_name), ''), split_part(v_email, '@', 1)),
                coalesce(v_profile.status, 'under_review'::public.membership_status)
            )
            RETURNING id INTO v_venue_id;
        END IF;

        UPDATE public.profiles
        SET
            role = 'venue',
            active_venue_id = v_venue_id,
            updated_at = now()
        WHERE id = p_user_id
        RETURNING * INTO v_profile;
    ELSIF p_role = 'admin' THEN
        UPDATE public.profiles
        SET
            role = 'admin',
            status = 'approved',
            updated_at = now()
        WHERE id = p_user_id
        RETURNING * INTO v_profile;

        UPDATE public.creator_profiles
        SET status = 'approved', updated_at = now()
        WHERE user_id = p_user_id;
    ELSE
        UPDATE public.profiles
        SET
            role = 'creator',
            active_venue_id = NULL,
            updated_at = now()
        WHERE id = p_user_id
        RETURNING * INTO v_profile;
    END IF;

    PERFORM public.log_activity_event(
        'admin_user_role',
        'profile',
        p_user_id,
        jsonb_build_object(
            'from', v_from,
            'to', p_role,
            'email', v_email
        )
    );

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_role(UUID, public.user_role) TO authenticated;
