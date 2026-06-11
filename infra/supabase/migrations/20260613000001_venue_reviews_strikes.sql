-- Venue post-visit ratings + admin strike by booking + richer review queue

CREATE TABLE IF NOT EXISTS public.venue_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings (id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    punctuality SMALLINT NOT NULL CHECK (punctuality BETWEEN 1 AND 5),
    presentation SMALLINT NOT NULL CHECK (presentation BETWEEN 1 AND 5),
    comment TEXT NOT NULL DEFAULT '',
    created_by UUID NOT NULL REFERENCES public.profiles (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.venue_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY venue_reviews_select ON public.venue_reviews
    FOR SELECT USING (
        created_by = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = venue_reviews.venue_id AND v.owner_user_id = auth.uid()
        )
    );

CREATE POLICY venue_reviews_insert ON public.venue_reviews
    FOR INSERT WITH CHECK (
        created_by = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.bookings b
            JOIN public.offers o ON o.id = b.offer_id
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE b.id = booking_id AND v.owner_user_id = auth.uid()
        )
    );

-- Venue owner rates creator after visit
CREATE OR REPLACE FUNCTION public.submit_venue_review(
    p_booking_id UUID,
    p_punctuality INT,
    p_presentation INT,
    p_comment TEXT DEFAULT ''
)
RETURNS public.venue_reviews
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_reviews;
    v_booking public.bookings;
    v_venue_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_punctuality < 1 OR p_punctuality > 5 OR p_presentation < 1 OR p_presentation > 5 THEN
        RAISE EXCEPTION 'Ratings must be between 1 and 5';
    END IF;

    SELECT b.* INTO v_booking FROM public.bookings b WHERE b.id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    SELECT o.venue_id INTO v_venue_id
    FROM public.offers o
    WHERE o.id = v_booking.offer_id;

    IF NOT EXISTS (
        SELECT 1 FROM public.venue_profiles v
        WHERE v.id = v_venue_id AND v.owner_user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'Not authorized to review this booking';
    END IF;

    INSERT INTO public.venue_reviews (
        booking_id, venue_id, creator_id, punctuality, presentation, comment, created_by
    )
    VALUES (
        p_booking_id,
        v_venue_id,
        v_booking.creator_id,
        p_punctuality,
        p_presentation,
        COALESCE(p_comment, ''),
        v_uid
    )
    ON CONFLICT (booking_id) DO UPDATE SET
        punctuality = EXCLUDED.punctuality,
        presentation = EXCLUDED.presentation,
        comment = EXCLUDED.comment,
        created_at = now()
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_venue_review(UUID, INT, INT, TEXT) TO authenticated;

-- Admin issues strike from proof/booking context
CREATE OR REPLACE FUNCTION public.issue_strike_for_booking(
    p_booking_id UUID,
    p_reason TEXT,
    p_severity TEXT DEFAULT 'medium'
)
RETURNS public.strikes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
    v_strike public.strikes;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    INSERT INTO public.strikes (creator_id, booking_id, reason, severity, created_by)
    VALUES (v_booking.creator_id, p_booking_id, p_reason, COALESCE(p_severity, 'medium'), auth.uid())
    RETURNING * INTO v_strike;

    RETURN v_strike;
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_strike_for_booking(UUID, TEXT, TEXT) TO authenticated;

-- Richer queue for Checked in / Checked out / No show tabs
DROP FUNCTION IF EXISTS public.fetch_venue_review_queue();

CREATE OR REPLACE FUNCTION public.fetch_venue_review_queue()
RETURNS TABLE (
    booking_id UUID,
    creator_name TEXT,
    instagram_handle TEXT,
    offer_title TEXT,
    stage public.booking_stage,
    proof_status public.proof_status,
    checked_in_label TEXT,
    has_review BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        b.id,
        cp.full_name,
        cp.instagram_handle,
        o.title,
        b.stage,
        b.proof_status,
        to_char(b.updated_at, 'Mon DD · HH24:MI'),
        (vr.id IS NOT NULL)
    FROM public.bookings b
    JOIN public.creator_profiles cp ON cp.id = b.creator_id
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    LEFT JOIN public.venue_reviews vr ON vr.booking_id = b.id
    WHERE v.owner_user_id = auth.uid()
      AND (
          b.stage IN ('checked_in', 'proof_due', 'completed', 'cancelled')
          OR b.proof_status IN ('pending', 'approved', 'flagged')
      )
    ORDER BY b.updated_at DESC
    LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_venue_review_queue() TO authenticated;
