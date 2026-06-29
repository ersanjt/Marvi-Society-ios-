-- Security hardening: block self-service privilege escalation + lock down internal RPCs.
-- Addresses audit findings: profiles/creator/venue/offers/bookings RLS escalation,
-- and over-granted queue_*/seed_istanbul_demo helpers.
--
-- Strategy: keep the existing broad UPDATE policies (so users can edit safe fields),
-- but add BEFORE-UPDATE triggers that reject changes to privileged columns unless the
-- caller is an admin (is_admin()) or the service role. Legitimate privileged changes
-- already flow through admin-only SECURITY DEFINER RPCs performed by admins.

-- ---------------------------------------------------------------------------
-- 1. profiles: only admin/service may change role or status
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_profiles_privileged()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.role() = 'service_role' OR public.is_admin() THEN
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

DROP TRIGGER IF EXISTS guard_profiles_privileged ON public.profiles;
CREATE TRIGGER guard_profiles_privileged
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.guard_profiles_privileged();

-- ---------------------------------------------------------------------------
-- 2. creator_profiles: only admin/service may change status
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_creator_profiles_privileged()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.role() = 'service_role' OR public.is_admin() THEN
        RETURN NEW;
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Not authorized to change creator status';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_creator_profiles_privileged ON public.creator_profiles;
CREATE TRIGGER guard_creator_profiles_privileged
    BEFORE UPDATE ON public.creator_profiles
    FOR EACH ROW EXECUTE FUNCTION public.guard_creator_profiles_privileged();

-- ---------------------------------------------------------------------------
-- 3. venue_profiles: only admin/service may change status
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_venue_profiles_privileged()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.role() = 'service_role' OR public.is_admin() THEN
        RETURN NEW;
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Not authorized to change venue status';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_venue_profiles_privileged ON public.venue_profiles;
CREATE TRIGGER guard_venue_profiles_privileged
    BEFORE UPDATE ON public.venue_profiles
    FOR EACH ROW EXECUTE FUNCTION public.guard_venue_profiles_privileged();

-- ---------------------------------------------------------------------------
-- 4. offers: venues may draft/submit, but only admin/service may publish (live)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_offer_publish()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.role() = 'service_role' OR public.is_admin() THEN
        RETURN NEW;
    END IF;
    -- Non-admins cannot create or move an offer into a publicly visible state.
    IF NEW.status = 'live' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'live') THEN
        RAISE EXCEPTION 'Offers must be approved by an operator before going live';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_offer_publish ON public.offers;
CREATE TRIGGER guard_offer_publish
    BEFORE INSERT OR UPDATE ON public.offers
    FOR EACH ROW EXECUTE FUNCTION public.guard_offer_publish();

-- ---------------------------------------------------------------------------
-- 5. bookings: only admin/service may approve proof
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_booking_proof_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.role() = 'service_role' OR public.is_admin() THEN
        RETURN NEW;
    END IF;
    IF NEW.proof_status IS DISTINCT FROM OLD.proof_status AND NEW.proof_status = 'approved' THEN
        RAISE EXCEPTION 'Only operators can approve proof';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_booking_proof_approval ON public.bookings;
CREATE TRIGGER guard_booking_proof_approval
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.guard_booking_proof_approval();

-- ---------------------------------------------------------------------------
-- 6. Lock down internal helper RPCs: server/service role only
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.queue_transactional_email(UUID, TEXT, TEXT, TEXT, JSONB) FROM authenticated, anon;
REVOKE EXECUTE ON FUNCTION public.queue_push_notification(UUID, TEXT, TEXT, JSONB) FROM authenticated, anon;
REVOKE EXECUTE ON FUNCTION public.seed_istanbul_demo(UUID) FROM authenticated, anon;

GRANT EXECUTE ON FUNCTION public.queue_transactional_email(UUID, TEXT, TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.queue_push_notification(UUID, TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.seed_istanbul_demo(UUID) TO service_role;
