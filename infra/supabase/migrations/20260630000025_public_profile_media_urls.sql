-- Expose avatar_url / cover_url on public creator profiles and member search
-- so other members can see uploaded profile media (social loop).

CREATE OR REPLACE FUNCTION public.get_creator_public_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator public.creator_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_reviews JSONB;
    v_collabs JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_creator FROM public.creator_profiles WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = p_user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = p_user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows WHERE follower_id = auth.uid() AND followee_id = p_user_id
    ) INTO v_is_following;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'venue_name', v.venue_name,
        'punctuality', vr.punctuality,
        'presentation', vr.presentation,
        'comment', vr.comment,
        'date', vr.created_at
    ) ORDER BY vr.created_at DESC), '[]'::JSONB)
    INTO v_reviews
    FROM public.venue_reviews vr
    JOIN public.venue_profiles v ON v.id = vr.venue_id
    WHERE vr.creator_id = v_creator.id;

    SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'venue_name', v.venue_name,
        'area', v.area,
        'category', v.category
    )), '[]'::JSONB)
    INTO v_collabs
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE b.creator_id = v_creator.id
      AND b.stage IN ('checked_in', 'proof_due', 'completed');

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'full_name', v_creator.full_name,
        'instagram_handle', v_creator.instagram_handle,
        'tiktok_handle', v_creator.tiktok_handle,
        'city', v_creator.city,
        'bio', v_creator.bio,
        'niches', v_creator.niches,
        'score', v_creator.score,
        'proof_rate', v_creator.proof_rate,
        'avatar_url', coalesce(v_creator.avatar_url, ''),
        'cover_url', coalesce(v_creator.cover_url, ''),
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_creator_public_profile_by_creator_id(p_creator_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator public.creator_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_reviews JSONB;
    v_collabs JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_creator FROM public.creator_profiles WHERE id = p_creator_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = v_creator.user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = v_creator.user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = auth.uid() AND followee_id = v_creator.user_id
    ) INTO v_is_following;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'venue_name', v.venue_name,
        'punctuality', vr.punctuality,
        'presentation', vr.presentation,
        'comment', vr.comment,
        'date', vr.created_at
    ) ORDER BY vr.created_at DESC), '[]'::JSONB)
    INTO v_reviews
    FROM public.venue_reviews vr
    JOIN public.venue_profiles v ON v.id = vr.venue_id
    WHERE vr.creator_id = v_creator.id;

    SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'venue_name', v.venue_name,
        'area', v.area,
        'category', v.category
    )), '[]'::JSONB)
    INTO v_collabs
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE b.creator_id = v_creator.id
      AND b.stage IN ('checked_in', 'proof_due', 'completed');

    RETURN jsonb_build_object(
        'creator_id', v_creator.id,
        'user_id', v_creator.user_id,
        'full_name', v_creator.full_name,
        'instagram_handle', v_creator.instagram_handle,
        'tiktok_handle', v_creator.tiktok_handle,
        'city', v_creator.city,
        'bio', v_creator.bio,
        'niches', v_creator.niches,
        'score', v_creator.score,
        'proof_rate', v_creator.proof_rate,
        'avatar_url', coalesce(v_creator.avatar_url, ''),
        'cover_url', coalesce(v_creator.cover_url, ''),
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile_by_creator_id(UUID) TO authenticated;

-- Changing RETURNS TABLE requires drop first (Postgres cannot alter OUT params in place).
DROP FUNCTION IF EXISTS public.search_members(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.search_members(
    p_query TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    profile_ref_id UUID,
    user_id UUID,
    member_type TEXT,
    full_name TEXT,
    instagram_handle TEXT,
    tiktok_handle TEXT,
    city TEXT,
    score NUMERIC,
    followers BIGINT,
    is_following BOOLEAN,
    avatar_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_query TEXT;
    v_limit INTEGER;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_query := lower(trim(coalesce(p_query, '')));
    v_limit := greatest(1, least(coalesce(p_limit, 30), 50));

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            cp.id AS profile_ref_id,
            cp.user_id AS user_id,
            'creator'::TEXT AS member_type,
            cp.full_name AS full_name,
            cp.instagram_handle AS instagram_handle,
            cp.tiktok_handle AS tiktok_handle,
            cp.city AS city,
            cp.score AS score,
            (SELECT count(*)::BIGINT FROM public.follows f WHERE f.followee_id = cp.user_id) AS followers,
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = cp.user_id
            ) AS is_following,
            coalesce(cp.avatar_url, '') AS avatar_url
        FROM public.creator_profiles cp
        JOIN public.profiles p ON p.id = cp.user_id
        WHERE cp.status = 'approved'
          AND p.status = 'approved'
          AND cp.user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(coalesce(cp.full_name, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.tiktok_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.city, '')) LIKE '%' || v_query || '%'
              OR EXISTS (
                  SELECT 1 FROM unnest(coalesce(cp.niches, ARRAY[]::TEXT[])) n
                  WHERE lower(n) LIKE '%' || v_query || '%'
              )
          )

        UNION ALL

        SELECT
            vp.id AS profile_ref_id,
            vp.owner_user_id AS user_id,
            'venue'::TEXT AS member_type,
            vp.venue_name AS full_name,
            vp.venue_name AS instagram_handle,
            ''::TEXT AS tiktok_handle,
            vp.area AS city,
            0::NUMERIC AS score,
            (SELECT count(*)::BIGINT FROM public.follows f WHERE f.followee_id = vp.owner_user_id) AS followers,
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = vp.owner_user_id
            ) AS is_following,
            ''::TEXT AS avatar_url
        FROM public.venue_profiles vp
        JOIN public.profiles p ON p.id = vp.owner_user_id
        WHERE vp.status = 'approved'
          AND p.status = 'approved'
          AND vp.owner_user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(vp.venue_name) LIKE '%' || v_query || '%'
              OR lower(vp.area) LIKE '%' || v_query || '%'
              OR lower(vp.category::TEXT) LIKE '%' || v_query || '%'
          )
    ) AS members
    ORDER BY members.score DESC NULLS LAST, members.followers DESC
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_members(TEXT, INTEGER) TO authenticated;
