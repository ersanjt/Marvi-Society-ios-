-- Marvi Society — combined migrations
-- Generated: 2026-06-11T20:31:33Z
-- Source: infra/supabase/migrations/*.sql (lexicographic order)
-- Do not edit by hand; run: npm run db:combine

-- ═══════════════════════════════════════════════════════════════════════════
-- 20260609000001_initial_schema.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Marvi Society — initial schema (Phase 1)
-- Requires: Supabase project with auth enabled

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE public.user_role AS ENUM ('creator', 'venue', 'admin');
CREATE TYPE public.membership_status AS ENUM ('under_review', 'approved', 'paused');
CREATE TYPE public.offer_category AS ENUM ('dining', 'nightlife', 'wellness', 'beauty', 'fitness', 'retail');
CREATE TYPE public.collaboration_model AS ENUM ('invitation', 'event', 'gift', 'instant');
CREATE TYPE public.offer_status AS ENUM ('draft', 'review', 'live', 'completed');
CREATE TYPE public.booking_stage AS ENUM ('invited', 'confirmed', 'checked_in', 'proof_due', 'completed', 'cancelled');
CREATE TYPE public.proof_status AS ENUM ('not_started', 'pending', 'approved', 'flagged');
CREATE TYPE public.admin_task_type AS ENUM ('creator_application', 'venue_application', 'campaign_review', 'proof_review');
CREATE TYPE public.admin_task_status AS ENUM ('open', 'approved', 'rejected');

-- ---------------------------------------------------------------------------
-- Profiles (extends auth.users)
-- ---------------------------------------------------------------------------

CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    role public.user_role NOT NULL DEFAULT 'creator',
    email TEXT,
    phone TEXT,
    apple_user_id TEXT,
    status public.membership_status NOT NULL DEFAULT 'under_review',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.creator_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles (id) ON DELETE CASCADE,
    full_name TEXT NOT NULL DEFAULT '',
    instagram_handle TEXT NOT NULL DEFAULT '',
    tiktok_handle TEXT,
    city TEXT NOT NULL DEFAULT 'istanbul',
    audience_count INTEGER NOT NULL DEFAULT 0,
    niches TEXT[] NOT NULL DEFAULT '{}',
    languages TEXT[] NOT NULL DEFAULT '{English}',
    status public.membership_status NOT NULL DEFAULT 'under_review',
    score NUMERIC(5, 2) NOT NULL DEFAULT 0,
    proof_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
    bio TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.venue_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    venue_name TEXT NOT NULL,
    area TEXT NOT NULL,
    category public.offer_category NOT NULL,
    address TEXT NOT NULL DEFAULT '',
    contact_name TEXT NOT NULL DEFAULT '',
    contact_phone TEXT NOT NULL DEFAULT '',
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    status public.membership_status NOT NULL DEFAULT 'under_review',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Marketplace
-- ---------------------------------------------------------------------------

CREATE TABLE public.offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category public.offer_category NOT NULL,
    model public.collaboration_model NOT NULL DEFAULT 'invitation',
    date_start TIMESTAMPTZ,
    date_end TIMESTAMPTZ,
    date_label TEXT NOT NULL DEFAULT '',
    time_label TEXT NOT NULL DEFAULT '',
    value_label TEXT NOT NULL DEFAULT '',
    capacity INTEGER NOT NULL DEFAULT 1,
    remaining_slots INTEGER NOT NULL DEFAULT 1,
    image_name TEXT NOT NULL DEFAULT 'venue-placeholder',
    description TEXT NOT NULL DEFAULT '',
    deliverables TEXT[] NOT NULL DEFAULT '{}',
    requirements TEXT[] NOT NULL DEFAULT '{}',
    host_note TEXT NOT NULL DEFAULT '',
    checklist TEXT[] NOT NULL DEFAULT ARRAY[
        'Confirm guest details',
        'Check in with venue host',
        'Upload story, post, or review links'
    ],
    status public.offer_status NOT NULL DEFAULT 'draft',
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT offers_remaining_lte_capacity CHECK (remaining_slots <= capacity)
);

CREATE TABLE public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID NOT NULL REFERENCES public.offers (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    stage public.booking_stage NOT NULL DEFAULT 'confirmed',
    check_in_code TEXT NOT NULL,
    guest_name TEXT NOT NULL DEFAULT '',
    proof_deadline TIMESTAMPTZ,
    proof_deadline_label TEXT NOT NULL DEFAULT '',
    proof_status public.proof_status NOT NULL DEFAULT 'not_started',
    proof_links TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (offer_id, creator_id)
);

CREATE TABLE public.proof_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    links TEXT[] NOT NULL DEFAULT '{}',
    screenshot_paths TEXT[] NOT NULL DEFAULT '{}',
    status public.proof_status NOT NULL DEFAULT 'pending',
    admin_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);

CREATE TABLE public.saved_offers (
    user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    offer_id UUID NOT NULL REFERENCES public.offers (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, offer_id)
);

CREATE TABLE public.admin_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type public.admin_task_type NOT NULL,
    subject_id UUID NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL DEFAULT '',
    priority TEXT NOT NULL DEFAULT 'Medium',
    status public.admin_task_status NOT NULL DEFAULT 'open',
    assigned_admin_id UUID REFERENCES public.profiles (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

CREATE TABLE public.strikes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    booking_id UUID REFERENCES public.bookings (id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'medium',
    created_by UUID REFERENCES public.profiles (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'general',
    icon TEXT NOT NULL DEFAULT 'bell.fill',
    tint TEXT NOT NULL DEFAULT 'emerald',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Views (join venue name for mobile clients)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.offers_public AS
SELECT
    o.*,
    v.venue_name,
    v.area
FROM public.offers o
JOIN public.venue_profiles v ON v.id = o.venue_id
WHERE o.status = 'live'
  AND v.status = 'approved';

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER creator_profiles_updated_at
    BEFORE UPDATE ON public.creator_profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER venue_profiles_updated_at
    BEFORE UPDATE ON public.venue_profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER offers_updated_at
    BEFORE UPDATE ON public.offers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER bookings_updated_at
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Auto-create profile row on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, role, status)
    VALUES (
        NEW.id,
        NEW.email,
        'creator',
        'under_review'
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        COALESCE(NEW.raw_user_meta_data ->> 'instagram_handle', ''),
        COALESCE(NEW.raw_user_meta_data ->> 'city', 'istanbul')
    );

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
    VALUES (
        'creator_application',
        NEW.id,
        'New creator application',
        COALESCE(NEW.raw_user_meta_data ->> 'instagram_handle', NEW.email, 'Unknown'),
        'High'
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX idx_offers_status_city ON public.offers (status);
CREATE INDEX idx_offers_venue ON public.offers (venue_id);
CREATE INDEX idx_bookings_creator ON public.bookings (creator_id);
CREATE INDEX idx_bookings_offer ON public.bookings (offer_id);
CREATE INDEX idx_notifications_user ON public.notifications (user_id, created_at DESC);
CREATE INDEX idx_admin_tasks_status ON public.admin_tasks (status, created_at DESC);


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260609000002_rls_policies.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Row Level Security policies

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proof_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Helper: current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$;

CREATE OR REPLACE FUNCTION public.current_creator_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT id FROM public.creator_profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- profiles
CREATE POLICY profiles_select_own ON public.profiles
    FOR SELECT USING (id = auth.uid() OR public.is_admin());

CREATE POLICY profiles_update_own ON public.profiles
    FOR UPDATE USING (id = auth.uid() OR public.is_admin());

-- creator_profiles
CREATE POLICY creator_profiles_select ON public.creator_profiles
    FOR SELECT USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY creator_profiles_update_own ON public.creator_profiles
    FOR UPDATE USING (user_id = auth.uid() OR public.is_admin());

-- venue_profiles
CREATE POLICY venue_profiles_select ON public.venue_profiles
    FOR SELECT USING (
        owner_user_id = auth.uid()
        OR public.is_admin()
        OR status = 'approved'
    );

CREATE POLICY venue_profiles_manage_own ON public.venue_profiles
    FOR ALL USING (owner_user_id = auth.uid() OR public.is_admin());

-- offers: creators see live; venues see own; admins see all
CREATE POLICY offers_select_live ON public.offers
    FOR SELECT USING (
        status = 'live'
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = offers.venue_id AND v.owner_user_id = auth.uid()
        )
    );

CREATE POLICY offers_manage_venue ON public.offers
    FOR ALL USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = offers.venue_id AND v.owner_user_id = auth.uid()
        )
    );

-- bookings
CREATE POLICY bookings_select ON public.bookings
    FOR SELECT USING (
        creator_id = public.current_creator_id()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.offers o
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE o.id = bookings.offer_id AND v.owner_user_id = auth.uid()
        )
    );

CREATE POLICY bookings_insert_creator ON public.bookings
    FOR INSERT WITH CHECK (creator_id = public.current_creator_id());

CREATE POLICY bookings_update_own ON public.bookings
    FOR UPDATE USING (
        creator_id = public.current_creator_id()
        OR public.is_admin()
    );

-- proof_submissions
CREATE POLICY proof_select ON public.proof_submissions
    FOR SELECT USING (
        creator_id = public.current_creator_id()
        OR public.is_admin()
    );

CREATE POLICY proof_insert ON public.proof_submissions
    FOR INSERT WITH CHECK (creator_id = public.current_creator_id());

-- saved_offers
CREATE POLICY saved_offers_own ON public.saved_offers
    FOR ALL USING (user_id = auth.uid());

-- admin_tasks
CREATE POLICY admin_tasks_admin ON public.admin_tasks
    FOR ALL USING (public.is_admin());

CREATE POLICY admin_tasks_creator_read ON public.admin_tasks
    FOR SELECT USING (
        type = 'creator_application' AND subject_id = auth.uid()
    );

-- strikes
CREATE POLICY strikes_admin ON public.strikes
    FOR ALL USING (public.is_admin());

CREATE POLICY strikes_creator_read ON public.strikes
    FOR SELECT USING (creator_id = public.current_creator_id());

-- notifications
CREATE POLICY notifications_own ON public.notifications
    FOR ALL USING (user_id = auth.uid() OR public.is_admin());


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260609000003_rpc_functions.sql
-- ═══════════════════════════════════════════════════════════════════════════
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260609000004_demo_leads_storage.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Demo requests, referrals, storage buckets

CREATE TABLE public.demo_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    company TEXT NOT NULL,
    email TEXT NOT NULL,
    website TEXT,
    message TEXT,
    source TEXT DEFAULT 'web',
    status TEXT DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.demo_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY demo_requests_insert_public ON public.demo_requests
    FOR INSERT WITH CHECK (true);

CREATE POLICY demo_requests_admin_read ON public.demo_requests
    FOR SELECT USING (public.is_admin());

CREATE TABLE public.referral_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    owner_user_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
    owner_type TEXT NOT NULL DEFAULT 'creator',
    uses_count INTEGER NOT NULL DEFAULT 0,
    max_uses INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY referral_read ON public.referral_codes
    FOR SELECT USING (true);

CREATE POLICY referral_admin ON public.referral_codes
    FOR ALL USING (public.is_admin());

-- Storage buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
    ('proof-uploads', 'proof-uploads', false, 10485760),
    ('venue-media', 'venue-media', true, 5242880)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY proof_upload_own ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY proof_read_own ON storage.objects
    FOR SELECT USING (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY venue_media_public_read ON storage.objects
    FOR SELECT USING (bucket_id = 'venue-media');

CREATE POLICY venue_media_upload ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'venue-media'
        AND auth.role() = 'authenticated'
    );

-- Account deletion request log
CREATE TABLE public.deletion_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    otp_hash TEXT,
    expires_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.deletion_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY deletion_insert ON public.deletion_requests
    FOR INSERT WITH CHECK (true);


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260609000005_seed_function.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Runnable Istanbul seed (call after creating venue owner in Auth)

CREATE OR REPLACE FUNCTION public.seed_istanbul_demo(p_owner_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_karakoy UUID;
    v_luma UUID;
    v_kadikoy UUID;
BEGIN
    INSERT INTO public.venue_profiles (owner_user_id, venue_name, area, category, address, status, lat, lng)
    VALUES (p_owner_id, 'Karaköy House', 'Karaköy', 'nightlife', 'Karaköy, Istanbul', 'approved', 41.0256, 28.9744)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.venue_profiles (owner_user_id, venue_name, area, category, address, status, lat, lng)
    VALUES (p_owner_id, 'Nişantaşı Glow Clinic', 'Nişantaşı', 'beauty', 'Nişantaşı, Istanbul', 'approved', 41.0520, 28.9940)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.venue_profiles (owner_user_id, venue_name, area, category, address, status, lat, lng)
    VALUES (p_owner_id, 'Kadıköy Brew Lab', 'Kadıköy', 'dining', 'Kadıköy, Istanbul', 'approved', 40.9903, 29.0244)
    ON CONFLICT DO NOTHING;

    SELECT id INTO v_karakoy FROM public.venue_profiles WHERE venue_name = 'Karaköy House' AND owner_user_id = p_owner_id LIMIT 1;
    SELECT id INTO v_luma FROM public.venue_profiles WHERE venue_name = 'Nişantaşı Glow Clinic' AND owner_user_id = p_owner_id LIMIT 1;
    SELECT id INTO v_kadikoy FROM public.venue_profiles WHERE venue_name = 'Kadıköy Brew Lab' AND owner_user_id = p_owner_id LIMIT 1;

    INSERT INTO public.offers (venue_id, title, category, model, date_label, time_label, value_label, capacity, remaining_slots, description, deliverables, requirements, host_note, status, lat, lng)
    VALUES
        (v_karakoy, 'Sunset Rooftop Preview', 'nightlife', 'event', 'Saturday, Jun 15', '21:00', 'VIP table + drinks', 8, 5,
         'Preview night for summer cocktail program.',
         ARRAY['1 TikTok', '1 Instagram Story set'], ARRAY['Nightlife niche', '21+ only'], 'Check in at host stand.', 'live', 41.0256, 28.9744),
        (v_luma, 'Skin Reset Session', 'beauty', 'gift', 'Flexible', 'Weekdays', '₺1,800 facial', 6, 4,
         'Complimentary facial for before/after content.',
         ARRAY['1 Reel', '1 post'], ARRAY['Beauty niche'], 'Arrive 10 min early.', 'live', 41.0520, 28.9940),
        (v_kadikoy, 'Morning Flat White', 'dining', 'instant', 'Today', 'Anytime', 'Coffee + pastry', 20, 18,
         'Walk-in grab-and-go. Open map, accept, visit within 2 hours.',
         ARRAY['1 Story with location tag'], ARRAY['Within 1 km'], 'Show check-in code at counter.', 'live', 40.9903, 29.0244);

    INSERT INTO public.referral_codes (code, owner_type, max_uses)
    VALUES ('MARVI-IST', 'creator', 500), ('MARVI2026', 'venue', 100)
    ON CONFLICT (code) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.seed_istanbul_demo(UUID) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260610000001_production_hardening.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Production hardening: public offers view grants + self-healing creator profile

-- Mobile clients read live offers through this view.
GRANT SELECT ON public.offers_public TO anon, authenticated;

-- Heal missing creator_profiles row (e.g. users created before trigger).
CREATE OR REPLACE FUNCTION public.ensure_creator_profile()
RETURNS public.creator_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user auth.users%ROWTYPE;
    v_profile public.creator_profiles;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_profile
    FROM public.creator_profiles
    WHERE user_id = auth.uid();

    IF FOUND THEN
        RETURN v_profile;
    END IF;

    SELECT * INTO v_user FROM auth.users WHERE id = auth.uid();

    INSERT INTO public.creator_profiles (
        user_id,
        full_name,
        instagram_handle,
        city,
        status
    ) VALUES (
        auth.uid(),
        COALESCE(v_user.raw_user_meta_data ->> 'full_name', ''),
        COALESCE(v_user.raw_user_meta_data ->> 'instagram_handle', ''),
        COALESCE(v_user.raw_user_meta_data ->> 'city', 'istanbul'),
        'under_review'
    )
    ON CONFLICT (user_id) DO UPDATE SET updated_at = now()
    RETURNING * INTO v_profile;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_creator_profile() TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260610000002_delete_own_account.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Account deletion RPC (Apple App Store requirement)
-- Called by authenticated user after email OTP verification on web.

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_creator_id := public.current_creator_id();

    DELETE FROM public.saved_offers WHERE user_id = v_user_id;
    DELETE FROM public.notifications WHERE user_id = v_user_id;

    IF v_creator_id IS NOT NULL THEN
        DELETE FROM public.proof_submissions WHERE creator_id = v_creator_id;
        DELETE FROM public.bookings WHERE creator_id = v_creator_id;
        DELETE FROM public.strikes WHERE creator_id = v_creator_id;
    END IF;

    DELETE FROM public.creator_profiles WHERE user_id = v_user_id;
    DELETE FROM public.venue_profiles WHERE owner_user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;

    UPDATE public.deletion_requests
    SET completed_at = now()
    WHERE email = (SELECT email FROM auth.users WHERE id = v_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260611000001_secret_society_parity.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Marvi Society — Secret Society parity: admin resolve, venue swipe, reviews, offer imagery

-- ---------------------------------------------------------------------------
-- Creator shortlist (venue swipe right)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.creator_shortlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    offer_id UUID REFERENCES public.offers (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (venue_id, creator_id, offer_id)
);

ALTER TABLE public.creator_shortlists ENABLE ROW LEVEL SECURITY;

CREATE POLICY creator_shortlists_venue ON public.creator_shortlists
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = venue_id AND (v.owner_user_id = auth.uid() OR public.is_admin())
        )
    );

-- ---------------------------------------------------------------------------
-- Admin: one-click approve / reject with downstream status updates
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.resolve_admin_task(p_task_id UUID, p_action TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task public.admin_tasks%ROWTYPE;
    v_approve BOOLEAN := lower(trim(p_action)) IN ('approve', 'approved');
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    SELECT * INTO v_task FROM public.admin_tasks WHERE id = p_task_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    IF v_task.status <> 'open' THEN
        RETURN;
    END IF;

    UPDATE public.admin_tasks
    SET
        status = CASE WHEN v_approve THEN 'approved'::public.admin_task_status ELSE 'rejected'::public.admin_task_status END,
        resolved_at = now(),
        assigned_admin_id = auth.uid()
    WHERE id = p_task_id;

    CASE v_task.type
        WHEN 'creator_application' THEN
            UPDATE public.profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

            UPDATE public.creator_profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE user_id = v_task.subject_id;

            IF v_approve THEN
                INSERT INTO public.notifications (user_id, title, body, type, icon, tint)
                VALUES (
                    v_task.subject_id,
                    'Membership approved',
                    'Your Marvi Society creator application was approved. Explore live events now.',
                    'membership',
                    'checkmark.seal.fill',
                    'emerald'
                );
            END IF;

        WHEN 'venue_application' THEN
            UPDATE public.venue_profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

        WHEN 'campaign_review' THEN
            UPDATE public.offers
            SET status = CASE WHEN v_approve THEN 'live'::public.offer_status ELSE 'draft'::public.offer_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

        WHEN 'proof_review' THEN
            UPDATE public.proof_submissions
            SET
                status = CASE WHEN v_approve THEN 'approved'::public.proof_status ELSE 'flagged'::public.proof_status END,
                reviewed_at = now()
            WHERE booking_id = v_task.subject_id
              AND status = 'pending';

            UPDATE public.bookings
            SET proof_status = CASE WHEN v_approve THEN 'approved'::public.proof_status ELSE 'flagged'::public.proof_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;
    END CASE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_admin_task(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- Venue swipe candidates
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fetch_swipe_candidates(p_offer_id UUID DEFAULT NULL)
RETURNS TABLE (
    creator_id UUID,
    full_name TEXT,
    instagram_handle TEXT,
    city TEXT,
    audience_count INTEGER,
    score NUMERIC,
    proof_rate NUMERIC,
    niches TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT v.id INTO v_venue_id
    FROM public.venue_profiles v
    WHERE v.owner_user_id = auth.uid() AND v.status = 'approved'
    ORDER BY v.created_at
    LIMIT 1;

    IF v_venue_id IS NULL AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'No approved venue profile';
    END IF;

    RETURN QUERY
    SELECT
        cp.id,
        cp.full_name,
        cp.instagram_handle,
        cp.city,
        cp.audience_count,
        cp.score,
        cp.proof_rate,
        cp.niches
    FROM public.creator_profiles cp
    WHERE cp.status = 'approved'
      AND NOT EXISTS (
          SELECT 1 FROM public.creator_shortlists s
          WHERE s.creator_id = cp.id
            AND s.venue_id = v_venue_id
            AND (p_offer_id IS NULL OR s.offer_id = p_offer_id)
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.bookings b
          JOIN public.offers o ON o.id = b.offer_id
          WHERE b.creator_id = cp.id
            AND o.venue_id = v_venue_id
            AND b.stage <> 'cancelled'
            AND (p_offer_id IS NULL OR o.id = p_offer_id)
      )
    ORDER BY cp.score DESC, cp.audience_count DESC
    LIMIT 25;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_swipe_candidates(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.shortlist_creator(p_creator_id UUID, p_offer_id UUID DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue_id UUID;
    v_creator_user UUID;
BEGIN
    SELECT v.id INTO v_venue_id
    FROM public.venue_profiles v
    WHERE v.owner_user_id = auth.uid() AND v.status = 'approved'
    LIMIT 1;

    IF v_venue_id IS NULL THEN
        RAISE EXCEPTION 'No venue profile';
    END IF;

    INSERT INTO public.creator_shortlists (venue_id, creator_id, offer_id)
    VALUES (v_venue_id, p_creator_id, p_offer_id)
    ON CONFLICT DO NOTHING;

    SELECT user_id INTO v_creator_user FROM public.creator_profiles WHERE id = p_creator_id;

    IF v_creator_user IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint)
        VALUES (
            v_creator_user,
            'Venue shortlisted you',
            'A Marvi venue partner added you to their creator shortlist.',
            'shortlist',
            'star.fill',
            'gold'
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.shortlist_creator(UUID, UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Venue post-visit review queue
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fetch_venue_review_queue()
RETURNS TABLE (
    booking_id UUID,
    creator_name TEXT,
    instagram_handle TEXT,
    offer_title TEXT,
    stage public.booking_stage,
    proof_status public.proof_status,
    checked_in_label TEXT
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
        to_char(b.updated_at, 'Mon DD · HH24:MI')
    FROM public.bookings b
    JOIN public.creator_profiles cp ON cp.id = b.creator_id
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE v.owner_user_id = auth.uid()
      AND b.stage IN ('checked_in', 'proof_due', 'completed')
      AND b.proof_status IN ('not_started', 'pending')
    ORDER BY b.updated_at DESC
    LIMIT 30;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_venue_review_queue() TO authenticated;

-- ---------------------------------------------------------------------------
-- Stock imagery for live offers (Unsplash — replace with venue-media later)
-- ---------------------------------------------------------------------------

UPDATE public.offers SET image_name = 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=900&q=80'
WHERE title ILIKE '%rooftop%' OR title ILIKE '%night%';

UPDATE public.offers SET image_name = 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=900&q=80'
WHERE category = 'beauty';

UPDATE public.offers SET image_name = 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=900&q=80'
WHERE category = 'dining';

UPDATE public.offers SET image_name = 'https://images.unsplash.com/photo-1540497077202-7a8ee7868e29?w=900&q=80'
WHERE category = 'fitness';

UPDATE public.offers SET image_name = 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&q=80'
WHERE category = 'nightlife' AND image_name NOT LIKE 'http%';

UPDATE public.offers SET image_name = 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=900&q=80'
WHERE category = 'wellness';

UPDATE public.offers SET image_name = 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=900&q=80'
WHERE category = 'retail';


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260612000001_account_context_rpc.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Reliable account role + workspace context for iOS Profile (uses auth.uid(), not client-side JWT parsing).

CREATE OR REPLACE FUNCTION public.fetch_account_context()
RETURNS TABLE (
    role public.user_role,
    status public.membership_status,
    has_venue_profile BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
        INSERT INTO public.profiles (id, email, role, status)
        SELECT u.id, u.email, 'creator'::public.user_role, 'under_review'::public.membership_status
        FROM auth.users u
        WHERE u.id = v_uid;
    END IF;

    RETURN QUERY
    SELECT
        p.role,
        p.status,
        EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.owner_user_id = v_uid
        )
    FROM public.profiles p
    WHERE p.id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_account_context() TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260613000001_venue_reviews_strikes.sql
-- ═══════════════════════════════════════════════════════════════════════════
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


