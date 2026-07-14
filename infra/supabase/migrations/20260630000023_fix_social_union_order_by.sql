-- Fix: invalid UNION/INTERSECT/EXCEPT ORDER BY + activity.created_at missing
-- Root cause: UNION branches lacked explicit output aliases; ORDER BY referenced
-- names that were not real output columns (e.g. followers, activity.created_at).

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
    is_following BOOLEAN
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
            ) AS is_following
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
            ) AS is_following
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

CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit INTEGER DEFAULT 40)
RETURNS TABLE (
    activity_id UUID,
    actor_user_id UUID,
    actor_creator_id UUID,
    actor_venue_id UUID,
    actor_name TEXT,
    action_type TEXT,
    title TEXT,
    subtitle TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            b.id AS activity_id,
            cp.user_id AS actor_user_id,
            cp.id AS actor_creator_id,
            NULL::UUID AS actor_venue_id,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'checked_in'::TEXT AS action_type,
            coalesce(o.title, v.venue_name, 'Collaboration') AS title,
            coalesce(v.area, '') AS subtitle,
            coalesce(b.updated_at, b.created_at) AS created_at
        FROM public.bookings b
        JOIN public.creator_profiles cp ON cp.id = b.creator_id
        JOIN public.offers o ON o.id = b.offer_id
        JOIN public.venue_profiles v ON v.id = o.venue_id
        JOIN public.follows f ON f.followee_id = cp.user_id AND f.follower_id = auth.uid()
        WHERE b.stage IN ('checked_in', 'proof_due', 'completed')

        UNION ALL

        SELECT
            cs.id AS activity_id,
            cs.user_id AS actor_user_id,
            cp.id AS actor_creator_id,
            NULL::UUID AS actor_venue_id,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'showcase_added'::TEXT AS action_type,
            CASE
                WHEN cs.caption <> '' THEN cs.caption
                WHEN cs.external_url <> '' THEN 'New showcase post'
                ELSE 'New showcase photo'
            END AS title,
            coalesce(cs.external_url, cs.media_url, '') AS subtitle,
            cs.created_at AS created_at
        FROM public.creator_showcase cs
        JOIN public.creator_profiles cp ON cp.user_id = cs.user_id
        JOIN public.follows f ON f.followee_id = cs.user_id AND f.follower_id = auth.uid()

        UNION ALL

        SELECT
            o.id AS activity_id,
            vp.owner_user_id AS actor_user_id,
            NULL::UUID AS actor_creator_id,
            vp.id AS actor_venue_id,
            vp.venue_name AS actor_name,
            'venue_offer'::TEXT AS action_type,
            o.title AS title,
            coalesce(vp.area, o.category::TEXT) AS subtitle,
            o.created_at AS created_at
        FROM public.offers o
        JOIN public.venue_profiles vp ON vp.id = o.venue_id
        JOIN public.follows f ON f.followee_id = vp.owner_user_id AND f.follower_id = auth.uid()
        WHERE o.status = 'live'
          AND o.created_at > now() - interval '30 days'
    ) AS activity
    ORDER BY activity.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_following_activity(INTEGER) TO authenticated;
