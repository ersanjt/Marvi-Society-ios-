-- Mutual-match collaboration, in-app chat, and admin activity feed.

-- ---------------------------------------------------------------------------
-- 1. Activity events (admin audit trail)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.activity_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    subject_type TEXT NOT NULL DEFAULT '',
    subject_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_events_created
    ON public.activity_events (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_events_actor
    ON public.activity_events (actor_user_id, created_at DESC);

ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS activity_events_admin_select ON public.activity_events;
CREATE POLICY activity_events_admin_select ON public.activity_events
    FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS activity_events_insert ON public.activity_events;
CREATE POLICY activity_events_insert ON public.activity_events
    FOR INSERT WITH CHECK (actor_user_id = auth.uid() OR public.is_admin());

CREATE OR REPLACE FUNCTION public.log_activity_event(
    p_action TEXT,
    p_subject_type TEXT DEFAULT '',
    p_subject_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.activity_events (actor_user_id, action, subject_type, subject_id, metadata)
    VALUES (auth.uid(), trim(p_action), coalesce(p_subject_type, ''), p_subject_id, coalesce(p_metadata, '{}'::JSONB));
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_activity_event(TEXT, TEXT, UUID, JSONB) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_list_activity(p_limit INTEGER DEFAULT 50)
RETURNS SETOF public.activity_events
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;
    RETURN QUERY
    SELECT *
    FROM public.activity_events
    ORDER BY created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_activity(INTEGER) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Conversations + messages (chat after mutual match)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings (id) ON DELETE CASCADE,
    creator_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    venue_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversations_creator
    ON public.conversations (creator_user_id);

CREATE INDEX IF NOT EXISTS idx_conversations_venue
    ON public.conversations (venue_user_id);

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT messages_body_not_empty CHECK (length(trim(body)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation
    ON public.messages (conversation_id, created_at ASC);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS conversations_select ON public.conversations;
CREATE POLICY conversations_select ON public.conversations
    FOR SELECT USING (
        creator_user_id = auth.uid()
        OR venue_user_id = auth.uid()
        OR public.is_admin()
    );

DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = messages.conversation_id
              AND (c.creator_user_id = auth.uid() OR c.venue_user_id = auth.uid() OR public.is_admin())
        )
    );

DROP POLICY IF EXISTS messages_insert ON public.messages;
CREATE POLICY messages_insert ON public.messages
    FOR INSERT WITH CHECK (
        sender_user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_id
              AND (c.creator_user_id = auth.uid() OR c.venue_user_id = auth.uid())
        )
    );

GRANT SELECT ON public.conversations TO authenticated;
GRANT SELECT, INSERT ON public.messages TO authenticated;

CREATE OR REPLACE FUNCTION public.ensure_conversation_for_booking(p_booking_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
    v_creator_user UUID;
    v_venue_user UUID;
    v_conversation_id UUID;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    SELECT cp.user_id INTO v_creator_user
    FROM public.creator_profiles cp WHERE cp.id = v_booking.creator_id;

    SELECT vp.owner_user_id INTO v_venue_user
    FROM public.offers o
    JOIN public.venue_profiles vp ON vp.id = o.venue_id
    WHERE o.id = v_booking.offer_id;

    IF v_creator_user IS NULL OR v_venue_user IS NULL THEN
        RAISE EXCEPTION 'Participants not found';
    END IF;

    SELECT id INTO v_conversation_id FROM public.conversations WHERE booking_id = p_booking_id;
    IF FOUND THEN
        RETURN v_conversation_id;
    END IF;

    INSERT INTO public.conversations (booking_id, creator_user_id, venue_user_id)
    VALUES (p_booking_id, v_creator_user, v_venue_user)
    RETURNING id INTO v_conversation_id;

    RETURN v_conversation_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_conversation_for_booking(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_conversations()
RETURNS TABLE (
    id UUID,
    booking_id UUID,
    creator_user_id UUID,
    venue_user_id UUID,
    offer_title TEXT,
    venue_name TEXT,
    last_message TEXT,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        c.id,
        c.booking_id,
        c.creator_user_id,
        c.venue_user_id,
        o.title,
        vp.venue_name,
        (
            SELECT m.body FROM public.messages m
            WHERE m.conversation_id = c.id
            ORDER BY m.created_at DESC
            LIMIT 1
        ),
        (
            SELECT m.created_at FROM public.messages m
            WHERE m.conversation_id = c.id
            ORDER BY m.created_at DESC
            LIMIT 1
        ),
        c.created_at
    FROM public.conversations c
    JOIN public.bookings b ON b.id = c.booking_id
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles vp ON vp.id = o.venue_id
    WHERE c.creator_user_id = auth.uid() OR c.venue_user_id = auth.uid()
    ORDER BY coalesce(
        (SELECT max(m.created_at) FROM public.messages m WHERE m.conversation_id = c.id),
        c.created_at
    ) DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_conversations() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_conversation_messages(p_conversation_id UUID)
RETURNS SETOF public.messages
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT m.*
    FROM public.messages m
    JOIN public.conversations c ON c.id = m.conversation_id
    WHERE m.conversation_id = p_conversation_id
      AND (c.creator_user_id = auth.uid() OR c.venue_user_id = auth.uid() OR public.is_admin())
    ORDER BY m.created_at ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_conversation_messages(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.send_message(p_conversation_id UUID, p_body TEXT)
RETURNS public.messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_message public.messages;
    v_body TEXT := trim(p_body);
    v_recipient UUID;
    v_conversation public.conversations;
BEGIN
    IF v_body = '' THEN
        RAISE EXCEPTION 'Message cannot be empty';
    END IF;

    SELECT * INTO v_conversation FROM public.conversations WHERE id = p_conversation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conversation not found';
    END IF;

    IF auth.uid() NOT IN (v_conversation.creator_user_id, v_conversation.venue_user_id) THEN
        RAISE EXCEPTION 'Not a participant';
    END IF;

    INSERT INTO public.messages (conversation_id, sender_user_id, body)
    VALUES (p_conversation_id, auth.uid(), v_body)
    RETURNING * INTO v_message;

    v_recipient := CASE
        WHEN auth.uid() = v_conversation.creator_user_id THEN v_conversation.venue_user_id
        ELSE v_conversation.creator_user_id
    END;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_recipient,
        'New message',
        left(v_body, 120),
        'message',
        'bubble.left.and.bubble.right.fill',
        'rose',
        jsonb_build_object('conversation_id', p_conversation_id, 'booking_id', v_conversation.booking_id)
    );

    PERFORM public.log_activity_event(
        'message_sent',
        'conversation',
        p_conversation_id,
        jsonb_build_object('length', length(v_body))
    );

    RETURN v_message;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_message(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Collaboration requests (mutual acceptance)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.collaboration_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID NOT NULL REFERENCES public.offers (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    initiated_by TEXT NOT NULL CHECK (initiated_by IN ('creator', 'venue')),
    status TEXT NOT NULL DEFAULT 'pending_creator'
        CHECK (status IN ('pending_creator', 'pending_venue', 'matched', 'declined', 'cancelled')),
    booking_id UUID REFERENCES public.bookings (id) ON DELETE SET NULL,
    creator_accepted_at TIMESTAMPTZ,
    venue_accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (offer_id, creator_id)
);

CREATE INDEX IF NOT EXISTS idx_collab_requests_status
    ON public.collaboration_requests (status, updated_at DESC);

ALTER TABLE public.collaboration_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS collab_requests_select ON public.collaboration_requests;
CREATE POLICY collab_requests_select ON public.collaboration_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.creator_profiles cp
            WHERE cp.id = collaboration_requests.creator_id AND cp.user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles vp
            WHERE vp.id = collaboration_requests.venue_id AND vp.owner_user_id = auth.uid()
        )
        OR public.is_admin()
    );

-- ---------------------------------------------------------------------------
-- 4. Creator accepts offer → pending venue confirmation (mutual match)
-- ---------------------------------------------------------------------------
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

-- Venue confirms creator request → confirmed + chat
CREATE OR REPLACE FUNCTION public.venue_confirm_booking(p_booking_id UUID)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
    v_offer public.offers;
    v_creator_user UUID;
    v_conversation_id UUID;
BEGIN
    SELECT b.* INTO v_booking
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles vp ON vp.id = o.venue_id
    WHERE b.id = p_booking_id AND vp.owner_user_id = auth.uid()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found or not authorized';
    END IF;

    IF v_booking.stage <> 'invited' THEN
        RAISE EXCEPTION 'Booking is not awaiting confirmation';
    END IF;

    SELECT * INTO v_offer FROM public.offers WHERE id = v_booking.offer_id FOR UPDATE;
    IF v_offer.remaining_slots <= 0 THEN
        RAISE EXCEPTION 'No slots remaining';
    END IF;

    UPDATE public.bookings
    SET stage = 'confirmed', updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    UPDATE public.offers
    SET remaining_slots = remaining_slots - 1
    WHERE id = v_booking.offer_id;

    UPDATE public.collaboration_requests
    SET status = 'matched',
        venue_accepted_at = now(),
        updated_at = now()
    WHERE booking_id = p_booking_id;

    v_conversation_id := public.ensure_conversation_for_booking(p_booking_id);

    SELECT cp.user_id INTO v_creator_user
    FROM public.creator_profiles cp WHERE cp.id = v_booking.creator_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_creator_user,
        'Collaboration confirmed',
        'The venue confirmed. You can now chat in Messages.',
        'booking',
        'checkmark.circle.fill',
        'emerald',
        jsonb_build_object('booking_id', p_booking_id, 'conversation_id', v_conversation_id)
    );

    PERFORM public.log_activity_event(
        'venue_confirmed_booking',
        'booking',
        p_booking_id,
        jsonb_build_object('conversation_id', v_conversation_id)
    );

    RETURN v_booking;
END;
$$;

GRANT EXECUTE ON FUNCTION public.venue_confirm_booking(UUID) TO authenticated;

-- Creator accepts venue shortlist / invitation
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
BEGIN
    SELECT * INTO v_request
    FROM public.collaboration_requests cr
    JOIN public.creator_profiles cp ON cp.id = cr.creator_id
    WHERE cr.id = p_request_id AND cp.user_id = auth.uid()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    IF v_request.status NOT IN ('pending_creator') THEN
        RAISE EXCEPTION 'Request is not pending creator acceptance';
    END IF;

    SELECT * INTO v_offer FROM public.offers WHERE id = v_request.offer_id FOR UPDATE;
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

    PERFORM public.log_activity_event(
        'creator_accepted_collaboration',
        'collaboration_request',
        p_request_id,
        jsonb_build_object('booking_id', v_booking.id)
    );

    RETURN v_booking;
END;
$$;

GRANT EXECUTE ON FUNCTION public.creator_accept_collaboration(UUID) TO authenticated;

-- Venue shortlist → collaboration request pending creator
CREATE OR REPLACE FUNCTION public.shortlist_creator(
    p_creator_id UUID,
    p_offer_id UUID DEFAULT NULL,
    p_venue_id UUID DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue_id UUID;
    v_creator_user UUID;
    v_request_id UUID;
BEGIN
    IF p_offer_id IS NOT NULL THEN
        SELECT o.venue_id INTO v_venue_id
        FROM public.offers o
        JOIN public.venue_profiles v ON v.id = o.venue_id
        WHERE o.id = p_offer_id AND v.owner_user_id = auth.uid();
    ELSE
        v_venue_id := public.resolve_active_venue_id(p_venue_id);
    END IF;

    IF v_venue_id IS NULL THEN
        RAISE EXCEPTION 'No venue profile';
    END IF;

    INSERT INTO public.creator_shortlists (venue_id, creator_id, offer_id)
    VALUES (v_venue_id, p_creator_id, p_offer_id)
    ON CONFLICT DO NOTHING;

    IF p_offer_id IS NOT NULL THEN
        INSERT INTO public.collaboration_requests (
            offer_id, creator_id, venue_id, initiated_by, status, venue_accepted_at
        ) VALUES (
            p_offer_id, p_creator_id, v_venue_id, 'venue', 'pending_creator', now()
        )
        ON CONFLICT (offer_id, creator_id) DO UPDATE
        SET status = 'pending_creator',
            venue_accepted_at = now(),
            initiated_by = 'venue',
            updated_at = now()
        RETURNING id INTO v_request_id;
    END IF;

    SELECT user_id INTO v_creator_user FROM public.creator_profiles WHERE id = p_creator_id;

    IF v_creator_user IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            v_creator_user,
            'Venue invited you',
            'A venue partner wants to collaborate. Accept to start chatting.',
            'collaboration',
            'star.fill',
            'gold',
            jsonb_build_object(
                'creator_id', p_creator_id,
                'offer_id', p_offer_id,
                'request_id', v_request_id
            )
        );
    END IF;

    PERFORM public.log_activity_event(
        'creator_shortlisted',
        'creator',
        p_creator_id,
        jsonb_build_object('offer_id', p_offer_id, 'venue_id', v_venue_id)
    );
END;
$$;

-- Pending collaboration requests for current user (creator or venue)
CREATE OR REPLACE FUNCTION public.get_my_pending_collaboration_requests()
RETURNS TABLE (
    id UUID,
    offer_id UUID,
    offer_title TEXT,
    venue_name TEXT,
    status TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_venue_ids UUID[];
BEGIN
    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NOT NULL THEN
        RETURN QUERY
        SELECT
            cr.id,
            cr.offer_id,
            o.title,
            vp.name,
            cr.status,
            cr.created_at
        FROM public.collaboration_requests cr
        JOIN public.offers o ON o.id = cr.offer_id
        JOIN public.venue_profiles vp ON vp.id = cr.venue_id
        WHERE cr.creator_id = v_creator_id
          AND cr.status = 'pending_creator'
        ORDER BY cr.created_at DESC;
        RETURN;
    END IF;

    SELECT array_agg(vp.id) INTO v_venue_ids
    FROM public.venue_profiles vp
    WHERE vp.owner_user_id = auth.uid();

    IF v_venue_ids IS NOT NULL THEN
        RETURN QUERY
        SELECT
            cr.id,
            cr.offer_id,
            o.title,
            vp.name,
            cr.status,
            cr.created_at
        FROM public.collaboration_requests cr
        JOIN public.offers o ON o.id = cr.offer_id
        JOIN public.venue_profiles vp ON vp.id = cr.venue_id
        WHERE cr.venue_id = ANY (v_venue_ids)
          AND cr.status = 'pending_venue'
        ORDER BY cr.created_at DESC;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_pending_collaboration_requests() TO authenticated;
