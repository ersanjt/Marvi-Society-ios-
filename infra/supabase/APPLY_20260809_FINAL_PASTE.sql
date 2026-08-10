BEGIN;

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

-- ---------------------------------------------------------------------------
-- Next migration
-- ---------------------------------------------------------------------------

-- Organization → Brand → Establishment (venue_profiles) hierarchy

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS organizations_owner_name_uidx
    ON public.organizations (owner_user_id, lower(name));

CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS brands_org_name_uidx
    ON public.brands (organization_id, lower(name));

ALTER TABLE public.venue_profiles
    ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES public.brands (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS instagram_handle TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS is_physical BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS country TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS city TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS address_line1 TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS address_line2 TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS postal_code TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS contact_is_self BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS logo_url TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS gallery_urls TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS categories TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS details_complete BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS address_complete BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS photos_complete BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS draft_name TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_venue_profiles_brand ON public.venue_profiles (brand_id);

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS organizations_owner ON public.organizations;
CREATE POLICY organizations_owner ON public.organizations
    FOR ALL USING (owner_user_id = auth.uid() OR public.is_admin())
    WITH CHECK (owner_user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS brands_owner ON public.brands;
CREATE POLICY brands_owner ON public.brands
    FOR ALL USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.organizations o
            WHERE o.id = brands.organization_id AND o.owner_user_id = auth.uid()
        )
    )
    WITH CHECK (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.organizations o
            WHERE o.id = brands.organization_id AND o.owner_user_id = auth.uid()
        )
    );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.organizations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.brands TO authenticated;
GRANT ALL ON public.organizations TO service_role;
GRANT ALL ON public.brands TO service_role;

-- Backfill existing venues into org/brand
DO $$
DECLARE
    r RECORD;
    v_org UUID;
    v_brand UUID;
BEGIN
    FOR r IN
        SELECT DISTINCT ON (owner_user_id) id, owner_user_id, venue_name
        FROM public.venue_profiles
        WHERE brand_id IS NULL
        ORDER BY owner_user_id, created_at
    LOOP
        SELECT id INTO v_org
        FROM public.organizations
        WHERE owner_user_id = r.owner_user_id
        ORDER BY created_at
        LIMIT 1;

        IF v_org IS NULL THEN
            INSERT INTO public.organizations (owner_user_id, name)
            VALUES (r.owner_user_id, coalesce(nullif(trim(r.venue_name), ''), 'My Organization'))
            RETURNING id INTO v_org;
        END IF;

        INSERT INTO public.brands (organization_id, name)
        VALUES (v_org, coalesce(nullif(trim(r.venue_name), ''), 'My Brand'))
        RETURNING id INTO v_brand;

        UPDATE public.venue_profiles
        SET brand_id = v_brand,
            draft_name = venue_name,
            city = CASE WHEN city = '' THEN area ELSE city END,
            address_line1 = CASE WHEN address_line1 = '' THEN address ELSE address_line1 END,
            details_complete = true,
            address_complete = (coalesce(lat, 0) <> 0 OR address <> ''),
            photos_complete = false
        WHERE owner_user_id = r.owner_user_id AND brand_id IS NULL;
    END LOOP;
END;
$$;

-- Tighten venue-media uploads to owner folder
DROP POLICY IF EXISTS "venue media upload" ON storage.objects;
DROP POLICY IF EXISTS venue_media_upload ON storage.objects;
DROP POLICY IF EXISTS venue_media_public_read ON storage.objects;
DROP POLICY IF EXISTS venue_media_insert ON storage.objects;
DROP POLICY IF EXISTS venue_media_update ON storage.objects;
DROP POLICY IF EXISTS venue_media_select ON storage.objects;
DROP POLICY IF EXISTS venue_media_delete ON storage.objects;

CREATE POLICY venue_media_insert ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY venue_media_update ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage upsert requires SELECT in addition to INSERT and UPDATE.
CREATE POLICY venue_media_select ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY venue_media_delete ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_organization_with_brand(
    p_organization_name TEXT,
    p_brand_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_org public.organizations;
    v_brand public.brands;
    v_org_name TEXT := trim(p_organization_name);
    v_brand_name TEXT := trim(p_brand_name);
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_org_name = '' OR v_brand_name = '' THEN
        RAISE EXCEPTION 'Organization and brand names are required';
    END IF;

    INSERT INTO public.organizations (owner_user_id, name)
    VALUES (v_uid, v_org_name)
    RETURNING * INTO v_org;

    INSERT INTO public.brands (organization_id, name)
    VALUES (v_org.id, v_brand_name)
    RETURNING * INTO v_brand;

    RETURN jsonb_build_object(
        'organization_id', v_org.id,
        'organization_name', v_org.name,
        'brand_id', v_brand.id,
        'brand_name', v_brand.name
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_establishment_draft(
    p_brand_id UUID,
    p_establishment_name TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_name TEXT := trim(p_establishment_name);
    v_venue_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_name = '' THEN
        RAISE EXCEPTION 'Name can''t be empty.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.brands b
        JOIN public.organizations o ON o.id = b.organization_id
        WHERE b.id = p_brand_id AND o.owner_user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'Brand not found on your account';
    END IF;

    INSERT INTO public.venue_profiles (
        owner_user_id,
        brand_id,
        venue_name,
        draft_name,
        area,
        category,
        status
    ) VALUES (
        v_uid,
        p_brand_id,
        v_name,
        v_name,
        'pending',
        'dining',
        'under_review'
    )
    RETURNING id INTO v_venue_id;

    UPDATE public.profiles
    SET active_venue_id = v_venue_id, updated_at = now()
    WHERE id = v_uid;

    RETURN v_venue_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_establishment_details(
    p_venue_id UUID,
    p_instagram_handle TEXT,
    p_description TEXT,
    p_categories TEXT[],
    p_contact_name TEXT,
    p_contact_phone TEXT,
    p_contact_is_self BOOLEAN DEFAULT false,
    p_offer_category TEXT DEFAULT 'dining'
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_ig TEXT := lower(trim(both '@' FROM coalesce(p_instagram_handle, '')));
    v_desc TEXT := trim(coalesce(p_description, ''));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF v_ig = '' OR length(v_ig) < 2 THEN
        RAISE EXCEPTION 'Invalid Instagram handle';
    END IF;
    IF v_desc = '' OR length(v_desc) > 200 THEN
        RAISE EXCEPTION 'Description is required (max 200 characters)';
    END IF;
    IF p_categories IS NULL OR array_length(p_categories, 1) IS NULL THEN
        RAISE EXCEPTION 'Choose at least one category';
    END IF;
    IF trim(coalesce(p_contact_name, '')) = '' OR trim(coalesce(p_contact_phone, '')) = '' THEN
        RAISE EXCEPTION 'Contact details are required';
    END IF;

    UPDATE public.venue_profiles
    SET
        instagram_handle = v_ig,
        description = v_desc,
        categories = p_categories,
        contact_name = trim(p_contact_name),
        contact_phone = trim(p_contact_phone),
        contact_is_self = coalesce(p_contact_is_self, false),
        category = coalesce(p_offer_category, 'dining')::public.offer_category,
        details_complete = true,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_establishment_address(
    p_venue_id UUID,
    p_is_physical BOOLEAN,
    p_country TEXT,
    p_city TEXT,
    p_location_label TEXT,
    p_address_line1 TEXT,
    p_address_line2 TEXT DEFAULT '',
    p_postal_code TEXT DEFAULT '',
    p_lat DOUBLE PRECISION DEFAULT NULL,
    p_lng DOUBLE PRECISION DEFAULT NULL
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_city TEXT := trim(coalesce(p_city, ''));
    v_country TEXT := trim(coalesce(p_country, ''));
    v_line1 TEXT := trim(coalesce(p_address_line1, ''));
    v_area TEXT := trim(coalesce(p_location_label, v_city));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF coalesce(p_is_physical, true) THEN
        IF v_country = '' OR v_city = '' OR v_line1 = '' THEN
            RAISE EXCEPTION 'Country, city, and address are required for physical venues';
        END IF;
        IF p_lat IS NULL OR p_lng IS NULL THEN
            RAISE EXCEPTION 'Locate the venue on the map';
        END IF;
    ELSE
        IF v_country = '' OR v_city = '' THEN
            RAISE EXCEPTION 'Country and city are required';
        END IF;
    END IF;

    UPDATE public.venue_profiles
    SET
        is_physical = coalesce(p_is_physical, true),
        country = v_country,
        city = v_city,
        area = CASE WHEN v_area = '' THEN v_city ELSE v_area END,
        address_line1 = v_line1,
        address_line2 = trim(coalesce(p_address_line2, '')),
        postal_code = trim(coalesce(p_postal_code, '')),
        address = trim(concat_ws(', ', nullif(v_line1, ''), nullif(trim(coalesce(p_address_line2, '')), ''), nullif(v_city, ''), nullif(v_country, ''))),
        lat = p_lat,
        lng = p_lng,
        address_complete = true,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_establishment_photos(
    p_venue_id UUID,
    p_logo_url TEXT,
    p_gallery_urls TEXT[]
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_gallery TEXT[] := coalesce(p_gallery_urls, '{}');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF trim(coalesce(p_logo_url, '')) = '' THEN
        RAISE EXCEPTION 'Upload your establishment logo';
    END IF;
    IF array_length(v_gallery, 1) IS NULL OR array_length(v_gallery, 1) < 3 THEN
        RAISE EXCEPTION 'Upload at least 3 photos';
    END IF;

    UPDATE public.venue_profiles
    SET
        logo_url = trim(p_logo_url),
        gallery_urls = v_gallery,
        photos_complete = true,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_establishment_for_review(p_venue_id UUID)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    PERFORM set_config('marvi.allow_lifecycle', '1', true);

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF trim(v_row.venue_name) = '' AND trim(v_row.draft_name) = '' THEN
        RAISE EXCEPTION 'Name can''t be empty.';
    END IF;
    IF NOT v_row.details_complete OR NOT v_row.address_complete OR NOT v_row.photos_complete THEN
        RAISE EXCEPTION 'Complete establishment details, address, and photos before submitting';
    END IF;

    UPDATE public.venue_profiles
    SET
        venue_name = coalesce(nullif(trim(draft_name), ''), venue_name),
        status = 'under_review',
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    IF NOT EXISTS (
        SELECT 1 FROM public.admin_tasks
        WHERE type = 'venue_application' AND subject_id = v_row.id AND status = 'open'
    ) THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
        VALUES (
            'venue_application',
            v_row.id,
            v_row.venue_name,
            coalesce(nullif(v_row.city, ''), v_row.area) || ' · establishment submitted for review',
            'High',
            'open'
        );
    END IF;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_my_brands()
RETURNS TABLE (
    organization_id UUID,
    organization_name TEXT,
    brand_id UUID,
    brand_name TEXT
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
    SELECT o.id, o.name, b.id, b.name
    FROM public.organizations o
    JOIN public.brands b ON b.organization_id = o.id
    WHERE o.owner_user_id = auth.uid()
    ORDER BY o.created_at, b.created_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_establishment_draft(p_venue_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.venue_profiles;
BEGIN
    SELECT * INTO v_row
    FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    RETURN to_jsonb(v_row);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_organization_with_brand(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_establishment_draft(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_establishment_details(UUID, TEXT, TEXT, TEXT[], TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_establishment_address(UUID, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_establishment_photos(UUID, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_establishment_for_review(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_my_brands() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_establishment_draft(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.create_organization_with_brand(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_establishment_draft(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_establishment_details(UUID, TEXT, TEXT, TEXT[], TEXT, TEXT, BOOLEAN, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_establishment_address(UUID, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_establishment_photos(UUID, TEXT, TEXT[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_establishment_for_review(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fetch_my_brands() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fetch_establishment_draft(UUID) FROM PUBLIC;

-- Keep legacy register_venue_location working: auto-create brand if needed
CREATE OR REPLACE FUNCTION public.register_venue_location(
    p_venue_name TEXT,
    p_area TEXT,
    p_category TEXT,
    p_address TEXT DEFAULT '',
    p_contact_name TEXT DEFAULT '',
    p_contact_phone TEXT DEFAULT '',
    p_lat DOUBLE PRECISION DEFAULT NULL,
    p_lng DOUBLE PRECISION DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_venue_id UUID;
    v_name TEXT := trim(p_venue_name);
    v_area TEXT := trim(p_area);
    v_brand UUID;
    v_org UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_name = '' OR v_area = '' THEN
        RAISE EXCEPTION 'Venue name and area are required';
    END IF;

    SELECT b.id INTO v_brand
    FROM public.brands b
    JOIN public.organizations o ON o.id = b.organization_id
    WHERE o.owner_user_id = v_uid
    ORDER BY b.created_at
    LIMIT 1;

    IF v_brand IS NULL THEN
        INSERT INTO public.organizations (owner_user_id, name)
        VALUES (v_uid, v_name)
        RETURNING id INTO v_org;

        INSERT INTO public.brands (organization_id, name)
        VALUES (v_org, v_name)
        RETURNING id INTO v_brand;
    END IF;

    INSERT INTO public.venue_profiles (
        owner_user_id,
        brand_id,
        venue_name,
        draft_name,
        area,
        city,
        category,
        address,
        address_line1,
        contact_name,
        contact_phone,
        lat,
        lng,
        status,
        details_complete,
        address_complete
    ) VALUES (
        v_uid,
        v_brand,
        v_name,
        v_name,
        v_area,
        v_area,
        p_category::public.offer_category,
        COALESCE(p_address, ''),
        COALESCE(p_address, ''),
        COALESCE(p_contact_name, ''),
        COALESCE(p_contact_phone, ''),
        p_lat,
        p_lng,
        'under_review'::public.membership_status,
        true,
        (p_lat IS NOT NULL OR coalesce(p_address, '') <> '')
    )
    RETURNING id INTO v_venue_id;

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
    VALUES (
        'venue_application',
        v_venue_id,
        v_name,
        v_area || ' · new location on existing account',
        'High',
        'open'
    );

    UPDATE public.profiles
    SET active_venue_id = v_venue_id, updated_at = now()
    WHERE id = v_uid;

    RETURN v_venue_id;
END;
$$;

REVOKE ALL ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

INSERT INTO supabase_migrations.schema_migrations (version, name, statements)
VALUES
    ('20260809000001', 'booking_integrity', ARRAY[]::TEXT[]),
    ('20260809000002', 'org_brand_establishment', ARRAY[]::TEXT[])
ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;

COMMIT;
-- Close legacy function-execution defaults and remove current advisor warnings.
-- Every SECURITY DEFINER function is private by default; authenticated RPCs are
-- explicitly restored below, while service_role keeps operational access.

BEGIN;

DO $$
DECLARE
    fn RECORD;
BEGIN
    FOR fn IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS identity_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef
    LOOP
        EXECUTE format(
            'REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC, anon, authenticated',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO service_role',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
    END LOOP;
END;
$$;

-- Restore the signed-in client RPC surface. Trigger functions and privileged
-- queue/cron helpers remain service-role only.
DO $$
DECLARE
    fn RECORD;
    internal_names CONSTANT TEXT[] := ARRAY[
        'dispatch_email_outbox',
        'dispatch_push_outbox',
        'ensure_conversation_for_booking',
        'guard_booking_proof_approval',
        'guard_offer_publish',
        'handle_new_user',
        'log_activity_event',
        'queue_push_notification',
        'queue_transactional_email',
        'resolve_active_venue_id',
        'seed_istanbul_demo'
    ];
BEGIN
    FOR fn IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS identity_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef
          AND p.prorettype <> 'trigger'::regtype
          AND NOT (p.proname = ANY(internal_names))
    LOOP
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
    END LOOP;
END;
$$;

-- Anonymous callers only need the non-mutating referral check and the policy
-- helper used by public RLS reads.
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon;

-- Pin search_path on project-owned functions to prevent object-shadowing.
DO $$
DECLARE
    fn RECORD;
BEGIN
    FOR fn IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS identity_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND pg_get_userbyid(p.proowner) = current_user
    LOOP
        EXECUTE format(
            'ALTER FUNCTION %I.%I(%s) SET search_path = public, extensions, pg_temp',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
    END LOOP;
END;
$$;

-- Public buckets do not need broad SELECT policies for object downloads.
-- Keep SELECT only for owner-scoped upsert/list operations.
DROP POLICY IF EXISTS profile_media_public_read ON storage.objects;
DROP POLICY IF EXISTS profile_media_select_own ON storage.objects;
CREATE POLICY profile_media_select_own ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'profile-media'
        AND (storage.foldername(name))[1] = (select auth.uid())::TEXT
    );

-- Account-deletion rows are written only by the server-side service role.
DROP POLICY IF EXISTS deletion_insert ON public.deletion_requests;

-- Demo submissions remain public, but validate shape and size at the database
-- boundary instead of accepting arbitrary rows.
DROP POLICY IF EXISTS demo_requests_insert_public ON public.demo_requests;
CREATE POLICY demo_requests_insert_public ON public.demo_requests
    FOR INSERT TO anon, authenticated
    WITH CHECK (
        length(trim(first_name)) BETWEEN 1 AND 120
        AND length(trim(last_name)) BETWEEN 1 AND 120
        AND length(trim(company)) BETWEEN 1 AND 180
        AND length(trim(email)) BETWEEN 3 AND 320
        AND position('@' IN email) > 1
        AND length(coalesce(website, '')) <= 500
        AND length(coalesce(message, '')) <= 5000
        AND source = 'web'
        AND status = 'new'
    );

INSERT INTO supabase_migrations.schema_migrations (version, name, statements)
VALUES (
    '20260809164025',
    'harden_function_execution_and_search_path',
    ARRAY[]::TEXT[]
)
ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;

COMMIT;
