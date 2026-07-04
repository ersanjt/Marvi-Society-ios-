-- Member discovery: search approved creators and activity feed from people you follow.

CREATE OR REPLACE FUNCTION public.search_members(
    p_query TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    creator_id UUID,
    user_id UUID,
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
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_query := lower(trim(coalesce(p_query, '')));

    RETURN QUERY
    SELECT
        cp.id,
        cp.user_id,
        cp.full_name,
        cp.instagram_handle,
        cp.tiktok_handle,
        cp.city,
        cp.score,
        (SELECT count(*) FROM public.follows f WHERE f.followee_id = cp.user_id),
        EXISTS (
            SELECT 1 FROM public.follows f
            WHERE f.follower_id = auth.uid() AND f.followee_id = cp.user_id
        )
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
    ORDER BY cp.score DESC NULLS LAST, cp.audience_count DESC NULLS LAST
    LIMIT greatest(1, least(coalesce(p_limit, 30), 50));
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_members(TEXT, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit INTEGER DEFAULT 40)
RETURNS TABLE (
    activity_id UUID,
    actor_user_id UUID,
    actor_creator_id UUID,
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
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'checked_in'::TEXT AS action_type,
            coalesce(o.title, v.venue_name, 'Collaboration') AS title,
            coalesce(v.area, v.venue_name, '') AS subtitle,
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
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'showcase_added'::TEXT AS action_type,
            CASE
                WHEN cs.caption <> '' THEN cs.caption
                WHEN cs.external_url <> '' THEN 'New showcase post'
                ELSE 'New showcase photo'
            END AS title,
            coalesce(cs.external_url, cs.media_url, '') AS subtitle,
            cs.created_at
        FROM public.creator_showcase cs
        JOIN public.creator_profiles cp ON cp.user_id = cs.user_id
        JOIN public.follows f ON f.followee_id = cs.user_id AND f.follower_id = auth.uid()
    ) activity
    ORDER BY activity.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_following_activity(INTEGER) TO authenticated;
