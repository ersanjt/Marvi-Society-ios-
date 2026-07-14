-- Soften accept_offer: keep Instagram OR TikTok handle, drop hard DM-verify gate.
-- Social verification remains a profile-health / admin trust signal.

CREATE OR REPLACE FUNCTION public.accept_offer(
    p_offer_id UUID,
    p_shipping_address TEXT DEFAULT NULL,
    p_rsvp_guests INTEGER DEFAULT NULL
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_creator_user UUID;
    v_creator_status public.membership_status;
    v_creator public.creator_profiles%ROWTYPE;
    v_offer public.offers;
    v_booking public.bookings;
    v_code TEXT;
    v_venue_user UUID;
BEGIN
    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    SELECT user_id INTO v_creator_user FROM public.creator_profiles WHERE id = v_creator_id;

    SELECT status INTO v_creator_status
    FROM public.creator_profiles
    WHERE id = v_creator_id;

    IF v_creator_status IS DISTINCT FROM 'approved' THEN
        RAISE EXCEPTION 'Membership not approved yet';
    END IF;

    IF NOT public.is_admin() THEN
        SELECT * INTO v_creator FROM public.creator_profiles WHERE id = v_creator_id;
        IF coalesce(trim(v_creator.instagram_handle), '') = ''
            AND coalesce(trim(v_creator.tiktok_handle), '') = '' THEN
            RAISE EXCEPTION 'Instagram or TikTok handle required';
        END IF;

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

    IF v_offer.model = 'gift'::public.collaboration_model AND coalesce(trim(p_shipping_address), '') = '' THEN
        RAISE EXCEPTION 'Shipping address required for gift collaborations';
    END IF;

    IF v_offer.model = 'event'::public.collaboration_model AND coalesce(p_rsvp_guests, 0) < 1 THEN
        RAISE EXCEPTION 'RSVP guest count required for event collaborations';
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
        proof_deadline_label,
        shipping_address,
        rsvp_guests
    ) VALUES (
        p_offer_id,
        v_creator_id,
        'invited',
        v_code,
        COALESCE(v_offer.date_end, now() + interval '1 day'),
        COALESCE(v_offer.date_label, 'Today') || ', 22:00',
        nullif(trim(p_shipping_address), ''),
        p_rsvp_guests
    )
    RETURNING * INTO v_booking;

    INSERT INTO public.collaboration_requests (
        offer_id, creator_id, venue_id, initiated_by, status,
        booking_id, creator_accepted_at, venue_accepted_at
    ) VALUES (
        p_offer_id, v_creator_id, v_offer.venue_id, 'creator', 'pending_venue',
        v_booking.id, now(), NULL
    )
    ON CONFLICT (offer_id, creator_id) DO UPDATE
    SET booking_id = EXCLUDED.booking_id,
        status = 'pending_venue',
        creator_accepted_at = now(),
        updated_at = now();

    SELECT vp.owner_user_id INTO v_venue_user
    FROM public.venue_profiles vp WHERE vp.id = v_offer.venue_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_creator_user,
        'Request sent',
        'Waiting for the venue to confirm your collaboration.',
        'booking',
        'hourglass',
        'gold',
        jsonb_build_object('booking_id', v_booking.id, 'offer_id', p_offer_id)
    );

    IF v_venue_user IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            v_venue_user,
            'Creator wants to collaborate',
            'A creator accepted your offer. Confirm to start chatting.',
            'collaboration',
            'person.badge.plus',
            'rose',
            jsonb_build_object('booking_id', v_booking.id, 'offer_id', p_offer_id)
        );
    END IF;

    PERFORM public.log_activity_event(
        'offer_accepted_pending',
        'booking',
        v_booking.id,
        jsonb_build_object('offer_id', p_offer_id)
    );

    RETURN v_booking;
END;
$$;
