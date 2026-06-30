-- Public creator profile lookup by creator_profiles.id

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
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile_by_creator_id(UUID) TO authenticated;
