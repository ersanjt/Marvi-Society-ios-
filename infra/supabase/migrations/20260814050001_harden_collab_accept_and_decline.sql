-- Harden collaboration accept + add decline path for venue invites.

CREATE OR REPLACE FUNCTION public.creator_accept_collaboration(p_request_id UUID)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request public.collaboration_requests;
    v_offer public.offers;
    v_booking public.bookings;
    v_code TEXT;
    v_venue_user UUID;
    v_conversation_id UUID;
    v_creator_status public.membership_status;
    v_profile_status public.membership_status;
BEGIN
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

    SELECT cr.* INTO v_request
    FROM public.collaboration_requests cr
    JOIN public.creator_profiles cp ON cp.id = cr.creator_id
    WHERE cr.id = p_request_id AND cp.user_id = auth.uid()
    FOR UPDATE OF cr;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    SELECT cp.status, p.status
    INTO v_creator_status, v_profile_status
    FROM public.creator_profiles cp
    JOIN public.profiles p ON p.id = cp.user_id
    WHERE cp.id = v_request.creator_id;

    IF v_creator_status = 'paused' OR v_profile_status = 'paused' THEN
        RAISE EXCEPTION 'Membership is paused';
    END IF;

    IF v_request.status NOT IN ('pending_creator') THEN
        RAISE EXCEPTION 'Request is not pending creator acceptance';
    END IF;

    SELECT * INTO v_offer FROM public.offers WHERE id = v_request.offer_id FOR UPDATE;
    IF NOT FOUND OR v_offer.status IS DISTINCT FROM 'live' OR v_offer.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Offer is not available';
    END IF;
    IF v_offer.remaining_slots <= 0 THEN
        RAISE EXCEPTION 'No slots remaining';
    END IF;

    v_code := lpad((floor(random() * 9000) + 1000)::TEXT, 4, '0');

    INSERT INTO public.bookings (
        offer_id, creator_id, stage, check_in_code,
        proof_deadline, proof_deadline_label
    ) VALUES (
        v_request.offer_id,
        v_request.creator_id,
        'confirmed',
        v_code,
        COALESCE(v_offer.date_end, now() + interval '1 day'),
        COALESCE(v_offer.date_label, 'Today') || ', 22:00'
    )
    RETURNING * INTO v_booking;

    UPDATE public.offers SET remaining_slots = remaining_slots - 1 WHERE id = v_request.offer_id;

    UPDATE public.collaboration_requests
    SET status = 'matched',
        booking_id = v_booking.id,
        creator_accepted_at = now(),
        updated_at = now()
    WHERE id = p_request_id;

    v_conversation_id := public.ensure_conversation_for_booking(v_booking.id);

    SELECT vp.owner_user_id INTO v_venue_user
    FROM public.venue_profiles vp WHERE vp.id = v_request.venue_id;

    IF v_venue_user IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            v_venue_user,
            'Creator accepted your invite',
            'Collaboration confirmed. Open Messages to chat.',
            'collaboration',
            'checkmark.circle.fill',
            'emerald',
            jsonb_build_object('booking_id', v_booking.id, 'conversation_id', v_conversation_id)
        );
    END IF;

    BEGIN
        PERFORM public.log_activity_event(
            'creator_accepted_collaboration',
            'collaboration_request',
            p_request_id,
            jsonb_build_object('booking_id', v_booking.id, 'offer_id', v_request.offer_id)
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN v_booking;
END;
$$;

REVOKE ALL ON FUNCTION public.creator_accept_collaboration(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.creator_accept_collaboration(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.creator_decline_collaboration(p_request_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request public.collaboration_requests;
    v_venue_user UUID;
BEGIN
    SELECT cr.* INTO v_request
    FROM public.collaboration_requests cr
    JOIN public.creator_profiles cp ON cp.id = cr.creator_id
    WHERE cr.id = p_request_id AND cp.user_id = auth.uid()
    FOR UPDATE OF cr;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    IF v_request.status <> 'pending_creator' THEN
        RAISE EXCEPTION 'Request is not pending creator acceptance';
    END IF;

    UPDATE public.collaboration_requests
    SET status = 'declined',
        updated_at = now()
    WHERE id = p_request_id;

    SELECT vp.owner_user_id INTO v_venue_user
    FROM public.venue_profiles vp WHERE vp.id = v_request.venue_id;

    IF v_venue_user IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            v_venue_user,
            'Creator declined your invite',
            'They passed on this collaboration. You can invite someone else.',
            'collaboration',
            'xmark.circle.fill',
            'tomato',
            jsonb_build_object('offer_id', v_request.offer_id, 'request_id', p_request_id)
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.creator_decline_collaboration(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.creator_decline_collaboration(UUID) TO authenticated, service_role;
