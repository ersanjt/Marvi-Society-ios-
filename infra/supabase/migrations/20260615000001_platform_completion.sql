-- Platform completion: inbox payloads, device tokens, gift/event accept extras, analytics events

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS payload JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS shipping_address TEXT,
    ADD COLUMN IF NOT EXISTS rsvp_guests INTEGER;

CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, platform)
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY device_tokens_own ON public.device_tokens
    FOR ALL USING (user_id = auth.uid());

CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    properties JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY analytics_events_insert ON public.analytics_events
    FOR INSERT WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY analytics_events_admin ON public.analytics_events
    FOR SELECT USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.notifications
    SET read_at = now()
    WHERE id = p_notification_id
      AND user_id = auth.uid()
      AND read_at IS NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.register_device_token(p_token TEXT, p_platform TEXT DEFAULT 'ios')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO public.device_tokens (user_id, token, platform, updated_at)
    VALUES (auth.uid(), trim(p_token), coalesce(nullif(trim(p_platform), ''), 'ios'), now())
    ON CONFLICT (user_id, platform) DO UPDATE SET
        token = EXCLUDED.token,
        updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.track_analytics_event(p_name TEXT, p_properties JSONB DEFAULT '{}'::JSONB)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.analytics_events (user_id, name, properties)
    VALUES (auth.uid(), trim(p_name), coalesce(p_properties, '{}'::JSONB));
END;
$$;

GRANT EXECUTE ON FUNCTION public.track_analytics_event(TEXT, JSONB) TO authenticated;

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
    v_creator_status public.membership_status;
    v_offer public.offers;
    v_booking public.bookings;
    v_code TEXT;
BEGIN
    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

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
        'confirmed',
        v_code,
        COALESCE(v_offer.date_end, now() + interval '1 day'),
        COALESCE(v_offer.date_label, 'Today') || ', 22:00',
        nullif(trim(p_shipping_address), ''),
        p_rsvp_guests
    )
    RETURNING * INTO v_booking;

    UPDATE public.offers
    SET remaining_slots = remaining_slots - 1
    WHERE id = p_offer_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    SELECT
        cp.user_id,
        CASE v_offer.model
            WHEN 'event'::public.collaboration_model THEN 'RSVP confirmed'
            WHEN 'gift'::public.collaboration_model THEN 'Gift collaboration confirmed'
            WHEN 'instant'::public.collaboration_model THEN 'Instant offer confirmed'
            ELSE 'Invitation confirmed'
        END,
        v.venue_name || ' is now in your bookings.',
        'booking',
        'checkmark.circle.fill',
        'emerald',
        jsonb_build_object('booking_id', v_booking.id, 'offer_id', p_offer_id)
    FROM public.creator_profiles cp
    JOIN public.offers o ON o.id = p_offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE cp.id = v_creator_id;

    RETURN v_booking;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_offer(UUID, TEXT, INTEGER) TO authenticated;
