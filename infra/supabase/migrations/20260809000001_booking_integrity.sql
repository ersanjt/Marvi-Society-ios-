-- Booking integrity: lock privileged booking columns, stage-gate check-in/proof,
-- fix cancel slot restore, allow lifecycle RPCs past privilege guards,
-- revoke JWT access to service_role in marvi_runtime_settings.

-- ---------------------------------------------------------------------------
-- Session GUCs for SECURITY DEFINER RPCs that must mutate privileged columns
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.marvi_allow_booking_mutation()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT coalesce(current_setting('marvi.allow_booking_mutation', true), '') = '1';
$$;

CREATE OR REPLACE FUNCTION public.marvi_allow_lifecycle()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT coalesce(current_setting('marvi.allow_lifecycle', true), '') = '1';
$$;

-- Keep check-in secrets outside the exposed `public` schema. The legacy
-- bookings.check_in_code column remains for client compatibility, but is
-- always blank after this migration.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.booking_check_in_secrets (
    booking_id UUID PRIMARY KEY REFERENCES public.bookings (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    code TEXT NOT NULL CHECK (length(code) BETWEEN 4 AND 12),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE private.booking_check_in_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_check_in_secrets FROM PUBLIC, anon, authenticated;
GRANT ALL ON private.booking_check_in_secrets TO service_role;

INSERT INTO private.booking_check_in_secrets (booking_id, code)
SELECT id, trim(check_in_code)
FROM public.bookings
WHERE trim(coalesce(check_in_code, '')) <> ''
ON CONFLICT (booking_id) DO UPDATE
SET code = EXCLUDED.code, updated_at = now();

SELECT set_config('marvi.allow_booking_mutation', '1', true);
UPDATE public.bookings
SET check_in_code = ''
WHERE check_in_code <> '';

CREATE OR REPLACE FUNCTION public.capture_booking_check_in_secret()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, pg_temp
AS $$
BEGIN
    IF trim(coalesce(NEW.check_in_code, '')) = '' THEN
        NEW.check_in_code := '';
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE'
       AND current_setting('marvi.allow_booking_mutation', true) IS DISTINCT FROM '1'
       AND (select auth.jwt()->>'role') IS DISTINCT FROM 'service_role'
       AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Check-in code cannot be modified directly';
    END IF;

    INSERT INTO private.booking_check_in_secrets (booking_id, code)
    VALUES (NEW.id, trim(NEW.check_in_code))
    ON CONFLICT (booking_id) DO UPDATE
    SET code = EXCLUDED.code, updated_at = now();

    NEW.check_in_code := '';
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS capture_booking_check_in_secret ON public.bookings;
CREATE TRIGGER capture_booking_check_in_secret
    BEFORE INSERT OR UPDATE OF check_in_code ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.capture_booking_check_in_secret();

-- Booking creation is an RPC-only operation. SECURITY DEFINER lifecycle RPCs
-- bypass RLS after validating offer, creator, capacity, and eligibility.
DROP POLICY IF EXISTS bookings_insert_creator ON public.bookings;
DROP POLICY IF EXISTS bookings_insert_admin ON public.bookings;
CREATE POLICY bookings_insert_admin ON public.bookings
    FOR INSERT TO authenticated
    WITH CHECK (public.is_admin());

-- ---------------------------------------------------------------------------
-- Guard: creators cannot PATCH stage / check_in_code / proof fields directly
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_booking_privileged_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (select auth.jwt()->>'role') = 'service_role'
       OR public.is_admin()
       OR public.marvi_allow_booking_mutation() THEN
        RETURN NEW;
    END IF;

    IF NEW.stage IS DISTINCT FROM OLD.stage THEN
        RAISE EXCEPTION 'Booking stage can only change via official RPCs';
    END IF;
    IF NEW.check_in_code IS DISTINCT FROM OLD.check_in_code THEN
        RAISE EXCEPTION 'Check-in code cannot be modified directly';
    END IF;
    IF NEW.proof_status IS DISTINCT FROM OLD.proof_status THEN
        RAISE EXCEPTION 'Proof status can only change via official RPCs';
    END IF;
    IF NEW.proof_links IS DISTINCT FROM OLD.proof_links THEN
        RAISE EXCEPTION 'Proof links can only change via submit_proof';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_booking_privileged_columns ON public.bookings;
CREATE TRIGGER guard_booking_privileged_columns
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.guard_booking_privileged_columns();

-- Drop broad creator UPDATE; venues still need limited updates via RPC only.
DROP POLICY IF EXISTS bookings_update_own ON public.bookings;
CREATE POLICY bookings_update_own ON public.bookings
    FOR UPDATE USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ---------------------------------------------------------------------------
-- Privilege guards: allow lifecycle RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_profiles_privileged()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (select auth.jwt()->>'role') = 'service_role'
       OR public.is_admin()
       OR public.marvi_allow_lifecycle() THEN
        RETURN NEW;
    END IF;
    IF NEW.role IS DISTINCT FROM OLD.role THEN
        RAISE EXCEPTION 'Not authorized to change role';
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Not authorized to change membership status';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_creator_profiles_privileged()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (select auth.jwt()->>'role') = 'service_role'
       OR public.is_admin()
       OR public.marvi_allow_lifecycle() THEN
        RETURN NEW;
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Not authorized to change creator status';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_venue_profiles_privileged()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (select auth.jwt()->>'role') = 'service_role'
       OR public.is_admin()
       OR public.marvi_allow_lifecycle() THEN
        RETURN NEW;
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Not authorized to change venue status';
    END IF;
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Lifecycle RPCs: set GUC before status updates
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pause_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current public.membership_status;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT status INTO v_current FROM public.profiles WHERE id = v_user_id;
    IF v_current IS NULL THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    IF v_current = 'paused' THEN
        RETURN;
    END IF;

    PERFORM set_config('marvi.allow_lifecycle', '1', true);
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

    UPDATE public.profiles
    SET status = 'paused',
        paused_by_self = true,
        status_before_pause = v_current,
        updated_at = now()
    WHERE id = v_user_id;

    UPDATE public.creator_profiles
    SET status = 'paused', updated_at = now()
    WHERE user_id = v_user_id;

    UPDATE public.venue_profiles
    SET status = 'paused', updated_at = now()
    WHERE owner_user_id = v_user_id;

    UPDATE public.bookings b
    SET stage = 'cancelled', updated_at = now()
    FROM public.creator_profiles cp
    WHERE cp.user_id = v_user_id
      AND b.creator_id = cp.id
      AND b.stage IN ('invited', 'confirmed');

    DELETE FROM public.device_tokens WHERE user_id = v_user_id;
    DELETE FROM public.user_location_snapshots WHERE user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reactivate_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_restore public.membership_status;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = v_user_id AND status = 'paused' AND paused_by_self = true
    ) THEN
        RAISE EXCEPTION 'Account cannot be reactivated in-app. Contact support@marvisociety.com.';
    END IF;

    SELECT COALESCE(status_before_pause, 'under_review')
    INTO v_restore
    FROM public.profiles
    WHERE id = v_user_id;

    PERFORM set_config('marvi.allow_lifecycle', '1', true);

    UPDATE public.profiles
    SET status = v_restore,
        paused_by_self = false,
        status_before_pause = NULL,
        updated_at = now()
    WHERE id = v_user_id;

    UPDATE public.creator_profiles
    SET status = v_restore, updated_at = now()
    WHERE user_id = v_user_id;

    UPDATE public.venue_profiles
    SET status = v_restore, updated_at = now()
    WHERE owner_user_id = v_user_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- cancel_booking: restore slot only if a slot was consumed (confirmed+)
-- ---------------------------------------------------------------------------
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

    IF v_prev IN ('confirmed', 'checked_in', 'proof_due', 'completed') THEN
        UPDATE public.offers
        SET remaining_slots = LEAST(remaining_slots + 1, capacity)
        WHERE id = v_booking.offer_id;
    END IF;

    RETURN v_booking;
END;
$$;

-- ---------------------------------------------------------------------------
-- check_in_booking: only from confirmed; mutation via GUC
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_in_booking(p_booking_id UUID, p_code TEXT)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking public.bookings;
    v_expected_code TEXT;
BEGIN
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id AND creator_id = public.current_creator_id()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.stage <> 'confirmed' THEN
        RAISE EXCEPTION 'Check-in is only available for confirmed bookings';
    END IF;

    SELECT s.code INTO v_expected_code
    FROM private.booking_check_in_secrets s
    WHERE s.booking_id = p_booking_id;

    IF trim(coalesce(p_code, '')) = '' OR v_expected_code IS DISTINCT FROM trim(p_code) THEN
        RAISE EXCEPTION 'Invalid check-in code';
    END IF;

    UPDATE public.bookings
    SET stage = 'checked_in', updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    DELETE FROM private.booking_check_in_secrets WHERE booking_id = p_booking_id;

    -- Never return the secret code to the creator client
    v_booking.check_in_code := '';
    RETURN v_booking;
END;
$$;

-- ---------------------------------------------------------------------------
-- submit_proof: only after check-in / proof_due
-- ---------------------------------------------------------------------------
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
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

    v_creator_id := public.current_creator_id();

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id AND creator_id = v_creator_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.stage NOT IN ('checked_in', 'proof_due') THEN
        RAISE EXCEPTION 'Proof can only be submitted after check-in';
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
        proof_links = p_links,
        updated_at = now()
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
        coalesce(v_venue_name, 'Venue') || ' proof',
        array_length(p_links, 1)::TEXT || ' proof link(s) submitted.',
        'Medium'
    );

    v_booking.check_in_code := '';
    RETURN v_booking;
END;
$$;

-- Venue-only: reveal check-in code for a booking they own
CREATE OR REPLACE FUNCTION public.get_booking_check_in_code(p_booking_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
BEGIN
    SELECT s.code INTO v_code
    FROM public.bookings b
    JOIN private.booking_check_in_secrets s ON s.booking_id = b.id
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE b.id = p_booking_id
      AND (v.owner_user_id = auth.uid() OR public.is_admin());

    IF v_code IS NULL THEN
        RAISE EXCEPTION 'Booking not found or not authorized';
    END IF;

    RETURN v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_booking_check_in_code(UUID) TO authenticated;

-- Ensure venue_confirm and accept_offer set mutation GUC when updating bookings
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

-- ---------------------------------------------------------------------------
-- Runtime settings: never expose service_role_key to JWT roles
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.marvi_runtime_settings FROM authenticated;
REVOKE ALL ON public.marvi_runtime_settings FROM PUBLIC;
DROP POLICY IF EXISTS marvi_runtime_settings_admin ON public.marvi_runtime_settings;
DELETE FROM public.marvi_runtime_settings WHERE key = 'service_role_key';

-- SECURITY DEFINER functions are executable by PUBLIC by default in Postgres.
-- Expose only the intended authenticated RPC surface.
REVOKE ALL ON FUNCTION public.marvi_allow_booking_mutation() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.marvi_allow_lifecycle() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capture_booking_check_in_secret() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.guard_booking_privileged_columns() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.guard_profiles_privileged() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.guard_creator_profiles_privileged() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.guard_venue_profiles_privileged() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pause_own_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reactivate_own_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_booking(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_in_booking(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_proof(UUID, TEXT[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_booking_check_in_code(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.venue_confirm_booking(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pause_own_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.reactivate_own_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_booking(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_in_booking(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_proof(UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_booking_check_in_code(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.venue_confirm_booking(UUID) TO authenticated;

-- Views use invoker permissions so the underlying offers / venue RLS policies
-- remain effective for anonymous and authenticated API callers.
ALTER VIEW public.offers_public SET (security_invoker = true);
GRANT SELECT ON public.offers, public.venue_profiles TO anon, authenticated;
GRANT SELECT ON public.offers_public TO anon, authenticated;
