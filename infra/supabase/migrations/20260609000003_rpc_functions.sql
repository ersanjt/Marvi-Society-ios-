-- RPC functions for mobile clients (atomic workflows)

-- Accept offer → create booking, decrement slots, notify
CREATE OR REPLACE FUNCTION public.accept_offer(p_offer_id UUID)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_offer public.offers;
    v_booking public.bookings;
    v_code TEXT;
BEGIN
    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    SELECT * INTO v_offer
    FROM public.offers
    WHERE id = p_offer_id AND status = 'live'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not available';
    END IF;

    IF v_offer.remaining_slots <= 0 THEN
        RAISE EXCEPTION 'No slots remaining';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.bookings
        WHERE offer_id = p_offer_id
          AND creator_id = v_creator_id
          AND stage <> 'cancelled'
    ) THEN
        RAISE EXCEPTION 'Already accepted';
    END IF;

    v_code := lpad((floor(random() * 9000) + 1000)::TEXT, 4, '0');

    INSERT INTO public.bookings (
        offer_id,
        creator_id,
        stage,
        check_in_code,
        proof_deadline,
        proof_deadline_label
    ) VALUES (
        p_offer_id,
        v_creator_id,
        'confirmed',
        v_code,
        COALESCE(v_offer.date_end, now() + interval '1 day'),
        COALESCE(v_offer.date_label, 'Today') || ', 22:00'
    )
    RETURNING * INTO v_booking;

    UPDATE public.offers
    SET remaining_slots = remaining_slots - 1
    WHERE id = p_offer_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint)
    SELECT
        cp.user_id,
        'Invitation confirmed',
        v.venue_name || ' is now in your bookings.',
        'booking',
        'checkmark.circle.fill',
        'emerald'
    FROM public.creator_profiles cp
    JOIN public.offers o ON o.id = p_offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE cp.id = v_creator_id;

    RETURN v_booking;
END;
$$;

-- Cancel booking
CREATE OR REPLACE FUNCTION public.cancel_booking(p_booking_id UUID)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id AND creator_id = public.current_creator_id()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.stage = 'cancelled' THEN
        RETURN v_booking;
    END IF;

    UPDATE public.bookings
    SET stage = 'cancelled'
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    UPDATE public.offers
    SET remaining_slots = LEAST(remaining_slots + 1, capacity)
    WHERE id = v_booking.offer_id;

    RETURN v_booking;
END;
$$;

-- Check in with code
CREATE OR REPLACE FUNCTION public.check_in_booking(p_booking_id UUID, p_code TEXT)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id AND creator_id = public.current_creator_id()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.check_in_code <> p_code THEN
        RAISE EXCEPTION 'Invalid check-in code';
    END IF;

    UPDATE public.bookings
    SET stage = 'checked_in'
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    RETURN v_booking;
END;
$$;

-- Submit proof
CREATE OR REPLACE FUNCTION public.submit_proof(p_booking_id UUID, p_links TEXT[])
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
    v_creator_id UUID;
    v_venue_name TEXT;
BEGIN
    v_creator_id := public.current_creator_id();

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id AND creator_id = v_creator_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF array_length(p_links, 1) IS NULL OR array_length(p_links, 1) = 0 THEN
        RAISE EXCEPTION 'At least one proof link required';
    END IF;

    INSERT INTO public.proof_submissions (booking_id, creator_id, links, status)
    VALUES (p_booking_id, v_creator_id, p_links, 'pending');

    UPDATE public.bookings
    SET
        stage = 'completed',
        proof_status = 'pending',
        proof_links = p_links
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    SELECT v.venue_name INTO v_venue_name
    FROM public.offers o
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE o.id = v_booking.offer_id;

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
    VALUES (
        'proof_review',
        p_booking_id,
        v_venue_name || ' proof',
        array_length(p_links, 1)::TEXT || ' proof link(s) submitted.',
        'Medium'
    );

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint)
    SELECT
        cp.user_id,
        'Proof sent to review',
        'Admin will review your submission for ' || v_venue_name || '.',
        'proof',
        'tray.and.arrow.up.fill',
        'blue'
    FROM public.creator_profiles cp
    WHERE cp.id = v_creator_id;

    RETURN v_booking;
END;
$$;

-- Toggle saved offer
CREATE OR REPLACE FUNCTION public.toggle_saved_offer(p_offer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_saved BOOLEAN;
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.saved_offers
        WHERE user_id = auth.uid() AND offer_id = p_offer_id
    ) THEN
        DELETE FROM public.saved_offers
        WHERE user_id = auth.uid() AND offer_id = p_offer_id;
        RETURN FALSE;
    ELSE
        INSERT INTO public.saved_offers (user_id, offer_id)
        VALUES (auth.uid(), p_offer_id);
        RETURN TRUE;
    END IF;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.accept_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_booking(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_in_booking(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_proof(UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_saved_offer(UUID) TO authenticated;
