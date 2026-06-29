-- Feature completeness: creator→venue ratings, profile avatar/cover, profile media storage.

-- ---------------------------------------------------------------------------
-- 1. Creator reviews (influencer rates venue after visit)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.creator_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings (id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    hospitality SMALLINT NOT NULL CHECK (hospitality BETWEEN 1 AND 5),
    experience SMALLINT NOT NULL CHECK (experience BETWEEN 1 AND 5),
    comment TEXT NOT NULL DEFAULT '',
    created_by UUID NOT NULL REFERENCES public.profiles (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.creator_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY creator_reviews_select ON public.creator_reviews
    FOR SELECT USING (
        created_by = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = creator_reviews.venue_id AND v.owner_user_id = auth.uid()
        )
    );

CREATE POLICY creator_reviews_insert ON public.creator_reviews
    FOR INSERT WITH CHECK (
        created_by = auth.uid()
        AND creator_id = public.current_creator_id()
    );

CREATE OR REPLACE FUNCTION public.submit_creator_review(
    p_booking_id UUID,
    p_hospitality INT,
    p_experience INT,
    p_comment TEXT DEFAULT ''
)
RETURNS public.creator_reviews
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_creator_id UUID;
    v_row public.creator_reviews;
    v_booking public.bookings;
    v_venue_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    IF p_hospitality < 1 OR p_hospitality > 5 OR p_experience < 1 OR p_experience > 5 THEN
        RAISE EXCEPTION 'Ratings must be between 1 and 5';
    END IF;

    SELECT b.* INTO v_booking FROM public.bookings b WHERE b.id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.creator_id IS DISTINCT FROM v_creator_id THEN
        RAISE EXCEPTION 'Not authorized to review this booking';
    END IF;

    IF v_booking.stage NOT IN ('checked_in', 'proof_due', 'completed') THEN
        RAISE EXCEPTION 'Visit must be checked in before rating the venue';
    END IF;

    SELECT o.venue_id INTO v_venue_id
    FROM public.offers o
    WHERE o.id = v_booking.offer_id;

    INSERT INTO public.creator_reviews (
        booking_id, venue_id, creator_id, hospitality, experience, comment, created_by
    )
    VALUES (
        p_booking_id,
        v_venue_id,
        v_creator_id,
        p_hospitality,
        p_experience,
        COALESCE(p_comment, ''),
        v_uid
    )
    ON CONFLICT (booking_id) DO UPDATE SET
        hospitality = EXCLUDED.hospitality,
        experience = EXCLUDED.experience,
        comment = EXCLUDED.comment,
        created_at = now()
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_creator_review(UUID, INT, INT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Profile avatar + cover on creator_profiles
-- ---------------------------------------------------------------------------
ALTER TABLE public.creator_profiles
    ADD COLUMN IF NOT EXISTS avatar_url TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS cover_url TEXT NOT NULL DEFAULT '';

-- ---------------------------------------------------------------------------
-- 3. Profile media storage (user-scoped uploads, public read)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('profile-media', 'profile-media', true, 5242880)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY profile_media_public_read ON storage.objects
    FOR SELECT USING (bucket_id = 'profile-media');

CREATE POLICY profile_media_upload_own ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY profile_media_update_own ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY profile_media_delete_own ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );
