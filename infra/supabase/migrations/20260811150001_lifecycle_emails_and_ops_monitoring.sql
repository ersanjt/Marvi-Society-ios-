-- Lifecycle emails for members + ops monitoring alerts.
-- Uses existing email_outbox → send-email pipeline.

CREATE OR REPLACE FUNCTION public.marvi_ops_inbox()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT coalesce(
        nullif(trim(current_setting('marvi.ops_inbox', true)), ''),
        'support@marvisociety.com'
    );
$$;

CREATE OR REPLACE FUNCTION public.notify_user_email(
    p_user_id UUID,
    p_template TEXT,
    p_variables JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email TEXT;
    v_locale TEXT := 'tr';
    v_name TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT p.email, coalesce(nullif(p.preferred_locale, ''), 'tr')
    INTO v_email, v_locale
    FROM public.profiles p
    WHERE p.id = p_user_id;

    IF coalesce(trim(v_email), '') = '' THEN
        SELECT email INTO v_email FROM auth.users WHERE id = p_user_id;
    END IF;
    IF coalesce(trim(v_email), '') = '' THEN
        RETURN NULL;
    END IF;

    SELECT coalesce(cp.full_name, split_part(v_email, '@', 1))
    INTO v_name
    FROM public.creator_profiles cp
    WHERE cp.user_id = p_user_id;

    RETURN public.queue_transactional_email(
        p_user_id,
        v_email,
        p_template,
        v_locale,
        coalesce(p_variables, '{}'::JSONB) || jsonb_build_object(
            'name', coalesce(v_name, split_part(v_email, '@', 1)),
            'site_url', 'https://marvisociety.com'
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_ops_email(
    p_event TEXT,
    p_detail TEXT DEFAULT NULL,
    p_variables JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.queue_transactional_email(
        NULL,
        public.marvi_ops_inbox(),
        'admin_ops_alert',
        'tr',
        coalesce(p_variables, '{}'::JSONB) || jsonb_build_object(
            'event', coalesce(p_event, 'System event'),
            'detail', coalesce(p_detail, ''),
            'site_url', 'https://marvisociety.com'
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_user_email(UUID, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_ops_email(TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_user_email(UUID, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.notify_ops_email(TEXT, TEXT, JSONB) TO service_role;

-- Signup: also alert ops (welcome email already queued in handle_new_user).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_locale TEXT;
    v_city TEXT;
    v_name TEXT;
    v_handle TEXT;
    v_tiktok TEXT;
    v_invite TEXT;
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_tiktok := coalesce(NEW.raw_user_meta_data ->> 'tiktok_handle', '');
    v_invite := public.normalize_invite_code(coalesce(NEW.raw_user_meta_data ->> 'invite_code', ''));
    v_locale := public.infer_user_locale(NEW.raw_user_meta_data ->> 'locale', v_city, NULL);

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (NEW.id, NEW.email, 'creator', 'approved', v_locale);

    INSERT INTO public.creator_profiles (
        user_id, full_name, instagram_handle, tiktok_handle, city, languages, status
    ) VALUES (
        NEW.id, v_name, v_handle, v_tiktok, v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END,
        'approved'
    );

    PERFORM public.queue_transactional_email(
        NEW.id, NEW.email, 'welcome_application', v_locale,
        jsonb_build_object('name', v_name, 'city', v_city, 'site_url', 'https://marvisociety.com')
    );

    PERFORM public.notify_ops_email(
        'Yeni üye kaydı',
        format('name=%s email=%s city=%s', v_name, NEW.email, v_city)
    );

    IF v_invite <> '' THEN
        BEGIN
            UPDATE public.referral_codes SET uses_count = uses_count + 1
            WHERE upper(code) = v_invite
              AND (max_uses IS NULL OR uses_count < max_uses)
              AND (invite_email IS NULL OR trim(invite_email) = ''
                   OR lower(trim(invite_email)) = lower(trim(NEW.email)));
            IF FOUND THEN
                UPDATE public.profiles SET referral_code = v_invite WHERE id = NEW.id;
            END IF;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;
    RETURN NEW;
END;
$$;

-- Accept offer: email creator + venue + ops.
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
    v_profile_status public.membership_status;
    v_offer public.offers;
    v_booking public.bookings;
    v_code TEXT;
    v_venue_user UUID;
    v_venue_name TEXT;
    v_creator_name TEXT;
BEGIN
    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN RAISE EXCEPTION 'Member profile not found'; END IF;
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

    SELECT cp.user_id, cp.status, p.status, cp.full_name
    INTO v_creator_user, v_creator_status, v_profile_status, v_creator_name
    FROM public.creator_profiles cp JOIN public.profiles p ON p.id = cp.user_id
    WHERE cp.id = v_creator_id;

    IF v_creator_status = 'paused' OR v_profile_status = 'paused' THEN
        RAISE EXCEPTION 'Membership is paused';
    END IF;

    SELECT * INTO v_offer FROM public.offers
    WHERE id = p_offer_id AND status = 'live' FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Offer not available'; END IF;
    IF v_offer.remaining_slots <= 0 THEN RAISE EXCEPTION 'No slots remaining'; END IF;
    IF v_offer.model = 'gift' AND coalesce(trim(p_shipping_address), '') = '' THEN
        RAISE EXCEPTION 'Shipping address required for gift collaborations';
    END IF;
    IF v_offer.model = 'event' AND coalesce(p_rsvp_guests, 0) < 1 THEN
        RAISE EXCEPTION 'RSVP guest count required for event collaborations';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.bookings
        WHERE offer_id = p_offer_id AND creator_id = v_creator_id AND stage <> 'cancelled'
    ) THEN RAISE EXCEPTION 'Already requested'; END IF;

    v_code := lpad((floor(random() * 9000) + 1000)::TEXT, 4, '0');
    INSERT INTO public.bookings (
        offer_id, creator_id, stage, check_in_code, proof_deadline, proof_deadline_label,
        shipping_address, rsvp_guests
    ) VALUES (
        p_offer_id, v_creator_id, 'invited', v_code,
        coalesce(v_offer.date_end, now() + interval '1 day'),
        coalesce(v_offer.date_label, 'Today') || ', 22:00',
        nullif(trim(p_shipping_address), ''), p_rsvp_guests
    )
    ON CONFLICT (offer_id, creator_id) DO UPDATE SET
        stage = 'invited',
        check_in_code = EXCLUDED.check_in_code,
        proof_deadline = EXCLUDED.proof_deadline,
        proof_deadline_label = EXCLUDED.proof_deadline_label,
        shipping_address = EXCLUDED.shipping_address,
        rsvp_guests = EXCLUDED.rsvp_guests,
        proof_status = 'not_started',
        proof_links = '{}',
        updated_at = now()
    RETURNING * INTO v_booking;

    UPDATE public.offers
    SET remaining_slots = greatest(remaining_slots - 1, 0), updated_at = now()
    WHERE id = p_offer_id;

    INSERT INTO public.collaboration_requests (
        offer_id, creator_id, venue_id, initiated_by, status, booking_id,
        creator_accepted_at, venue_accepted_at
    ) VALUES (
        p_offer_id, v_creator_id, v_offer.venue_id, 'creator', 'pending_venue',
        v_booking.id, now(), NULL
    ) ON CONFLICT (offer_id, creator_id) DO UPDATE SET
        booking_id = EXCLUDED.booking_id, status = 'pending_venue',
        creator_accepted_at = now(), venue_accepted_at = NULL, updated_at = now();

    SELECT owner_user_id, venue_name INTO v_venue_user, v_venue_name
    FROM public.venue_profiles WHERE id = v_offer.venue_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_creator_user, 'Request sent', 'Waiting for the business to confirm your request.',
        'booking', 'hourglass', 'gold',
        jsonb_build_object('booking_id', v_booking.id, 'offer_id', p_offer_id)
    );
    IF v_venue_user IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            v_venue_user, 'New collaboration request',
            'A member wants to collaborate with your business. Review the request to continue.',
            'collaboration', 'person.badge.plus', 'rose',
            jsonb_build_object('booking_id', v_booking.id, 'offer_id', p_offer_id)
        );
    END IF;

    PERFORM public.notify_user_email(
        v_creator_user,
        'booking_requested',
        jsonb_build_object(
            'offer_title', coalesce(v_offer.title, 'Collaboration'),
            'venue_name', coalesce(v_venue_name, 'Business'),
            'booking_id', v_booking.id::TEXT
        )
    );
    IF v_venue_user IS NOT NULL THEN
        PERFORM public.notify_user_email(
            v_venue_user,
            'collaboration_request_venue',
            jsonb_build_object(
                'offer_title', coalesce(v_offer.title, 'Campaign'),
                'creator_name', coalesce(v_creator_name, 'Creator'),
                'booking_id', v_booking.id::TEXT
            )
        );
    END IF;
    PERFORM public.notify_ops_email(
        'Yeni rezervasyon / iş birliği talebi',
        format(
            'offer=%s venue=%s creator=%s booking=%s',
            coalesce(v_offer.title, p_offer_id::TEXT),
            coalesce(v_venue_name, '—'),
            coalesce(v_creator_name, v_creator_user::TEXT),
            v_booking.id::TEXT
        )
    );

    PERFORM public.log_activity_event(
        'offer_requested', 'booking', v_booking.id, jsonb_build_object('offer_id', p_offer_id)
    );
    RETURN v_booking;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_offer(UUID, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_offer(UUID, TEXT, INTEGER) TO authenticated, service_role;

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
    v_venue_name TEXT;
    v_venue_user UUID;
BEGIN
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

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
    -- Slot was already reserved at accept_offer (invited). remaining_slots may be 0;
    -- do not re-check capacity or decrement again.

    UPDATE public.bookings
    SET stage = 'confirmed', updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    UPDATE public.collaboration_requests
    SET status = 'matched',
        venue_accepted_at = now(),
        updated_at = now()
    WHERE booking_id = p_booking_id;

    v_conversation_id := public.ensure_conversation_for_booking(p_booking_id);

    SELECT cp.user_id INTO v_creator_user
    FROM public.creator_profiles cp WHERE cp.id = v_booking.creator_id;

    SELECT vp.venue_name, vp.owner_user_id INTO v_venue_name, v_venue_user
    FROM public.venue_profiles vp WHERE vp.id = v_offer.venue_id;

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

    PERFORM public.notify_user_email(
        v_creator_user,
        'booking_confirmed',
        jsonb_build_object(
            'offer_title', coalesce(v_offer.title, 'Collaboration'),
            'venue_name', coalesce(v_venue_name, 'Business'),
            'booking_id', p_booking_id::TEXT
        )
    );
    IF v_venue_user IS NOT NULL THEN
        PERFORM public.notify_user_email(
            v_venue_user,
            'booking_confirmed',
            jsonb_build_object(
                'offer_title', coalesce(v_offer.title, 'Collaboration'),
                'venue_name', coalesce(v_venue_name, 'Business'),
                'booking_id', p_booking_id::TEXT
            )
        );
    END IF;
    PERFORM public.notify_ops_email(
        'İş birliği onaylandı',
        format('offer=%s venue=%s booking=%s', coalesce(v_offer.title, '—'), coalesce(v_venue_name, '—'), p_booking_id::TEXT)
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

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_user_id UUID := auth.uid();
    v_email TEXT;
    v_name TEXT;
    v_locale TEXT := 'tr';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
    SELECT preferred_locale INTO v_locale FROM public.profiles WHERE id = v_user_id;
    SELECT full_name INTO v_name FROM public.creator_profiles WHERE user_id = v_user_id;
    v_creator_id := public.current_creator_id();

    -- Email user + ops before hard delete removes profile rows.
    IF coalesce(trim(v_email), '') <> '' THEN
        PERFORM public.queue_transactional_email(
            v_user_id,
            v_email,
            'account_deleted',
            coalesce(nullif(v_locale, ''), 'tr'),
            jsonb_build_object(
                'name', coalesce(v_name, split_part(v_email, '@', 1)),
                'site_url', 'https://marvisociety.com'
            )
        );
        PERFORM public.notify_ops_email(
            'Hesap silindi',
            format('email=%s name=%s user_id=%s', v_email, coalesce(v_name, '—'), v_user_id::TEXT)
        );
    END IF;

    DELETE FROM public.admin_tasks t
    WHERE (t.type IN ('creator_application', 'social_verification') AND t.subject_id = v_user_id)
       OR (t.type = 'venue_application' AND EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = t.subject_id AND v.owner_user_id = v_user_id
       ))
       OR (t.type = 'campaign_review' AND EXISTS (
            SELECT 1
            FROM public.offers o
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE o.id = t.subject_id AND v.owner_user_id = v_user_id
       ))
       OR (t.type = 'proof_review' AND EXISTS (
            SELECT 1
            FROM public.bookings b
            JOIN public.offers o ON o.id = b.offer_id
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE b.id = t.subject_id
              AND (b.creator_id = v_creator_id OR v.owner_user_id = v_user_id)
       ));

    DELETE FROM public.device_tokens WHERE user_id = v_user_id;
    DELETE FROM public.user_location_snapshots WHERE user_id = v_user_id;
    DELETE FROM public.saved_offers WHERE user_id = v_user_id;
    DELETE FROM public.notifications WHERE user_id = v_user_id;
    DELETE FROM public.push_outbox WHERE user_id = v_user_id;

    IF v_creator_id IS NOT NULL THEN
        DELETE FROM public.creator_shortlists WHERE creator_id = v_creator_id;
        DELETE FROM public.creator_passes WHERE creator_id = v_creator_id;
        DELETE FROM public.proof_submissions WHERE creator_id = v_creator_id;
        DELETE FROM public.bookings WHERE creator_id = v_creator_id;
        DELETE FROM public.strikes WHERE creator_id = v_creator_id;
    END IF;

    DELETE FROM public.creator_profiles WHERE user_id = v_user_id;
    DELETE FROM public.venue_profiles WHERE owner_user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;

    UPDATE public.deletion_requests
    SET completed_at = now()
    WHERE email = v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- Admin review queue → ops inbox.
CREATE OR REPLACE FUNCTION public.notify_ops_on_admin_task()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'open' THEN
        PERFORM public.notify_ops_email(
            format('Yeni admin görevi: %s', NEW.type),
            format('title=%s | subtitle=%s | id=%s', NEW.title, coalesce(NEW.subtitle, '—'), NEW.id::TEXT)
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS admin_tasks_ops_email ON public.admin_tasks;
CREATE TRIGGER admin_tasks_ops_email
    AFTER INSERT ON public.admin_tasks
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_ops_on_admin_task();

-- Admin monitoring RPCs for web Ops page.
CREATE OR REPLACE FUNCTION public.admin_list_email_outbox(p_limit INTEGER DEFAULT 50)
RETURNS TABLE (
    id UUID,
    to_email TEXT,
    template TEXT,
    locale TEXT,
    status TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;
    RETURN QUERY
    SELECT e.id, e.to_email, e.template, e.locale, e.status, e.error_message, e.created_at, e.sent_at
    FROM public.email_outbox e
    ORDER BY e.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_system_health()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;
    RETURN jsonb_build_object(
        'open_tasks', (SELECT count(*) FROM public.admin_tasks WHERE status = 'open'),
        'live_offers', (SELECT count(*) FROM public.offers WHERE status = 'live'),
        'active_bookings', (SELECT count(*) FROM public.bookings WHERE stage <> 'cancelled'),
        'pending_emails', (SELECT count(*) FROM public.email_outbox WHERE status = 'pending'),
        'failed_emails', (SELECT count(*) FROM public.email_outbox WHERE status = 'failed'),
        'pending_push', (SELECT count(*) FROM public.push_outbox WHERE status = 'pending'),
        'members', (SELECT count(*) FROM public.profiles),
        'venues', (SELECT count(*) FROM public.venue_profiles),
        'deletion_requests_open', (SELECT count(*) FROM public.deletion_requests WHERE completed_at IS NULL)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_email_outbox(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_system_health() TO authenticated;

-- Cancel must restore slots held at accept (invited) as well as confirmed+.
CREATE OR REPLACE FUNCTION public.cancel_booking(p_booking_id UUID)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
    v_prev public.booking_stage;
    v_is_venue BOOLEAN := false;
BEGIN
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.creator_id = public.current_creator_id() THEN
        NULL;
    ELSIF EXISTS (
        SELECT 1
        FROM public.offers o
        JOIN public.venue_profiles v ON v.id = o.venue_id
        WHERE o.id = v_booking.offer_id AND v.owner_user_id = auth.uid()
    ) THEN
        v_is_venue := true;
    ELSIF public.is_admin() THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.stage = 'cancelled' THEN
        RETURN v_booking;
    END IF;

    v_prev := v_booking.stage;

    UPDATE public.bookings
    SET stage = 'cancelled', updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    IF v_prev IN ('invited', 'confirmed', 'checked_in', 'proof_due', 'completed') THEN
        UPDATE public.offers
        SET remaining_slots = LEAST(remaining_slots + 1, capacity)
        WHERE id = v_booking.offer_id;
    END IF;

    RETURN v_booking;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_booking(UUID) TO authenticated;

-- Repair capacity counters from non-cancelled bookings.
UPDATE public.offers o
SET remaining_slots = greatest(
        o.capacity - (
            SELECT count(*)::INTEGER
            FROM public.bookings b
            WHERE b.offer_id = o.id AND b.stage <> 'cancelled'
        ),
        0
    ),
    updated_at = now();

