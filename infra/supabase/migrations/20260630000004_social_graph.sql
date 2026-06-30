-- Social graph: follows + collaboration history with two-way reviews

-- ---------------------------------------------------------------------------
-- Follows (any profile can follow any other profile: creators and venue owners)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.follows (
    follower_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    followee_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id),
    CONSTRAINT follows_no_self CHECK (follower_id <> followee_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_followee ON public.follows (followee_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows (follower_id);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS follows_select ON public.follows;
CREATE POLICY follows_select ON public.follows
    FOR SELECT USING (true);

DROP POLICY IF EXISTS follows_insert ON public.follows;
CREATE POLICY follows_insert ON public.follows
    FOR INSERT WITH CHECK (follower_id = auth.uid());

DROP POLICY IF EXISTS follows_delete ON public.follows;
CREATE POLICY follows_delete ON public.follows
    FOR DELETE USING (follower_id = auth.uid());

CREATE OR REPLACE FUNCTION public.follow_user(p_target UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF p_target = auth.uid() THEN
        RAISE EXCEPTION 'Cannot follow yourself';
    END IF;
    INSERT INTO public.follows (follower_id, followee_id)
    VALUES (auth.uid(), p_target)
    ON CONFLICT DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.follow_user(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.unfollow_user(p_target UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    DELETE FROM public.follows
    WHERE follower_id = auth.uid() AND followee_id = p_target;
END;
$$;

GRANT EXECUTE ON FUNCTION public.unfollow_user(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Collaboration history for the signed-in creator
-- Returns venues visited, the rating the venue gave them, and their own review.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_collaboration_history()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_result JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(jsonb_agg(entry ORDER BY entry->>'date' DESC), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'booking_id', b.id,
            'venue_id', v.id,
            'venue_name', v.venue_name,
            'area', v.area,
            'category', v.category,
            'title', o.title,
            'stage', b.stage,
            'date', b.created_at,
            'venue_rating', CASE
                WHEN vr.id IS NOT NULL THEN jsonb_build_object(
                    'punctuality', vr.punctuality,
                    'presentation', vr.presentation,
                    'comment', vr.comment
                )
                ELSE NULL
            END,
            'my_rating', CASE
                WHEN cr.id IS NOT NULL THEN jsonb_build_object(
                    'hospitality', cr.hospitality,
                    'experience', cr.experience,
                    'comment', cr.comment
                )
                ELSE NULL
            END
        ) AS entry
        FROM public.bookings b
        JOIN public.offers o ON o.id = b.offer_id
        JOIN public.venue_profiles v ON v.id = o.venue_id
        LEFT JOIN public.venue_reviews vr ON vr.booking_id = b.id
        LEFT JOIN public.creator_reviews cr ON cr.booking_id = b.id
        WHERE b.creator_id = v_creator_id
          AND b.stage IN ('checked_in', 'proof_due', 'completed')
    ) rows;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_collaboration_history() TO authenticated;

-- ---------------------------------------------------------------------------
-- Public creator profile (viewable by any authenticated member)
-- ---------------------------------------------------------------------------
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

    -- Reviews the creator received from venues
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

    -- Venues the creator collaborated with
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
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Follower / following counts for the signed-in user
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_follow_counts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    RETURN jsonb_build_object(
        'followers', (SELECT count(*) FROM public.follows WHERE followee_id = auth.uid()),
        'following', (SELECT count(*) FROM public.follows WHERE follower_id = auth.uid())
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_follow_counts() TO authenticated;
