-- Paste in Supabase SQL Editor (Run once).
-- Admin directory avatars + admin photo set/clear + admin storage write.

DROP FUNCTION IF EXISTS public.admin_list_users(TEXT, TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.admin_list_users(
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    role public.user_role,
    status public.membership_status,
    full_name TEXT,
    instagram_handle TEXT,
    city TEXT,
    strike_count BIGINT,
    booking_count BIGINT,
    last_lat DOUBLE PRECISION,
    last_lng DOUBLE PRECISION,
    last_seen_at TIMESTAMPTZ,
    creator_id UUID,
    avatar_url TEXT,
    cover_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        coalesce(p.email, u.email),
        p.role,
        p.status,
        cp.full_name,
        cp.instagram_handle,
        cp.city,
        (SELECT count(*) FROM public.strikes s JOIN public.creator_profiles c ON c.id = s.creator_id WHERE c.user_id = p.id),
        (SELECT count(*) FROM public.bookings b JOIN public.creator_profiles c ON c.id = b.creator_id WHERE c.user_id = p.id),
        loc.lat,
        loc.lng,
        loc.updated_at,
        cp.id,
        cp.avatar_url,
        cp.cover_url
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
    LEFT JOIN public.user_location_snapshots loc ON loc.user_id = p.id
    WHERE (
        p_search IS NULL OR trim(p_search) = ''
        OR lower(coalesce(p.email, u.email, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.full_name, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.city, '')) LIKE '%' || lower(trim(p_search)) || '%'
    )
    AND (
        p_status IS NULL OR trim(p_status) = ''
        OR p.status::TEXT = lower(trim(p_status))
    )
    ORDER BY p.updated_at DESC NULLS LAST, p.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 100), 200));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_users(TEXT, TEXT, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_user_profile_image(
    p_user_id UUID,
    p_kind TEXT,
    p_url TEXT DEFAULT NULL
)
RETURNS public.creator_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile public.creator_profiles;
    v_url TEXT := nullif(trim(COALESCE(p_url, '')), '');
    v_kind TEXT := lower(trim(COALESCE(p_kind, '')));
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User required';
    END IF;
    IF v_kind NOT IN ('avatar', 'cover') THEN
        RAISE EXCEPTION 'Invalid image kind';
    END IF;

    INSERT INTO public.creator_profiles (user_id, full_name, city)
    SELECT p.id, coalesce(nullif(trim(p.email), ''), 'Member'), 'istanbul'
    FROM public.profiles p
    WHERE p.id = p_user_id
    ON CONFLICT (user_id) DO NOTHING;

    IF v_kind = 'avatar' THEN
        UPDATE public.creator_profiles
        SET avatar_url = v_url, updated_at = now()
        WHERE user_id = p_user_id
        RETURNING * INTO v_profile;
    ELSE
        UPDATE public.creator_profiles
        SET cover_url = v_url, updated_at = now()
        WHERE user_id = p_user_id
        RETURNING * INTO v_profile;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    PERFORM public.log_activity_event(
        'admin_set_profile_image',
        'user',
        p_user_id,
        jsonb_build_object('kind', v_kind, 'cleared', v_url IS NULL)
    );

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_profile_image(UUID, TEXT, TEXT) TO authenticated;

DROP POLICY IF EXISTS profile_media_admin_write ON storage.objects;
CREATE POLICY profile_media_admin_write ON storage.objects
    FOR ALL
    USING (bucket_id = 'profile-media' AND public.is_admin())
    WITH CHECK (bucket_id = 'profile-media' AND public.is_admin());
