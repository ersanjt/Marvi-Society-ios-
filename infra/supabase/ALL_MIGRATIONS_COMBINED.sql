-- Marvi Society — combined migrations
-- Generated: 2026-07-19T12:33:15Z
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
    VALUES ('MARVI-IST', 'creator', 500), ('TURGUT', 'creator', 500), ('MARVI2026', 'venue', 100)
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260614000001_production_integrity.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Production integrity: membership guard, referral redemption, campaign RPC, swipe pass

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS referral_code TEXT;

CREATE TABLE IF NOT EXISTS public.creator_passes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    offer_id UUID REFERENCES public.offers (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (venue_id, creator_id, offer_id)
);

ALTER TABLE public.creator_passes ENABLE ROW LEVEL SECURITY;

CREATE POLICY creator_passes_venue ON public.creator_passes
    FOR ALL USING (
        venue_id IN (
            SELECT id FROM public.venue_profiles WHERE owner_user_id = auth.uid()
        )
    );

-- Block unapproved creators from accepting offers
CREATE OR REPLACE FUNCTION public.accept_offer(p_offer_id UUID)
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

-- Redeem invite code for current user (idempotent)
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_code := upper(trim(p_code));
    IF v_code = '' THEN
        RAISE EXCEPTION 'Invite code required';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND referral_code IS NOT NULL
    ) THEN
        RETURN;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid invite code';
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RAISE EXCEPTION 'Invite code has reached its limit';
    END IF;

    UPDATE public.referral_codes
    SET uses_count = uses_count + 1
    WHERE id = v_row.id;

    UPDATE public.profiles
    SET referral_code = v_code
    WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT) TO authenticated;

-- Venue swipe left: pass on creator
CREATE OR REPLACE FUNCTION public.pass_creator(p_creator_id UUID, p_offer_id UUID DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue_id UUID;
BEGIN
    SELECT v.id INTO v_venue_id
    FROM public.venue_profiles v
    WHERE v.owner_user_id = auth.uid() AND v.status = 'approved'
    LIMIT 1;

    IF v_venue_id IS NULL THEN
        RAISE EXCEPTION 'No venue profile';
    END IF;

    INSERT INTO public.creator_passes (venue_id, creator_id, offer_id)
    VALUES (v_venue_id, p_creator_id, p_offer_id)
    ON CONFLICT DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pass_creator(UUID, UUID) TO authenticated;

-- Venue campaign submit (offer + admin task atomically)
CREATE OR REPLACE FUNCTION public.submit_campaign_for_review(
    p_title TEXT,
    p_category TEXT,
    p_model TEXT,
    p_date_label TEXT,
    p_value_label TEXT,
    p_slots INTEGER,
    p_deliverables TEXT[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue public.venue_profiles%ROWTYPE;
    v_offer_id UUID;
BEGIN
    SELECT * INTO v_venue
    FROM public.venue_profiles
    WHERE owner_user_id = auth.uid() AND status = 'approved'
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No approved venue profile';
    END IF;

    INSERT INTO public.offers (
        venue_id,
        title,
        category,
        model,
        date_label,
        time_label,
        value_label,
        capacity,
        remaining_slots,
        description,
        deliverables,
        requirements,
        host_note,
        status,
        lat,
        lng
    ) VALUES (
        v_venue.id,
        p_title,
        p_category::public.offer_category,
        p_model::public.collaboration_model,
        p_date_label,
        'Flexible',
        p_value_label,
        p_slots,
        p_slots,
        p_title || ' — submitted via Marvi Society.',
        COALESCE(p_deliverables, ARRAY[]::TEXT[]),
        ARRAY['Approved creator membership'],
        'Submitted for admin review.',
        'review',
        v_venue.lat,
        v_venue.lng
    )
    RETURNING id INTO v_offer_id;

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
    VALUES (
        'campaign_review',
        v_offer_id,
        p_title,
        v_venue.venue_name || ' requested ' || p_slots::TEXT || ' creator slots.',
        'High',
        'open'
    );

    RETURN v_offer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_campaign_for_review(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[]) TO authenticated;

-- Exclude passed creators from swipe queue
-- Must drop first: return column order changed vs 20260611000001_secret_society_parity.
DROP FUNCTION IF EXISTS public.fetch_swipe_candidates(UUID);

CREATE OR REPLACE FUNCTION public.fetch_swipe_candidates(p_offer_id UUID DEFAULT NULL)
RETURNS TABLE (
    creator_id UUID,
    full_name TEXT,
    instagram_handle TEXT,
    audience_count INTEGER,
    score NUMERIC,
    city TEXT,
    niches TEXT[],
    proof_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue_id UUID;
BEGIN
    SELECT v.id INTO v_venue_id
    FROM public.venue_profiles v
    WHERE v.owner_user_id = auth.uid() AND v.status = 'approved'
    LIMIT 1;

    IF v_venue_id IS NULL THEN
        RAISE EXCEPTION 'No venue profile';
    END IF;

    RETURN QUERY
    SELECT
        cp.id,
        cp.full_name,
        cp.instagram_handle,
        cp.audience_count,
        cp.score,
        cp.city,
        cp.niches,
        cp.proof_rate
    FROM public.creator_profiles cp
    JOIN public.profiles p ON p.id = cp.user_id
    WHERE cp.status = 'approved'
      AND p.status = 'approved'
      AND NOT EXISTS (
          SELECT 1 FROM public.creator_shortlists s
          WHERE s.venue_id = v_venue_id
            AND s.creator_id = cp.id
            AND (p_offer_id IS NULL OR s.offer_id = p_offer_id)
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.creator_passes x
          WHERE x.venue_id = v_venue_id
            AND x.creator_id = cp.id
            AND (p_offer_id IS NULL OR x.offer_id = p_offer_id)
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260615000001_platform_completion.sql
-- ═══════════════════════════════════════════════════════════════════════════
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260616000001_transactional_email.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Transactional email: locale on profiles, outbox queue, signup + approval emails

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS preferred_locale TEXT NOT NULL DEFAULT 'en';

CREATE TABLE IF NOT EXISTS public.email_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
    to_email TEXT NOT NULL,
    template TEXT NOT NULL,
    locale TEXT NOT NULL DEFAULT 'en',
    variables JSONB NOT NULL DEFAULT '{}'::JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_outbox_pending
    ON public.email_outbox (status, created_at)
    WHERE status = 'pending';

ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY email_outbox_admin ON public.email_outbox
    FOR SELECT USING (public.is_admin());

-- Infer tr for Istanbul / Turkish preference, otherwise en
CREATE OR REPLACE FUNCTION public.infer_user_locale(
    p_meta_locale TEXT,
    p_city TEXT,
    p_languages TEXT[]
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN lower(coalesce(p_meta_locale, '')) IN ('tr', 'turkish', 'türkçe') THEN 'tr'
        WHEN lower(coalesce(p_city, '')) LIKE '%istanbul%'
            OR lower(coalesce(p_city, '')) IN ('kadıköy', 'kadikoy', 'beşiktaş', 'besiktas', 'şişli', 'sisli') THEN 'tr'
        WHEN p_languages IS NOT NULL AND EXISTS (
            SELECT 1 FROM unnest(p_languages) AS lang
            WHERE lower(lang) LIKE '%turk%'
        ) THEN 'tr'
        ELSE 'en'
    END;
$$;

CREATE OR REPLACE FUNCTION public.queue_transactional_email(
    p_user_id UUID,
    p_to_email TEXT,
    p_template TEXT,
    p_locale TEXT,
    p_variables JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF coalesce(trim(p_to_email), '') = '' THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.email_outbox (user_id, to_email, template, locale, variables, status)
    VALUES (
        p_user_id,
        lower(trim(p_to_email)),
        p_template,
        CASE WHEN lower(coalesce(p_locale, 'en')) LIKE 'tr%' THEN 'tr' ELSE 'en' END,
        coalesce(p_variables, '{}'::JSONB),
        'pending'
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.queue_transactional_email(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.queue_transactional_email(UUID, TEXT, TEXT, TEXT, JSONB) TO service_role;

-- Dispatch pending row to Edge Function (optional — set DB settings in EMAIL_SETUP.md)
CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        RETURN NEW;
    END;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 THEN
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/send-email',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object('outbox_id', NEW.id::TEXT)
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS email_outbox_dispatch ON public.email_outbox;
CREATE TRIGGER email_outbox_dispatch
    AFTER INSERT ON public.email_outbox
    FOR EACH ROW
    EXECUTE FUNCTION public.dispatch_email_outbox();

-- Signup: profile + creator + admin task + welcome email
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
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_locale := public.infer_user_locale(
        NEW.raw_user_meta_data ->> 'locale',
        v_city,
        NULL
    );

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (
        NEW.id,
        NEW.email,
        'creator',
        'under_review',
        v_locale
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, languages)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END
    );

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
    VALUES (
        'creator_application',
        NEW.id,
        'New creator application',
        coalesce(nullif(v_handle, ''), NEW.email, 'Unknown'),
        'High'
    );

    PERFORM public.queue_transactional_email(
        NEW.id,
        NEW.email,
        'welcome_application',
        v_locale,
        jsonb_build_object(
            'name', v_name,
            'city', v_city,
            'site_url', 'https://marvisociety.com'
        )
    );

    RETURN NEW;
END;
$$;

-- Approval email when admin approves creator application
CREATE OR REPLACE FUNCTION public.resolve_admin_task(p_task_id UUID, p_action TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task public.admin_tasks%ROWTYPE;
    v_approve BOOLEAN := lower(trim(p_action)) IN ('approve', 'approved');
    v_email TEXT;
    v_locale TEXT;
    v_name TEXT;
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
                SELECT p.email, p.preferred_locale, cp.full_name
                INTO v_email, v_locale, v_name
                FROM public.profiles p
                LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
                WHERE p.id = v_task.subject_id;

                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Üyeliğiniz onaylandı' ELSE 'Membership approved' END,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr'
                        THEN 'Marvi Society başvurunuz onaylandı. Keşfet sekmesinden canlı etkinliklere göz atın.'
                        ELSE 'Your Marvi Society creator application was approved. Explore live events now.'
                    END,
                    'membership',
                    'checkmark.seal.fill',
                    'emerald',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );

                PERFORM public.queue_transactional_email(
                    v_task.subject_id,
                    v_email,
                    'membership_approved',
                    coalesce(v_locale, 'en'),
                    jsonb_build_object(
                        'name', coalesce(nullif(v_name, ''), 'Creator'),
                        'site_url', 'https://marvisociety.com',
                        'app_url', 'https://marvisociety.com/creators'
                    )
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260617000001_referral_codes_bootstrap.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Default invite codes + server-side validation (fixes MARVI-IST hyphen filter issues)

INSERT INTO public.referral_codes (code, owner_type, max_uses)
VALUES
    ('MARVI-IST', 'creator', 500),
    ('TURGUT', 'creator', 500),
    ('MARVI2026', 'venue', 100)
ON CONFLICT (code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
BEGIN
    v_code := upper(trim(p_code));
    IF v_code = '' THEN
        RETURN false;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260618000001_admin_operations.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Admin operations: user directory, block/pause, email, in-app notify, location map, geo broadcast

CREATE TABLE IF NOT EXISTS public.user_location_snapshots (
    user_id UUID PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_location_snapshots_updated
    ON public.user_location_snapshots (updated_at DESC);

ALTER TABLE public.user_location_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_location_own ON public.user_location_snapshots
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY user_location_admin ON public.user_location_snapshots
    FOR SELECT USING (public.is_admin());

-- Client uploads last known location (throttled in app)
CREATE OR REPLACE FUNCTION public.upsert_user_location(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_lat IS NULL OR p_lng IS NULL OR abs(p_lat) > 90 OR abs(p_lng) > 180 THEN
        RAISE EXCEPTION 'Invalid coordinates';
    END IF;

    INSERT INTO public.user_location_snapshots (user_id, lat, lng, updated_at)
    VALUES (auth.uid(), p_lat, p_lng, now())
    ON CONFLICT (user_id) DO UPDATE SET
        lat = EXCLUDED.lat,
        lng = EXCLUDED.lng,
        updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_user_location(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_list_users(
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    role public.user_role,
    status public.membership_status,
    full_name TEXT,
    instagram_handle TEXT,
    city TEXT,
    strike_count BIGINT,
    booking_count BIGINT,
    last_lat DOUBLE PRECISION,
    last_lng DOUBLE PRECISION,
    last_seen_at TIMESTAMPTZ
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
    SELECT
        p.id,
        coalesce(p.email, u.email),
        p.role,
        p.status,
        cp.full_name,
        cp.instagram_handle,
        cp.city,
        (SELECT count(*) FROM public.strikes s JOIN public.creator_profiles c ON c.id = s.creator_id WHERE c.user_id = p.id),
        (SELECT count(*) FROM public.bookings b JOIN public.creator_profiles c ON c.id = b.creator_id WHERE c.user_id = p.id),
        loc.lat,
        loc.lng,
        loc.updated_at
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
    LEFT JOIN public.user_location_snapshots loc ON loc.user_id = p.id
    WHERE (
        p_search IS NULL OR trim(p_search) = ''
        OR lower(coalesce(p.email, u.email, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.full_name, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.city, '')) LIKE '%' || lower(trim(p_search)) || '%'
    )
    AND (
        p_status IS NULL OR trim(p_status) = ''
        OR p.status::TEXT = lower(trim(p_status))
    )
    ORDER BY p.updated_at DESC NULLS LAST, p.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 100), 200));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_users(TEXT, TEXT, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_get_user_detail(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_result JSONB;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    SELECT id INTO v_creator_id FROM public.creator_profiles WHERE user_id = p_user_id LIMIT 1;

    SELECT jsonb_build_object(
        'user_id', p.id,
        'email', coalesce(p.email, u.email),
        'role', p.role,
        'status', p.status,
        'referral_code', p.referral_code,
        'preferred_locale', p.preferred_locale,
        'phone', p.phone,
        'created_at', p.created_at,
        'creator', (
            SELECT to_jsonb(cp.*) FROM public.creator_profiles cp WHERE cp.user_id = p.id
        ),
        'venue', (
            SELECT to_jsonb(v.*) FROM public.venue_profiles v WHERE v.owner_user_id = p.id LIMIT 1
        ),
        'location', (
            SELECT to_jsonb(loc.*) FROM public.user_location_snapshots loc WHERE loc.user_id = p.id
        ),
        'strikes', coalesce((
            SELECT jsonb_agg(to_jsonb(s.*) ORDER BY s.created_at DESC)
            FROM public.strikes s
            WHERE v_creator_id IS NOT NULL AND s.creator_id = v_creator_id
        ), '[]'::JSONB),
        'bookings', coalesce((
            SELECT jsonb_agg(jsonb_build_object(
                'id', b.id,
                'stage', b.stage,
                'offer_title', o.title,
                'venue_name', v.venue_name,
                'created_at', b.created_at
            ) ORDER BY b.created_at DESC)
            FROM public.bookings b
            JOIN public.offers o ON o.id = b.offer_id
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE v_creator_id IS NOT NULL AND b.creator_id = v_creator_id
        ), '[]'::JSONB),
        'notifications', coalesce((
            SELECT jsonb_agg(nrow ORDER BY (nrow->>'created_at') DESC)
            FROM (
                SELECT jsonb_build_object(
                    'id', n.id,
                    'title', n.title,
                    'body', n.body,
                    'type', n.type,
                    'created_at', n.created_at
                ) AS nrow
                FROM public.notifications n
                WHERE n.user_id = p_user_id
                ORDER BY n.created_at DESC
                LIMIT 20
            ) recent
        ), '[]'::JSONB)
    ) INTO v_result
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p.id = p_user_id;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_user_detail(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_membership_status(
    p_user_id UUID,
    p_status public.membership_status
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot change your own status';
    END IF;

    UPDATE public.profiles
    SET status = p_status, updated_at = now()
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE public.creator_profiles
    SET status = p_status, updated_at = now()
    WHERE user_id = p_user_id;

    UPDATE public.venue_profiles
    SET status = CASE WHEN p_status = 'approved' THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
        updated_at = now()
    WHERE owner_user_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_membership_status(UUID, public.membership_status) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_send_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT DEFAULT 'admin'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF coalesce(trim(p_title), '') = '' OR coalesce(trim(p_body), '') = '' THEN
        RAISE EXCEPTION 'Title and body required';
    END IF;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        p_user_id,
        trim(p_title),
        trim(p_body),
        coalesce(nullif(trim(p_type), ''), 'admin'),
        'bell.fill',
        'rose',
        jsonb_build_object('source', 'admin_console')
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_send_notification(UUID, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_send_email(
    p_user_id UUID,
    p_subject TEXT,
    p_body TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email TEXT;
    v_locale TEXT;
    v_name TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    SELECT coalesce(p.email, u.email), coalesce(p.preferred_locale, 'en'), coalesce(cp.full_name, split_part(coalesce(p.email, u.email, ''), '@', 1))
    INTO v_email, v_locale, v_name
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
    WHERE p.id = p_user_id;

    IF v_email IS NULL OR trim(v_email) = '' THEN
        RAISE EXCEPTION 'User has no email';
    END IF;

    RETURN public.queue_transactional_email(
        p_user_id,
        v_email,
        'admin_message',
        v_locale,
        jsonb_build_object(
            'name', v_name,
            'subject', trim(p_subject),
            'body', trim(p_body),
            'site_url', 'https://marvisociety.com'
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_send_email(UUID, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_notify_users_in_radius(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_km DOUBLE PRECISION,
    p_title TEXT,
    p_body TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER := 0;
    v_row RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF abs(p_lat) > 90 OR abs(p_lng) > 180 OR p_radius_km <= 0 THEN
        RAISE EXCEPTION 'Invalid map parameters';
    END IF;

    IF coalesce(trim(p_title), '') = '' OR coalesce(trim(p_body), '') = '' THEN
        RAISE EXCEPTION 'Title and body required';
    END IF;

    FOR v_row IN
        SELECT loc.user_id
        FROM public.user_location_snapshots loc
        JOIN public.profiles p ON p.id = loc.user_id
        WHERE p.status = 'approved'
          AND (
            6371 * acos(
                least(1.0, greatest(-1.0,
                    cos(radians(p_lat)) * cos(radians(loc.lat))
                    * cos(radians(loc.lng) - radians(p_lng))
                    + sin(radians(p_lat)) * sin(radians(loc.lat))
                ))
            )
          ) <= p_radius_km
    LOOP
        PERFORM public.admin_send_notification(
            v_row.user_id,
            trim(p_title),
            trim(p_body),
            'admin_geo'
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_notify_users_in_radius(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated;

-- Invite flow: create referral code + queue invite email (user signs up in app)
CREATE OR REPLACE FUNCTION public.admin_send_invite(
    p_email TEXT,
    p_invite_code TEXT DEFAULT NULL,
    p_max_uses INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_email TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_email := lower(trim(p_email));
    IF v_email = '' OR position('@' IN v_email) = 0 THEN
        RAISE EXCEPTION 'Valid email required';
    END IF;

    v_code := upper(coalesce(nullif(trim(p_invite_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8)));

    INSERT INTO public.referral_codes (code, owner_type, max_uses)
    VALUES (v_code, 'creator', greatest(1, coalesce(p_max_uses, 1)))
    ON CONFLICT (code) DO UPDATE SET max_uses = EXCLUDED.max_uses;

    PERFORM public.queue_transactional_email(
        NULL,
        v_email,
        'invite_code',
        'en',
        jsonb_build_object(
            'email', v_email,
            'invite_code', v_code,
            'site_url', 'https://marvisociety.com'
        )
    );

    RETURN jsonb_build_object('email', v_email, 'invite_code', v_code);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_send_invite(TEXT, TEXT, INTEGER) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260619000001_push_outbox.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Push outbox + hook admin notifications to remote push delivery

CREATE TABLE IF NOT EXISTS public.push_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_outbox_pending
    ON public.push_outbox (status, created_at)
    WHERE status = 'pending';

ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY push_outbox_admin ON public.push_outbox
    FOR SELECT USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.queue_push_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF p_user_id IS NULL OR coalesce(trim(p_title), '') = '' OR coalesce(trim(p_body), '') = '' THEN
        RETURN NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.device_tokens WHERE user_id = p_user_id) THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.push_outbox (user_id, title, body, payload, status)
    VALUES (p_user_id, trim(p_title), trim(p_body), coalesce(p_payload, '{}'::JSONB), 'pending')
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.queue_push_notification(UUID, TEXT, TEXT, JSONB) TO authenticated;

CREATE OR REPLACE FUNCTION public.dispatch_push_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        RETURN NEW;
    END;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 THEN
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object('outbox_id', NEW.id::TEXT)
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_outbox_dispatch ON public.push_outbox;
CREATE TRIGGER push_outbox_dispatch
    AFTER INSERT ON public.push_outbox
    FOR EACH ROW
    EXECUTE FUNCTION public.dispatch_push_outbox();

-- Admin in-app notification also queues APNs when device token exists
CREATE OR REPLACE FUNCTION public.admin_send_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT DEFAULT 'admin'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
    v_type TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF coalesce(trim(p_title), '') = '' OR coalesce(trim(p_body), '') = '' THEN
        RAISE EXCEPTION 'Title and body required';
    END IF;

    v_type := coalesce(nullif(trim(p_type), ''), 'admin');

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        p_user_id,
        trim(p_title),
        trim(p_body),
        v_type,
        'bell.fill',
        'rose',
        jsonb_build_object('source', 'admin_console')
    )
    RETURNING id INTO v_id;

    PERFORM public.queue_push_notification(
        p_user_id,
        trim(p_title),
        trim(p_body),
        jsonb_build_object('type', v_type, 'notification_id', v_id::TEXT)
    );

    RETURN v_id;
END;
$$;

-- Allow admins to read device tokens for delivery diagnostics
CREATE POLICY device_tokens_admin_read ON public.device_tokens
    FOR SELECT USING (public.is_admin());


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260620000001_account_lifecycle.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Self-service account lifecycle: pause, reactivate, improved deletion

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS paused_by_self BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS status_before_pause public.membership_status;

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
    WHERE email = (SELECT email FROM auth.users WHERE id = v_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.pause_own_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.reactivate_own_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260621000001_multi_venue_accounts.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Multi-venue accounts: one user manages many locations (restaurant, hotel, shop, etc.)

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS active_venue_id UUID REFERENCES public.venue_profiles (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_active_venue ON public.profiles (active_venue_id);

-- Resolve which venue the current session operates on.
CREATE OR REPLACE FUNCTION public.resolve_active_venue_id(p_venue_id UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_active UUID;
    v_resolved UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_venue_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = p_venue_id AND v.owner_user_id = v_uid
        ) THEN
            RAISE EXCEPTION 'Venue not found on your account';
        END IF;
        RETURN p_venue_id;
    END IF;

    SELECT p.active_venue_id INTO v_active
    FROM public.profiles p
    WHERE p.id = v_uid;

    IF v_active IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.venue_profiles v
        WHERE v.id = v_active AND v.owner_user_id = v_uid
    ) THEN
        RETURN v_active;
    END IF;

    SELECT v.id INTO v_resolved
    FROM public.venue_profiles v
    WHERE v.owner_user_id = v_uid
    ORDER BY
        CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END,
        v.created_at
    LIMIT 1;

    IF v_resolved IS NULL THEN
        RAISE EXCEPTION 'No venue profile';
    END IF;

    UPDATE public.profiles
    SET active_venue_id = v_resolved, updated_at = now()
    WHERE id = v_uid AND active_venue_id IS DISTINCT FROM v_resolved;

    RETURN v_resolved;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_active_venue_id(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.fetch_my_venues()
RETURNS TABLE (
    id UUID,
    venue_name TEXT,
    area TEXT,
    category public.offer_category,
    status public.membership_status,
    is_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_active UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT p.active_venue_id INTO v_active
    FROM public.profiles p
    WHERE p.id = v_uid;

    IF v_active IS NULL THEN
        v_active := public.resolve_active_venue_id(NULL);
    END IF;

    RETURN QUERY
    SELECT
        v.id,
        v.venue_name,
        v.area,
        v.category,
        v.status,
        (v.id = v_active)
    FROM public.venue_profiles v
    WHERE v.owner_user_id = v_uid
    ORDER BY
        (v.id = v_active) DESC,
        CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END,
        v.created_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_my_venues() TO authenticated;

CREATE OR REPLACE FUNCTION public.set_active_venue(p_venue_id UUID)
RETURNS void
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

    IF NOT EXISTS (
        SELECT 1 FROM public.venue_profiles v
        WHERE v.id = p_venue_id AND v.owner_user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'Venue not found on your account';
    END IF;

    UPDATE public.profiles
    SET active_venue_id = p_venue_id, updated_at = now()
    WHERE id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_active_venue(UUID) TO authenticated;

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
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_name = '' OR v_area = '' THEN
        RAISE EXCEPTION 'Venue name and area are required';
    END IF;

    INSERT INTO public.venue_profiles (
        owner_user_id,
        venue_name,
        area,
        category,
        address,
        contact_name,
        contact_phone,
        lat,
        lng,
        status
    ) VALUES (
        v_uid,
        v_name,
        v_area,
        p_category::public.offer_category,
        COALESCE(p_address, ''),
        COALESCE(p_contact_name, ''),
        COALESCE(p_contact_phone, ''),
        p_lat,
        p_lng,
        'under_review'::public.membership_status
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

GRANT EXECUTE ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- Venue-scoped RPCs: use active venue or derive from offer when provided.

DROP FUNCTION IF EXISTS public.submit_campaign_for_review(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[]);

CREATE OR REPLACE FUNCTION public.submit_campaign_for_review(
    p_title TEXT,
    p_category TEXT,
    p_model TEXT,
    p_date_label TEXT,
    p_value_label TEXT,
    p_slots INTEGER,
    p_deliverables TEXT[],
    p_venue_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue public.venue_profiles%ROWTYPE;
    v_offer_id UUID;
    v_venue_id UUID;
BEGIN
    v_venue_id := public.resolve_active_venue_id(p_venue_id);

    SELECT * INTO v_venue
    FROM public.venue_profiles
    WHERE id = v_venue_id;

    IF v_venue.status <> 'approved' THEN
        RAISE EXCEPTION 'Venue must be approved before creating campaigns';
    END IF;

    INSERT INTO public.offers (
        venue_id,
        title,
        category,
        model,
        date_label,
        time_label,
        value_label,
        capacity,
        remaining_slots,
        description,
        deliverables,
        requirements,
        host_note,
        status,
        lat,
        lng
    ) VALUES (
        v_venue.id,
        p_title,
        p_category::public.offer_category,
        p_model::public.collaboration_model,
        p_date_label,
        'Flexible',
        p_value_label,
        p_slots,
        p_slots,
        p_title || ' — submitted via Marvi Society.',
        COALESCE(p_deliverables, ARRAY[]::TEXT[]),
        ARRAY['Approved creator membership'],
        'Submitted for admin review.',
        'review',
        v_venue.lat,
        v_venue.lng
    )
    RETURNING id INTO v_offer_id;

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
    VALUES (
        'campaign_review',
        v_offer_id,
        p_title,
        v_venue.venue_name || ' requested ' || p_slots::TEXT || ' creator slots.',
        'High',
        'open'
    );

    RETURN v_offer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_campaign_for_review(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[], UUID) TO authenticated;

DROP FUNCTION IF EXISTS public.fetch_swipe_candidates(UUID);

CREATE OR REPLACE FUNCTION public.fetch_swipe_candidates(p_offer_id UUID DEFAULT NULL)
RETURNS TABLE (
    creator_id UUID,
    full_name TEXT,
    instagram_handle TEXT,
    audience_count INTEGER,
    score NUMERIC,
    city TEXT,
    niches TEXT[],
    proof_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue_id UUID;
BEGIN
    IF p_offer_id IS NOT NULL THEN
        SELECT o.venue_id INTO v_venue_id
        FROM public.offers o
        JOIN public.venue_profiles v ON v.id = o.venue_id
        WHERE o.id = p_offer_id
          AND v.owner_user_id = auth.uid()
          AND v.status = 'approved';

        IF v_venue_id IS NULL THEN
            RAISE EXCEPTION 'Offer not found for your venues';
        END IF;
    ELSE
        v_venue_id := public.resolve_active_venue_id(NULL);
    END IF;

    RETURN QUERY
    SELECT
        cp.id,
        cp.full_name,
        cp.instagram_handle,
        cp.audience_count,
        cp.score,
        cp.city,
        cp.niches,
        cp.proof_rate
    FROM public.creator_profiles cp
    JOIN public.profiles p ON p.id = cp.user_id
    WHERE cp.status = 'approved'
      AND p.status = 'approved'
      AND NOT EXISTS (
          SELECT 1 FROM public.creator_shortlists s
          WHERE s.venue_id = v_venue_id
            AND s.creator_id = cp.id
            AND (p_offer_id IS NULL OR s.offer_id = p_offer_id)
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.creator_passes x
          WHERE x.venue_id = v_venue_id
            AND x.creator_id = cp.id
            AND (p_offer_id IS NULL OR x.offer_id = p_offer_id)
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

GRANT EXECUTE ON FUNCTION public.shortlist_creator(UUID, UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.pass_creator(
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

    INSERT INTO public.creator_passes (venue_id, creator_id, offer_id)
    VALUES (v_venue_id, p_creator_id, p_offer_id)
    ON CONFLICT DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pass_creator(UUID, UUID, UUID) TO authenticated;

-- Drop legacy 2-arg overloads if present
DROP FUNCTION IF EXISTS public.shortlist_creator(UUID, UUID);
DROP FUNCTION IF EXISTS public.pass_creator(UUID, UUID);


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260624000001_email_production_hardening.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Email production hardening: dispatch diagnostics, review account skip, contact log, retry helper

-- ---------------------------------------------------------------------------
-- 1. Contact messages (audit trail; notification goes to email_outbox)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.contact_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    subject TEXT NOT NULL DEFAULT 'General support',
    message TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'web',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS contact_messages_insert_public ON public.contact_messages;
CREATE POLICY contact_messages_insert_public ON public.contact_messages
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS contact_messages_admin_read ON public.contact_messages;
CREATE POLICY contact_messages_admin_read ON public.contact_messages
    FOR SELECT USING (public.is_admin());

GRANT INSERT ON public.contact_messages TO anon, authenticated;
GRANT SELECT ON public.contact_messages TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Dispatch: record config errors instead of silent no-op
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        v_url := NULL;
        v_key := NULL;
    END;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured: set marvi.edge_function_url and marvi.service_role_key (see docs/EMAIL_SETUP.md)'
        WHERE id = NEW.id;
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/send-email',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object('outbox_id', NEW.id::TEXT)
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    UPDATE public.email_outbox
    SET status = 'failed', error_message = SQLERRM
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Skip welcome/admin task noise for Apple review account
-- ---------------------------------------------------------------------------
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
    v_is_review BOOLEAN := lower(coalesce(NEW.email, '')) = 'review@marvisociety.com';
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_locale := public.infer_user_locale(
        NEW.raw_user_meta_data ->> 'locale',
        v_city,
        NULL
    );

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (
        NEW.id,
        NEW.email,
        'creator',
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END,
        v_locale
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, languages, status)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END,
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END
    );

    IF NOT v_is_review THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
        VALUES (
            'creator_application',
            NEW.id,
            'New creator application',
            coalesce(nullif(v_handle, ''), NEW.email, 'Unknown'),
            'High'
        );

        PERFORM public.queue_transactional_email(
            NEW.id,
            NEW.email,
            'welcome_application',
            v_locale,
            jsonb_build_object(
                'name', v_name,
                'city', v_city,
                'site_url', 'https://marvisociety.com'
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Retry failed/pending outbox rows (run manually or via cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.retry_pending_emails(p_limit INTEGER DEFAULT 20)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    v_row RECORD;
    v_count INTEGER := 0;
BEGIN
    IF NOT public.is_admin() AND auth.role() <> 'service_role' THEN
        RAISE EXCEPTION 'Admin or service role required';
    END IF;

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Email dispatch not configured';
    END;

    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE EXCEPTION 'Email dispatch not configured';
    END IF;

    FOR v_row IN
        SELECT id FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
        ORDER BY created_at ASC
        LIMIT p_limit
    LOOP
        UPDATE public.email_outbox SET status = 'pending', error_message = NULL WHERE id = v_row.id;

        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            body := jsonb_build_object('outbox_id', v_row.id::TEXT)
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.retry_pending_emails(INTEGER) TO service_role;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000001_security_hardening.sql
-- ═══════════════════════════════════════════════════════════════════════════
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000002_feature_completeness.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Feature completeness: creator→venue ratings, profile avatar/cover, profile media storage.

-- ---------------------------------------------------------------------------
-- 1. Creator reviews (influencer rates venue after visit)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.creator_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings (id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    hospitality SMALLINT NOT NULL CHECK (hospitality BETWEEN 1 AND 5),
    experience SMALLINT NOT NULL CHECK (experience BETWEEN 1 AND 5),
    comment TEXT NOT NULL DEFAULT '',
    created_by UUID NOT NULL REFERENCES public.profiles (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.creator_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY creator_reviews_select ON public.creator_reviews
    FOR SELECT USING (
        created_by = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = creator_reviews.venue_id AND v.owner_user_id = auth.uid()
        )
    );

CREATE POLICY creator_reviews_insert ON public.creator_reviews
    FOR INSERT WITH CHECK (
        created_by = auth.uid()
        AND creator_id = public.current_creator_id()
    );

CREATE OR REPLACE FUNCTION public.submit_creator_review(
    p_booking_id UUID,
    p_hospitality INT,
    p_experience INT,
    p_comment TEXT DEFAULT ''
)
RETURNS public.creator_reviews
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_creator_id UUID;
    v_row public.creator_reviews;
    v_booking public.bookings;
    v_venue_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    IF p_hospitality < 1 OR p_hospitality > 5 OR p_experience < 1 OR p_experience > 5 THEN
        RAISE EXCEPTION 'Ratings must be between 1 and 5';
    END IF;

    SELECT b.* INTO v_booking FROM public.bookings b WHERE b.id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;

    IF v_booking.creator_id IS DISTINCT FROM v_creator_id THEN
        RAISE EXCEPTION 'Not authorized to review this booking';
    END IF;

    IF v_booking.stage NOT IN ('checked_in', 'proof_due', 'completed') THEN
        RAISE EXCEPTION 'Visit must be checked in before rating the venue';
    END IF;

    SELECT o.venue_id INTO v_venue_id
    FROM public.offers o
    WHERE o.id = v_booking.offer_id;

    INSERT INTO public.creator_reviews (
        booking_id, venue_id, creator_id, hospitality, experience, comment, created_by
    )
    VALUES (
        p_booking_id,
        v_venue_id,
        v_creator_id,
        p_hospitality,
        p_experience,
        COALESCE(p_comment, ''),
        v_uid
    )
    ON CONFLICT (booking_id) DO UPDATE SET
        hospitality = EXCLUDED.hospitality,
        experience = EXCLUDED.experience,
        comment = EXCLUDED.comment,
        created_at = now()
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_creator_review(UUID, INT, INT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Profile avatar + cover on creator_profiles
-- ---------------------------------------------------------------------------
ALTER TABLE public.creator_profiles
    ADD COLUMN IF NOT EXISTS avatar_url TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS cover_url TEXT NOT NULL DEFAULT '';

-- ---------------------------------------------------------------------------
-- 3. Profile media storage (user-scoped uploads, public read)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('profile-media', 'profile-media', true, 5242880)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY profile_media_public_read ON storage.objects
    FOR SELECT USING (bucket_id = 'profile-media');

CREATE POLICY profile_media_upload_own ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY profile_media_update_own ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY profile_media_delete_own ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000003_invite_social_completeness.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Invite email binding, creator-to-creator invites, TikTok on signup

ALTER TABLE public.referral_codes
    ADD COLUMN IF NOT EXISTS invite_email TEXT;

CREATE INDEX IF NOT EXISTS idx_referral_codes_invite_email
    ON public.referral_codes (lower(invite_email))
    WHERE invite_email IS NOT NULL;

-- Redeem invite: optional email lock when code was emailed to a specific address
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
    v_user_email TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_code := upper(trim(p_code));
    IF v_code = '' THEN
        RAISE EXCEPTION 'Invite code required';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND referral_code IS NOT NULL
    ) THEN
        RETURN;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid invite code';
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RAISE EXCEPTION 'Invite code has reached its limit';
    END IF;

    IF v_row.invite_email IS NOT NULL AND trim(v_row.invite_email) <> '' THEN
        SELECT lower(trim(email)) INTO v_user_email
        FROM public.profiles
        WHERE id = auth.uid();

        IF v_user_email IS NULL OR v_user_email <> lower(trim(v_row.invite_email)) THEN
            RAISE EXCEPTION 'This invite was sent to a different email address';
        END IF;
    END IF;

    UPDATE public.referral_codes
    SET uses_count = uses_count + 1
    WHERE id = v_row.id;

    UPDATE public.profiles
    SET referral_code = v_code
    WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT) TO authenticated;

-- Creator invites a friend by email (single-use code bound to recipient email)
CREATE OR REPLACE FUNCTION public.send_creator_invite(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email TEXT;
    v_code TEXT;
    v_locale TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_email := lower(trim(p_email));
    IF v_email = '' OR position('@' IN v_email) = 0 THEN
        RAISE EXCEPTION 'Valid email required';
    END IF;

    IF v_email = lower(trim((SELECT email FROM public.profiles WHERE id = auth.uid()))) THEN
        RAISE EXCEPTION 'You cannot invite yourself';
    END IF;

    v_code := 'MARVI-' || upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8));

    INSERT INTO public.referral_codes (code, owner_user_id, owner_type, max_uses, invite_email)
    VALUES (v_code, auth.uid(), 'creator', 1, v_email);

    SELECT coalesce(preferred_locale, 'en') INTO v_locale
    FROM public.profiles
    WHERE id = auth.uid();

    PERFORM public.queue_transactional_email(
        NULL,
        v_email,
        'invite_code',
        v_locale,
        jsonb_build_object(
            'email', v_email,
            'invite_code', v_code,
            'site_url', 'https://marvisociety.com',
            'deep_link', 'marvisociety://invite?code=' || v_code
        )
    );

    RETURN jsonb_build_object('email', v_email, 'invite_code', v_code);
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_creator_invite(TEXT) TO authenticated;

-- Admin invite: also bind recipient email
CREATE OR REPLACE FUNCTION public.admin_send_invite(
    p_email TEXT,
    p_invite_code TEXT DEFAULT NULL,
    p_max_uses INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_email TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_email := lower(trim(p_email));
    IF v_email = '' OR position('@' IN v_email) = 0 THEN
        RAISE EXCEPTION 'Valid email required';
    END IF;

    v_code := upper(coalesce(nullif(trim(p_invite_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8)));

    INSERT INTO public.referral_codes (code, owner_type, max_uses, invite_email)
    VALUES (v_code, 'creator', greatest(1, coalesce(p_max_uses, 1)), v_email)
    ON CONFLICT (code) DO UPDATE
        SET max_uses = EXCLUDED.max_uses,
            invite_email = EXCLUDED.invite_email;

    PERFORM public.queue_transactional_email(
        NULL,
        v_email,
        'invite_code',
        'en',
        jsonb_build_object(
            'email', v_email,
            'invite_code', v_code,
            'site_url', 'https://marvisociety.com',
            'deep_link', 'marvisociety://invite?code=' || v_code
        )
    );

    RETURN jsonb_build_object('email', v_email, 'invite_code', v_code);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_send_invite(TEXT, TEXT, INTEGER) TO authenticated;

-- Store TikTok handle from signup metadata
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
    v_is_review BOOLEAN := lower(coalesce(NEW.email, '')) = 'review@marvisociety.com';
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_tiktok := coalesce(NEW.raw_user_meta_data ->> 'tiktok_handle', '');
    v_locale := public.infer_user_locale(
        NEW.raw_user_meta_data ->> 'locale',
        v_city,
        NULL
    );

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (
        NEW.id,
        NEW.email,
        'creator',
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END,
        v_locale
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, tiktok_handle, city, languages, status)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_tiktok,
        v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END,
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END
    );

    IF NOT v_is_review THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
        VALUES (
            'creator_application',
            NEW.id,
            'New creator application',
            coalesce(nullif(v_handle, ''), NEW.email, 'Unknown'),
            'High'
        );

        PERFORM public.queue_transactional_email(
            NEW.id,
            NEW.email,
            'welcome_application',
            v_locale,
            jsonb_build_object(
                'name', v_name,
                'city', v_city,
                'site_url', 'https://marvisociety.com'
            )
        );
    END IF;

    RETURN NEW;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000004_social_graph.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Social graph: follows + collaboration history with two-way reviews

-- ---------------------------------------------------------------------------
-- Follows (any profile can follow any other profile: creators and venue owners)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.follows (
    follower_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    followee_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id),
    CONSTRAINT follows_no_self CHECK (follower_id <> followee_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_followee ON public.follows (followee_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows (follower_id);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS follows_select ON public.follows;
CREATE POLICY follows_select ON public.follows
    FOR SELECT USING (true);

DROP POLICY IF EXISTS follows_insert ON public.follows;
CREATE POLICY follows_insert ON public.follows
    FOR INSERT WITH CHECK (follower_id = auth.uid());

DROP POLICY IF EXISTS follows_delete ON public.follows;
CREATE POLICY follows_delete ON public.follows
    FOR DELETE USING (follower_id = auth.uid());

CREATE OR REPLACE FUNCTION public.follow_user(p_target UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF p_target = auth.uid() THEN
        RAISE EXCEPTION 'Cannot follow yourself';
    END IF;
    INSERT INTO public.follows (follower_id, followee_id)
    VALUES (auth.uid(), p_target)
    ON CONFLICT DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.follow_user(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.unfollow_user(p_target UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    DELETE FROM public.follows
    WHERE follower_id = auth.uid() AND followee_id = p_target;
END;
$$;

GRANT EXECUTE ON FUNCTION public.unfollow_user(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Collaboration history for the signed-in creator
-- Returns venues visited, the rating the venue gave them, and their own review.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_collaboration_history()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_result JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(jsonb_agg(entry ORDER BY entry->>'date' DESC), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'booking_id', b.id,
            'venue_id', v.id,
            'venue_name', v.venue_name,
            'area', v.area,
            'category', v.category,
            'title', o.title,
            'stage', b.stage,
            'date', b.created_at,
            'venue_rating', CASE
                WHEN vr.id IS NOT NULL THEN jsonb_build_object(
                    'punctuality', vr.punctuality,
                    'presentation', vr.presentation,
                    'comment', vr.comment
                )
                ELSE NULL
            END,
            'my_rating', CASE
                WHEN cr.id IS NOT NULL THEN jsonb_build_object(
                    'hospitality', cr.hospitality,
                    'experience', cr.experience,
                    'comment', cr.comment
                )
                ELSE NULL
            END
        ) AS entry
        FROM public.bookings b
        JOIN public.offers o ON o.id = b.offer_id
        JOIN public.venue_profiles v ON v.id = o.venue_id
        LEFT JOIN public.venue_reviews vr ON vr.booking_id = b.id
        LEFT JOIN public.creator_reviews cr ON cr.booking_id = b.id
        WHERE b.creator_id = v_creator_id
          AND b.stage IN ('checked_in', 'proof_due', 'completed')
    ) rows;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_collaboration_history() TO authenticated;

-- ---------------------------------------------------------------------------
-- Public creator profile (viewable by any authenticated member)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_creator_public_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator public.creator_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_reviews JSONB;
    v_collabs JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_creator FROM public.creator_profiles WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = p_user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = p_user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows WHERE follower_id = auth.uid() AND followee_id = p_user_id
    ) INTO v_is_following;

    -- Reviews the creator received from venues
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'venue_name', v.venue_name,
        'punctuality', vr.punctuality,
        'presentation', vr.presentation,
        'comment', vr.comment,
        'date', vr.created_at
    ) ORDER BY vr.created_at DESC), '[]'::JSONB)
    INTO v_reviews
    FROM public.venue_reviews vr
    JOIN public.venue_profiles v ON v.id = vr.venue_id
    WHERE vr.creator_id = v_creator.id;

    -- Venues the creator collaborated with
    SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'venue_name', v.venue_name,
        'area', v.area,
        'category', v.category
    )), '[]'::JSONB)
    INTO v_collabs
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE b.creator_id = v_creator.id
      AND b.stage IN ('checked_in', 'proof_due', 'completed');

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'full_name', v_creator.full_name,
        'instagram_handle', v_creator.instagram_handle,
        'tiktok_handle', v_creator.tiktok_handle,
        'city', v_creator.city,
        'bio', v_creator.bio,
        'niches', v_creator.niches,
        'score', v_creator.score,
        'proof_rate', v_creator.proof_rate,
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Follower / following counts for the signed-in user
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_follow_counts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    RETURN jsonb_build_object(
        'followers', (SELECT count(*) FROM public.follows WHERE followee_id = auth.uid()),
        'following', (SELECT count(*) FROM public.follows WHERE follower_id = auth.uid())
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_follow_counts() TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000005_creator_public_profile_by_id.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Public creator profile lookup by creator_profiles.id

CREATE OR REPLACE FUNCTION public.get_creator_public_profile_by_creator_id(p_creator_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator public.creator_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_reviews JSONB;
    v_collabs JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_creator FROM public.creator_profiles WHERE id = p_creator_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = v_creator.user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = v_creator.user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = auth.uid() AND followee_id = v_creator.user_id
    ) INTO v_is_following;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'venue_name', v.venue_name,
        'punctuality', vr.punctuality,
        'presentation', vr.presentation,
        'comment', vr.comment,
        'date', vr.created_at
    ) ORDER BY vr.created_at DESC), '[]'::JSONB)
    INTO v_reviews
    FROM public.venue_reviews vr
    JOIN public.venue_profiles v ON v.id = vr.venue_id
    WHERE vr.creator_id = v_creator.id;

    SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'venue_name', v.venue_name,
        'area', v.area,
        'category', v.category
    )), '[]'::JSONB)
    INTO v_collabs
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE b.creator_id = v_creator.id
      AND b.stage IN ('checked_in', 'proof_due', 'completed');

    RETURN jsonb_build_object(
        'creator_id', v_creator.id,
        'user_id', v_creator.user_id,
        'full_name', v_creator.full_name,
        'instagram_handle', v_creator.instagram_handle,
        'tiktok_handle', v_creator.tiktok_handle,
        'city', v_creator.city,
        'bio', v_creator.bio,
        'niches', v_creator.niches,
        'score', v_creator.score,
        'proof_rate', v_creator.proof_rate,
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile_by_creator_id(UUID) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000006_creator_showcase.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Creator showcase: a portfolio gallery on the profile.
-- Creators add their best content — uploaded photos or links to their
-- Instagram / TikTok posts — to display on their (public) profile.

CREATE TABLE IF NOT EXISTS public.creator_showcase (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES public.profiles (id) ON DELETE CASCADE,
    media_type TEXT NOT NULL DEFAULT 'image' CHECK (media_type IN ('image', 'video', 'link')),
    media_url TEXT NOT NULL DEFAULT '',
    external_url TEXT NOT NULL DEFAULT '',
    caption TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_creator_showcase_user
    ON public.creator_showcase (user_id, created_at DESC);

ALTER TABLE public.creator_showcase ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS creator_showcase_select ON public.creator_showcase;
CREATE POLICY creator_showcase_select ON public.creator_showcase
    FOR SELECT USING (true);

DROP POLICY IF EXISTS creator_showcase_insert ON public.creator_showcase;
CREATE POLICY creator_showcase_insert ON public.creator_showcase
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS creator_showcase_update ON public.creator_showcase;
CREATE POLICY creator_showcase_update ON public.creator_showcase
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS creator_showcase_delete ON public.creator_showcase;
CREATE POLICY creator_showcase_delete ON public.creator_showcase
    FOR DELETE USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.creator_showcase TO authenticated;
GRANT SELECT ON public.creator_showcase TO anon;

-- Delete helper (the iOS client has no generic table-delete method).
CREATE OR REPLACE FUNCTION public.delete_showcase_item(p_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    DELETE FROM public.creator_showcase
    WHERE id = p_id AND user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_showcase_item(UUID) TO authenticated;

-- Public fetch of a user's showcase (used on public creator profiles).
CREATE OR REPLACE FUNCTION public.get_user_showcase(p_user_id UUID)
RETURNS SETOF public.creator_showcase
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT *
    FROM public.creator_showcase
    WHERE user_id = p_user_id
    ORDER BY created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_showcase(UUID) TO authenticated, anon;

-- Showcase for the signed-in user.
CREATE OR REPLACE FUNCTION public.get_my_showcase()
RETURNS SETOF public.creator_showcase
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT *
    FROM public.creator_showcase
    WHERE user_id = auth.uid()
    ORDER BY created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_showcase() TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000007_chat_activity_mutual_match.sql
-- ═══════════════════════════════════════════════════════════════════════════
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000008_fix_rpc_overloads.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Fix production RPC errors seen in TestFlight:
-- 1) accept_offer(uuid) vs accept_offer(uuid,text,integer) ambiguity
-- 2) resolve_active_venue_id marked STABLE but performs UPDATE

-- Drop legacy single-argument overload (superseded by 3-arg version with defaults).
DROP FUNCTION IF EXISTS public.accept_offer(UUID);

GRANT EXECUTE ON FUNCTION public.accept_offer(UUID, TEXT, INTEGER) TO authenticated;

-- resolve_active_venue_id may UPDATE profiles.active_venue_id — must be VOLATILE.
CREATE OR REPLACE FUNCTION public.resolve_active_venue_id(p_venue_id UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_active UUID;
    v_resolved UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_venue_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = p_venue_id AND v.owner_user_id = v_uid
        ) THEN
            RAISE EXCEPTION 'Venue not found on your account';
        END IF;
        RETURN p_venue_id;
    END IF;

    SELECT p.active_venue_id INTO v_active
    FROM public.profiles p
    WHERE p.id = v_uid;

    IF v_active IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.venue_profiles v
        WHERE v.id = v_active AND v.owner_user_id = v_uid
    ) THEN
        RETURN v_active;
    END IF;

    SELECT v.id INTO v_resolved
    FROM public.venue_profiles v
    WHERE v.owner_user_id = v_uid
    ORDER BY
        CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END,
        v.created_at
    LIMIT 1;

    IF v_resolved IS NULL THEN
        RAISE EXCEPTION 'No venue profile';
    END IF;

    UPDATE public.profiles
    SET active_venue_id = v_resolved, updated_at = now()
    WHERE id = v_uid AND active_venue_id IS DISTINCT FROM v_resolved;

    RETURN v_resolved;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_active_venue_id(UUID) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000009_admin_invite_codes_private.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Invite codes are admin-managed secrets: hide from app users, expose stats to admins only.

DROP POLICY IF EXISTS referral_read ON public.referral_codes;

-- Admin-only listing and management RPCs
CREATE OR REPLACE FUNCTION public.admin_list_invite_codes()
RETURNS TABLE (
    id UUID,
    code TEXT,
    owner_type TEXT,
    uses_count INTEGER,
    max_uses INTEGER,
    invite_email TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    RETURN QUERY
    SELECT
        rc.id,
        rc.code,
        rc.owner_type,
        rc.uses_count,
        rc.max_uses,
        rc.invite_email,
        rc.created_at
    FROM public.referral_codes rc
    ORDER BY rc.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_invite_codes() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_create_invite_code(
    p_code TEXT DEFAULT NULL,
    p_owner_type TEXT DEFAULT 'creator',
    p_max_uses INTEGER DEFAULT 1,
    p_invite_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_email TEXT;
    v_max INTEGER;
    v_type TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_code := upper(coalesce(nullif(trim(p_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8)));
    v_type := lower(coalesce(nullif(trim(p_owner_type), ''), 'creator'));
    IF v_type NOT IN ('creator', 'venue') THEN
        RAISE EXCEPTION 'owner_type must be creator or venue';
    END IF;

    v_max := greatest(1, coalesce(p_max_uses, 1));
    v_email := nullif(lower(trim(p_invite_email)), '');

    INSERT INTO public.referral_codes (code, owner_type, max_uses, invite_email)
    VALUES (v_code, v_type, v_max, v_email)
    ON CONFLICT (code) DO UPDATE
    SET max_uses = EXCLUDED.max_uses,
        invite_email = coalesce(EXCLUDED.invite_email, public.referral_codes.invite_email),
        owner_type = EXCLUDED.owner_type;

    RETURN jsonb_build_object(
        'code', v_code,
        'owner_type', v_type,
        'max_uses', v_max,
        'uses_count', (SELECT uses_count FROM public.referral_codes WHERE code = v_code)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_invite_code(TEXT, TEXT, INTEGER, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_update_invite_code(
    p_code TEXT,
    p_max_uses INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_max INTEGER;
    v_row public.referral_codes%ROWTYPE;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_code := upper(trim(p_code));
    IF v_code = '' THEN
        RAISE EXCEPTION 'Invite code required';
    END IF;

    v_max := greatest(1, coalesce(p_max_uses, 1));

    UPDATE public.referral_codes
    SET max_uses = v_max
    WHERE upper(code) = v_code
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invite code not found';
    END IF;

    RETURN jsonb_build_object(
        'code', v_row.code,
        'max_uses', v_row.max_uses,
        'uses_count', v_row.uses_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_invite_code(TEXT, INTEGER) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000010_member_social_discovery.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Member discovery: search approved creators and activity feed from people you follow.

CREATE OR REPLACE FUNCTION public.search_members(
    p_query TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    creator_id UUID,
    user_id UUID,
    full_name TEXT,
    instagram_handle TEXT,
    tiktok_handle TEXT,
    city TEXT,
    score NUMERIC,
    followers BIGINT,
    is_following BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_query TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_query := lower(trim(coalesce(p_query, '')));

    RETURN QUERY
    SELECT
        cp.id,
        cp.user_id,
        cp.full_name,
        cp.instagram_handle,
        cp.tiktok_handle,
        cp.city,
        cp.score,
        (SELECT count(*) FROM public.follows f WHERE f.followee_id = cp.user_id),
        EXISTS (
            SELECT 1 FROM public.follows f
            WHERE f.follower_id = auth.uid() AND f.followee_id = cp.user_id
        )
    FROM public.creator_profiles cp
    JOIN public.profiles p ON p.id = cp.user_id
    WHERE cp.status = 'approved'
      AND p.status = 'approved'
      AND cp.user_id <> auth.uid()
      AND (
          v_query = ''
          OR lower(coalesce(cp.full_name, '')) LIKE '%' || v_query || '%'
          OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || v_query || '%'
          OR lower(coalesce(cp.tiktok_handle, '')) LIKE '%' || v_query || '%'
          OR lower(coalesce(cp.city, '')) LIKE '%' || v_query || '%'
          OR EXISTS (
              SELECT 1 FROM unnest(coalesce(cp.niches, ARRAY[]::TEXT[])) n
              WHERE lower(n) LIKE '%' || v_query || '%'
          )
      )
    ORDER BY cp.score DESC NULLS LAST, cp.audience_count DESC NULLS LAST
    LIMIT greatest(1, least(coalesce(p_limit, 30), 50));
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_members(TEXT, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit INTEGER DEFAULT 40)
RETURNS TABLE (
    activity_id UUID,
    actor_user_id UUID,
    actor_creator_id UUID,
    actor_name TEXT,
    action_type TEXT,
    title TEXT,
    subtitle TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            b.id AS activity_id,
            cp.user_id AS actor_user_id,
            cp.id AS actor_creator_id,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'checked_in'::TEXT AS action_type,
            coalesce(o.title, v.venue_name, 'Collaboration') AS title,
            coalesce(v.area, v.venue_name, '') AS subtitle,
            coalesce(b.updated_at, b.created_at) AS created_at
        FROM public.bookings b
        JOIN public.creator_profiles cp ON cp.id = b.creator_id
        JOIN public.offers o ON o.id = b.offer_id
        JOIN public.venue_profiles v ON v.id = o.venue_id
        JOIN public.follows f ON f.followee_id = cp.user_id AND f.follower_id = auth.uid()
        WHERE b.stage IN ('checked_in', 'proof_due', 'completed')

        UNION ALL

        SELECT
            cs.id AS activity_id,
            cs.user_id AS actor_user_id,
            cp.id AS actor_creator_id,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'showcase_added'::TEXT AS action_type,
            CASE
                WHEN cs.caption <> '' THEN cs.caption
                WHEN cs.external_url <> '' THEN 'New showcase post'
                ELSE 'New showcase photo'
            END AS title,
            coalesce(cs.external_url, cs.media_url, '') AS subtitle,
            cs.created_at
        FROM public.creator_showcase cs
        JOIN public.creator_profiles cp ON cp.user_id = cs.user_id
        JOIN public.follows f ON f.followee_id = cs.user_id AND f.follower_id = auth.uid()
    ) activity
    ORDER BY activity.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_following_activity(INTEGER) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000011_social_complete.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Full social layer: direct messages, profile comments, venue discovery.

-- ---------------------------------------------------------------------------
-- 1. Direct messaging (any approved member ↔ member)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.direct_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_low UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    user_high UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT direct_threads_ordered CHECK (user_low < user_high),
    CONSTRAINT direct_threads_unique UNIQUE (user_low, user_high)
);

CREATE INDEX IF NOT EXISTS idx_direct_threads_user_low ON public.direct_threads (user_low);
CREATE INDEX IF NOT EXISTS idx_direct_threads_user_high ON public.direct_threads (user_high);

CREATE TABLE IF NOT EXISTS public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES public.direct_threads (id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT direct_messages_body_not_empty CHECK (length(trim(body)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_direct_messages_thread
    ON public.direct_messages (thread_id, created_at ASC);

ALTER TABLE public.direct_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS direct_threads_select ON public.direct_threads;
CREATE POLICY direct_threads_select ON public.direct_threads
    FOR SELECT USING (user_low = auth.uid() OR user_high = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS direct_messages_select ON public.direct_messages;
CREATE POLICY direct_messages_select ON public.direct_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.direct_threads t
            WHERE t.id = direct_messages.thread_id
              AND (t.user_low = auth.uid() OR t.user_high = auth.uid() OR public.is_admin())
        )
    );

DROP POLICY IF EXISTS direct_messages_insert ON public.direct_messages;
CREATE POLICY direct_messages_insert ON public.direct_messages
    FOR INSERT WITH CHECK (
        sender_user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.direct_threads t
            WHERE t.id = thread_id
              AND (t.user_low = auth.uid() OR t.user_high = auth.uid())
        )
    );

GRANT SELECT ON public.direct_threads TO authenticated;
GRANT SELECT, INSERT ON public.direct_messages TO authenticated;

CREATE OR REPLACE FUNCTION public.ensure_direct_thread(p_target UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := auth.uid();
    v_low UUID;
    v_high UUID;
    v_thread_id UUID;
BEGIN
    IF v_me IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF p_target IS NULL OR p_target = v_me THEN
        RAISE EXCEPTION 'Invalid recipient';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = p_target AND p.status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Recipient not available';
    END IF;

    v_low := LEAST(v_me, p_target);
    v_high := GREATEST(v_me, p_target);

    SELECT id INTO v_thread_id
    FROM public.direct_threads
    WHERE user_low = v_low AND user_high = v_high;

    IF FOUND THEN
        RETURN v_thread_id;
    END IF;

    INSERT INTO public.direct_threads (user_low, user_high)
    VALUES (v_low, v_high)
    RETURNING id INTO v_thread_id;

    RETURN v_thread_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_direct_thread(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_direct_threads()
RETURNS TABLE (
    id UUID,
    peer_user_id UUID,
    peer_name TEXT,
    peer_handle TEXT,
    last_message TEXT,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := auth.uid();
BEGIN
    IF v_me IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        t.id,
        CASE WHEN t.user_low = v_me THEN t.user_high ELSE t.user_low END AS peer_user_id,
        coalesce(cp.full_name, vp.venue_name, 'Member') AS peer_name,
        coalesce(cp.instagram_handle, vp.venue_name, '') AS peer_handle,
        (
            SELECT m.body FROM public.direct_messages m
            WHERE m.thread_id = t.id
            ORDER BY m.created_at DESC
            LIMIT 1
        ),
        (
            SELECT m.created_at FROM public.direct_messages m
            WHERE m.thread_id = t.id
            ORDER BY m.created_at DESC
            LIMIT 1
        ),
        t.created_at
    FROM public.direct_threads t
    LEFT JOIN public.creator_profiles cp ON cp.user_id = CASE WHEN t.user_low = v_me THEN t.user_high ELSE t.user_low END
    LEFT JOIN public.venue_profiles vp ON vp.owner_user_id = CASE WHEN t.user_low = v_me THEN t.user_high ELSE t.user_low END
        AND cp.id IS NULL
    WHERE t.user_low = v_me OR t.user_high = v_me
    ORDER BY coalesce(
        (SELECT max(m.created_at) FROM public.direct_messages m WHERE m.thread_id = t.id),
        t.created_at
    ) DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_direct_threads() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_direct_messages(p_thread_id UUID)
RETURNS SETOF public.direct_messages
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT m.*
    FROM public.direct_messages m
    JOIN public.direct_threads t ON t.id = m.thread_id
    WHERE m.thread_id = p_thread_id
      AND (t.user_low = auth.uid() OR t.user_high = auth.uid() OR public.is_admin())
    ORDER BY m.created_at ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_direct_messages(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.send_direct_message(p_thread_id UUID, p_body TEXT)
RETURNS public.direct_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_body TEXT := trim(p_body);
    v_row public.direct_messages;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_body = '' THEN
        RAISE EXCEPTION 'Message required';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.direct_threads t
        WHERE t.id = p_thread_id
          AND (t.user_low = auth.uid() OR t.user_high = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Thread not found';
    END IF;

    INSERT INTO public.direct_messages (thread_id, sender_user_id, body)
    VALUES (p_thread_id, auth.uid(), v_body)
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_direct_message(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Profile comments (public notes on a member profile)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    showcase_id UUID REFERENCES public.creator_showcase (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT profile_comments_body_not_empty CHECK (length(trim(body)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_profile_comments_target
    ON public.profile_comments (target_user_id, created_at DESC);

ALTER TABLE public.profile_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_comments_select ON public.profile_comments;
CREATE POLICY profile_comments_select ON public.profile_comments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS profile_comments_insert ON public.profile_comments;
CREATE POLICY profile_comments_insert ON public.profile_comments
    FOR INSERT WITH CHECK (
        author_user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = target_user_id AND p.status = 'approved'
        )
    );

GRANT SELECT, INSERT ON public.profile_comments TO authenticated;

CREATE OR REPLACE FUNCTION public.list_profile_comments(
    p_target_user_id UUID,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    id UUID,
    author_user_id UUID,
    author_name TEXT,
    body TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.author_user_id,
        coalesce(cp.full_name, cp.instagram_handle, 'Member') AS author_name,
        c.body,
        c.created_at
    FROM public.profile_comments c
    LEFT JOIN public.creator_profiles cp ON cp.user_id = c.author_user_id
    WHERE c.target_user_id = p_target_user_id
    ORDER BY c.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 30), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_profile_comments(UUID, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.add_profile_comment(
    p_target_user_id UUID,
    p_body TEXT,
    p_showcase_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_body TEXT := trim(p_body);
    v_row public.profile_comments;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_body = '' THEN
        RAISE EXCEPTION 'Comment required';
    END IF;
    IF p_target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot comment on your own profile';
    END IF;

    INSERT INTO public.profile_comments (target_user_id, author_user_id, body, showcase_id)
    VALUES (p_target_user_id, auth.uid(), v_body, p_showcase_id)
    RETURNING * INTO v_row;

    RETURN jsonb_build_object('id', v_row.id, 'created_at', v_row.created_at);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_profile_comment(UUID, TEXT, UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Venue public profile
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_venue_public_profile(p_venue_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue public.venue_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_offers JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_venue FROM public.venue_profiles WHERE id = p_venue_id;
    IF NOT FOUND OR v_venue.status <> 'approved' THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = v_venue.owner_user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = v_venue.owner_user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = auth.uid() AND followee_id = v_venue.owner_user_id
    ) INTO v_is_following;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', o.id,
        'title', o.title,
        'area', v_venue.area,
        'category', o.category::TEXT,
        'remaining_slots', o.remaining_slots
    ) ORDER BY o.created_at DESC), '[]'::JSONB)
    INTO v_offers
    FROM public.offers o
    WHERE o.venue_id = v_venue.id
      AND o.status = 'live'
    LIMIT 12;

    RETURN jsonb_build_object(
        'venue_id', v_venue.id,
        'owner_user_id', v_venue.owner_user_id,
        'venue_name', v_venue.venue_name,
        'area', v_venue.area,
        'category', v_venue.category::TEXT,
        'address', v_venue.address,
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'live_offers', v_offers
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_venue_public_profile(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Expand member search (creators + venues) and following activity
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.search_members(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.search_members(
    p_query TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    profile_ref_id UUID,
    user_id UUID,
    member_type TEXT,
    full_name TEXT,
    instagram_handle TEXT,
    tiktok_handle TEXT,
    city TEXT,
    score NUMERIC,
    followers BIGINT,
    is_following BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_query TEXT;
    v_limit INTEGER;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_query := lower(trim(coalesce(p_query, '')));
    v_limit := greatest(1, least(coalesce(p_limit, 30), 50));

    RETURN QUERY
    (
        SELECT
            cp.id,
            cp.user_id,
            'creator'::TEXT,
            cp.full_name,
            cp.instagram_handle,
            cp.tiktok_handle,
            cp.city,
            cp.score,
            (SELECT count(*) FROM public.follows f WHERE f.followee_id = cp.user_id),
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = cp.user_id
            )
        FROM public.creator_profiles cp
        JOIN public.profiles p ON p.id = cp.user_id
        WHERE cp.status = 'approved'
          AND p.status = 'approved'
          AND cp.user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(coalesce(cp.full_name, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.tiktok_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.city, '')) LIKE '%' || v_query || '%'
              OR EXISTS (
                  SELECT 1 FROM unnest(coalesce(cp.niches, ARRAY[]::TEXT[])) n
                  WHERE lower(n) LIKE '%' || v_query || '%'
              )
          )
    )
    UNION ALL
    (
        SELECT
            vp.id,
            vp.owner_user_id,
            'venue'::TEXT,
            vp.venue_name,
            vp.venue_name,
            ''::TEXT,
            vp.area,
            0::NUMERIC,
            (SELECT count(*) FROM public.follows f WHERE f.followee_id = vp.owner_user_id),
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = vp.owner_user_id
            )
        FROM public.venue_profiles vp
        JOIN public.profiles p ON p.id = vp.owner_user_id
        WHERE vp.status = 'approved'
          AND p.status = 'approved'
          AND vp.owner_user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(vp.venue_name) LIKE '%' || v_query || '%'
              OR lower(vp.area) LIKE '%' || v_query || '%'
              OR lower(vp.category::TEXT) LIKE '%' || v_query || '%'
          )
    )
    ORDER BY score DESC NULLS LAST, followers DESC
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_members(TEXT, INTEGER) TO authenticated;

DROP FUNCTION IF EXISTS public.get_following_activity(INTEGER);

CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit INTEGER DEFAULT 40)
RETURNS TABLE (
    activity_id UUID,
    actor_user_id UUID,
    actor_creator_id UUID,
    actor_venue_id UUID,
    actor_name TEXT,
    action_type TEXT,
    title TEXT,
    subtitle TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            b.id,
            cp.user_id,
            cp.id,
            NULL::UUID,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator'),
            'checked_in'::TEXT,
            coalesce(o.title, v.venue_name, 'Collaboration'),
            coalesce(v.area, ''),
            coalesce(b.updated_at, b.created_at)
        FROM public.bookings b
        JOIN public.creator_profiles cp ON cp.id = b.creator_id
        JOIN public.offers o ON o.id = b.offer_id
        JOIN public.venue_profiles v ON v.id = o.venue_id
        JOIN public.follows f ON f.followee_id = cp.user_id AND f.follower_id = auth.uid()
        WHERE b.stage IN ('checked_in', 'proof_due', 'completed')

        UNION ALL

        SELECT
            cs.id,
            cs.user_id,
            cp.id,
            NULL::UUID,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator'),
            'showcase_added'::TEXT,
            CASE WHEN cs.caption <> '' THEN cs.caption WHEN cs.external_url <> '' THEN 'New showcase post' ELSE 'New showcase photo' END,
            coalesce(cs.external_url, cs.media_url, ''),
            cs.created_at
        FROM public.creator_showcase cs
        JOIN public.creator_profiles cp ON cp.user_id = cs.user_id
        JOIN public.follows f ON f.followee_id = cs.user_id AND f.follower_id = auth.uid()

        UNION ALL

        SELECT
            o.id,
            vp.owner_user_id,
            NULL::UUID,
            vp.id,
            vp.venue_name,
            'venue_offer'::TEXT,
            o.title,
            coalesce(vp.area, o.category::TEXT),
            o.created_at
        FROM public.offers o
        JOIN public.venue_profiles vp ON vp.id = o.venue_id
        JOIN public.follows f ON f.followee_id = vp.owner_user_id AND f.follower_id = auth.uid()
        WHERE o.status = 'live'
          AND o.created_at > now() - interval '30 days'
    ) activity
    ORDER BY activity.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_following_activity(INTEGER) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000012_social_dm_verification.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Per-user social verification code: user DMs code to @marvisociety from their Instagram account.

ALTER TYPE public.admin_task_type ADD VALUE IF NOT EXISTS 'social_verification';

ALTER TABLE public.creator_profiles
    ADD COLUMN IF NOT EXISTS social_verification_code TEXT,
    ADD COLUMN IF NOT EXISTS social_verification_issued_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS social_verification_instagram_handle TEXT,
    ADD COLUMN IF NOT EXISTS social_verification_tiktok_handle TEXT,
    ADD COLUMN IF NOT EXISTS social_verification_submitted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS social_verification_verified_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS idx_creator_profiles_social_verification_code
    ON public.creator_profiles (social_verification_code)
    WHERE social_verification_code IS NOT NULL;

CREATE OR REPLACE FUNCTION public.normalize_social_handle(p_handle TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT lower(trim(regexp_replace(coalesce(p_handle, ''), '^@+', '')));
$$;

CREATE OR REPLACE FUNCTION public._new_social_verification_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_code TEXT;
BEGIN
    LOOP
        v_code := 'MARVI-' || upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 6));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.creator_profiles WHERE social_verification_code = v_code
        );
    END LOOP;
    RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_social_verification_code()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.creator_profiles%ROWTYPE;
    v_ig TEXT;
    v_tt TEXT;
    v_status TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row
    FROM public.creator_profiles
    WHERE user_id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    v_ig := public.normalize_social_handle(v_row.instagram_handle);
    v_tt := public.normalize_social_handle(v_row.tiktok_handle);

    IF v_ig = '' OR v_tt = '' THEN
        RETURN jsonb_build_object(
            'status', 'needs_handles',
            'instagram_handle', v_row.instagram_handle,
            'tiktok_handle', coalesce(v_row.tiktok_handle, ''),
            'tiktok_handle_required', true,
            'marvi_instagram', 'marvisociety'
        );
    END IF;

    IF v_row.social_verification_verified_at IS NOT NULL
        AND public.normalize_social_handle(v_row.social_verification_instagram_handle) = v_ig
        AND public.normalize_social_handle(v_row.social_verification_tiktok_handle) = v_tt THEN
        v_status := 'verified';
    ELSIF v_row.social_verification_code IS NULL
        OR public.normalize_social_handle(v_row.social_verification_instagram_handle) IS DISTINCT FROM v_ig
        OR public.normalize_social_handle(v_row.social_verification_tiktok_handle) IS DISTINCT FROM v_tt THEN
        UPDATE public.creator_profiles
        SET social_verification_code = public._new_social_verification_code(),
            social_verification_issued_at = now(),
            social_verification_instagram_handle = v_ig,
            social_verification_tiktok_handle = v_tt,
            social_verification_submitted_at = NULL,
            social_verification_verified_at = NULL,
            updated_at = now()
        WHERE user_id = v_uid
        RETURNING * INTO v_row;
        v_status := 'pending';
    ELSIF v_row.social_verification_submitted_at IS NOT NULL THEN
        v_status := 'submitted';
    ELSE
        v_status := 'pending';
    END IF;

    RETURN jsonb_build_object(
        'status', v_status,
        'code', v_row.social_verification_code,
        'instagram_handle', v_row.instagram_handle,
        'tiktok_handle', coalesce(v_row.tiktok_handle, ''),
        'marvi_instagram', 'marvisociety',
        'issued_at', v_row.social_verification_issued_at,
        'submitted_at', v_row.social_verification_submitted_at,
        'verified_at', v_row.social_verification_verified_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_social_verification_code() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_social_verification_dm()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.creator_profiles%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row
    FROM public.creator_profiles
    WHERE user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    IF v_row.social_verification_code IS NULL
        OR public.normalize_social_handle(v_row.instagram_handle) = ''
        OR public.normalize_social_handle(v_row.tiktok_handle) = '' THEN
        RAISE EXCEPTION 'Save Instagram and TikTok handles first';
    END IF;

    IF v_row.social_verification_verified_at IS NOT NULL THEN
        RETURN public.ensure_social_verification_code();
    END IF;

    UPDATE public.creator_profiles
    SET social_verification_submitted_at = now(),
        updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

    IF NOT EXISTS (
        SELECT 1 FROM public.admin_tasks
        WHERE type = 'social_verification'
          AND subject_id = v_uid
          AND status = 'open'
    ) THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
        VALUES (
            'social_verification',
            v_uid,
            'Instagram DM verification',
            '@' || v_row.social_verification_instagram_handle
                || ' · TikTok @' || v_row.social_verification_tiktok_handle
                || ' · code ' || v_row.social_verification_code,
            'High'
        );
    END IF;

    RETURN public.ensure_social_verification_code();
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_social_verification_dm() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_verify_social_dm(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.creator_profiles%ROWTYPE;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    UPDATE public.creator_profiles
    SET social_verification_verified_at = now(),
        social_verification_instagram_handle = public.normalize_social_handle(instagram_handle),
        social_verification_tiktok_handle = public.normalize_social_handle(tiktok_handle),
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    UPDATE public.admin_tasks
    SET status = 'approved',
        resolved_at = now()
    WHERE subject_id = p_user_id
      AND type = 'social_verification'
      AND status = 'open';

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'verified_at', v_row.social_verification_verified_at,
        'instagram_handle', v_row.instagram_handle,
        'tiktok_handle', v_row.tiktok_handle
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_verify_social_dm(UUID) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000013_resolve_social_verification_task.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Wire social_verification admin tasks into resolve_admin_task approve/reject flow.

CREATE OR REPLACE FUNCTION public.resolve_admin_task(p_task_id UUID, p_action TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task public.admin_tasks%ROWTYPE;
    v_approve BOOLEAN := lower(trim(p_action)) IN ('approve', 'approved');
    v_email TEXT;
    v_locale TEXT;
    v_name TEXT;
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
                SELECT p.email, p.preferred_locale, cp.full_name
                INTO v_email, v_locale, v_name
                FROM public.profiles p
                LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
                WHERE p.id = v_task.subject_id;

                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Üyeliğiniz onaylandı' ELSE 'Membership approved' END,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr'
                        THEN 'Marvi Society başvurunuz onaylandı. Keşfet sekmesinden canlı etkinliklere göz atın.'
                        ELSE 'Your Marvi Society creator application was approved. Explore live events now.'
                    END,
                    'membership',
                    'checkmark.seal.fill',
                    'emerald',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );

                PERFORM public.queue_transactional_email(
                    v_task.subject_id,
                    v_email,
                    'membership_approved',
                    coalesce(v_locale, 'en'),
                    jsonb_build_object(
                        'name', coalesce(nullif(v_name, ''), 'Creator'),
                        'site_url', 'https://marvisociety.com',
                        'app_url', 'https://marvisociety.com/creators'
                    )
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

        WHEN 'social_verification' THEN
            IF v_approve THEN
                UPDATE public.creator_profiles
                SET social_verification_verified_at = now(),
                    social_verification_instagram_handle = public.normalize_social_handle(instagram_handle),
                    social_verification_tiktok_handle = public.normalize_social_handle(tiktok_handle),
                    updated_at = now()
                WHERE user_id = v_task.subject_id;

                SELECT p.email, p.preferred_locale, cp.full_name
                INTO v_email, v_locale, v_name
                FROM public.profiles p
                LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
                WHERE p.id = v_task.subject_id;

                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Sosyal hesap doğrulandı' ELSE 'Social accounts verified' END,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr'
                        THEN 'Instagram DM kodunuz onaylandı. Artık etkinlik tekliflerini kabul edebilirsiniz.'
                        ELSE 'Your Instagram DM code was confirmed. You can now accept event offers.'
                    END,
                    'membership',
                    'checkmark.seal.fill',
                    'emerald',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );
            ELSE
                UPDATE public.creator_profiles
                SET social_verification_submitted_at = NULL,
                    updated_at = now()
                WHERE user_id = v_task.subject_id;
            END IF;
    END CASE;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000014_accept_offer_profile_gates.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Enforce invite redemption and social DM verification before accepting offers (non-admin creators).

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
    v_profile public.profiles%ROWTYPE;
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
        SELECT * INTO v_profile FROM public.profiles WHERE id = v_creator_user;
        IF v_profile.referral_code IS NULL OR trim(v_profile.referral_code) = '' THEN
            RAISE EXCEPTION 'Invite code required before accepting offers';
        END IF;

        SELECT * INTO v_creator FROM public.creator_profiles WHERE id = v_creator_id;
        IF coalesce(trim(v_creator.instagram_handle), '') = ''
            OR coalesce(trim(v_creator.tiktok_handle), '') = '' THEN
            RAISE EXCEPTION 'Instagram and TikTok handles required';
        END IF;

        IF v_creator.social_verification_verified_at IS NULL THEN
            RAISE EXCEPTION 'Social verification required before accepting offers';
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000015_invite_email_and_redeem_fix.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Fix invite redeem normalization + auto-queue invite email when creating a code with recipient email.
-- Also harden validate/redeem against unicode dashes and casing.

CREATE OR REPLACE FUNCTION public.normalize_invite_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT upper(
        trim(
            replace(
                replace(
                    replace(coalesce(p_code, ''), E'\u2013', '-'), -- en-dash
                    E'\u2014', '-' -- em-dash
                ),
                E'\u2212', '-' -- minus
            )
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
BEGIN
    v_code := public.normalize_invite_code(p_code);
    IF v_code = '' THEN
        RETURN FALSE;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
    v_user_email TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_code := public.normalize_invite_code(p_code);
    IF v_code = '' THEN
        RAISE EXCEPTION 'Invite code required';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND referral_code IS NOT NULL
    ) THEN
        RETURN;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid invite code';
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RAISE EXCEPTION 'Invite code has reached its limit';
    END IF;

    -- Prefer auth email; fall back to profiles.email for binding checks.
    SELECT lower(trim(coalesce(au.email, p.email))) INTO v_user_email
    FROM auth.users au
    LEFT JOIN public.profiles p ON p.id = au.id
    WHERE au.id = auth.uid();

    IF v_row.invite_email IS NOT NULL AND trim(v_row.invite_email) <> '' THEN
        IF v_user_email IS NULL OR v_user_email <> lower(trim(v_row.invite_email)) THEN
            RAISE EXCEPTION 'This invite was sent to a different email address';
        END IF;
    END IF;

    UPDATE public.referral_codes
    SET uses_count = uses_count + 1
    WHERE id = v_row.id;

    UPDATE public.profiles
    SET referral_code = v_code
    WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT) TO authenticated;

-- Creating an invite code with a recipient email also queues the invite email.
CREATE OR REPLACE FUNCTION public.admin_create_invite_code(
    p_code TEXT DEFAULT NULL,
    p_owner_type TEXT DEFAULT 'creator',
    p_max_uses INTEGER DEFAULT 1,
    p_invite_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_email TEXT;
    v_max INTEGER;
    v_type TEXT;
    v_uses INTEGER;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_code := public.normalize_invite_code(
        coalesce(nullif(trim(p_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8))
    );
    v_type := lower(coalesce(nullif(trim(p_owner_type), ''), 'creator'));
    IF v_type NOT IN ('creator', 'venue') THEN
        RAISE EXCEPTION 'owner_type must be creator or venue';
    END IF;

    v_max := greatest(1, coalesce(p_max_uses, 1));
    v_email := nullif(lower(trim(p_invite_email)), '');

    INSERT INTO public.referral_codes (code, owner_type, max_uses, invite_email)
    VALUES (v_code, v_type, v_max, v_email)
    ON CONFLICT (code) DO UPDATE
    SET max_uses = EXCLUDED.max_uses,
        invite_email = coalesce(EXCLUDED.invite_email, public.referral_codes.invite_email),
        owner_type = EXCLUDED.owner_type;

    SELECT uses_count INTO v_uses FROM public.referral_codes WHERE code = v_code;

    IF v_email IS NOT NULL THEN
        PERFORM public.queue_transactional_email(
            NULL,
            v_email,
            'invite_code',
            'tr',
            jsonb_build_object(
                'email', v_email,
                'invite_code', v_code,
                'site_url', 'https://marvisociety.com',
                'deep_link', 'marvisociety://invite?code=' || v_code
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'code', v_code,
        'owner_type', v_type,
        'max_uses', v_max,
        'uses_count', coalesce(v_uses, 0),
        'invite_email', v_email,
        'email_queued', (v_email IS NOT NULL)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_invite_code(TEXT, TEXT, INTEGER, TEXT) TO authenticated;

-- Admin send invite: normalize code + Turkish email by default for Istanbul product.
CREATE OR REPLACE FUNCTION public.admin_send_invite(
    p_email TEXT,
    p_invite_code TEXT DEFAULT NULL,
    p_max_uses INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_email TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_email := lower(trim(p_email));
    IF v_email = '' OR position('@' IN v_email) = 0 THEN
        RAISE EXCEPTION 'Valid email required';
    END IF;

    v_code := public.normalize_invite_code(
        coalesce(nullif(trim(p_invite_code), ''), 'INVITE-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8))
    );

    INSERT INTO public.referral_codes (code, owner_type, max_uses, invite_email)
    VALUES (v_code, 'creator', greatest(1, coalesce(p_max_uses, 1)), v_email)
    ON CONFLICT (code) DO UPDATE
        SET max_uses = EXCLUDED.max_uses,
            invite_email = EXCLUDED.invite_email;

    PERFORM public.queue_transactional_email(
        NULL,
        v_email,
        'invite_code',
        'tr',
        jsonb_build_object(
            'email', v_email,
            'invite_code', v_code,
            'site_url', 'https://marvisociety.com',
            'deep_link', 'marvisociety://invite?code=' || v_code
        )
    );

    RETURN jsonb_build_object('email', v_email, 'invite_code', v_code);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_send_invite(TEXT, TEXT, INTEGER) TO authenticated;

-- When dispatch settings are missing, mark pending rows so admins see the failure instead of silent queue.
CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        v_url := NULL;
        v_key := NULL;
    END;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 OR v_key = 'YOUR_SERVICE_ROLE_KEY' THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured — set marvi.edge_function_url + marvi.service_role_key or Database Webhook'
        WHERE id = NEW.id AND status = 'pending';
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/send-email',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object('outbox_id', NEW.id::TEXT)
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    UPDATE public.email_outbox
    SET error_message = left('Dispatch error: ' || SQLERRM, 500)
    WHERE id = NEW.id AND status = 'pending';
    RETURN NEW;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000016_email_dispatch_settings_table.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Email dispatch config that does not require ALTER DATABASE privileges.

CREATE TABLE IF NOT EXISTS public.marvi_runtime_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.marvi_runtime_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS marvi_runtime_settings_admin ON public.marvi_runtime_settings;
CREATE POLICY marvi_runtime_settings_admin ON public.marvi_runtime_settings
    FOR ALL
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.marvi_runtime_settings TO authenticated;
GRANT ALL ON public.marvi_runtime_settings TO service_role;

CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 OR v_key IN ('', 'YOUR_SERVICE_ROLE_KEY') THEN
        BEGIN
            v_url := current_setting('marvi.edge_function_url', true);
            v_key := current_setting('marvi.service_role_key', true);
        EXCEPTION WHEN OTHERS THEN
            v_url := NULL;
            v_key := NULL;
        END;
    END IF;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 OR v_key IN ('', 'YOUR_SERVICE_ROLE_KEY') THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured — set marvi_runtime_settings edge_function_url + service_role_key, or Database Webhook'
        WHERE id = NEW.id AND status = 'pending';
        RETURN NEW;
    END IF;

    BEGIN
        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            body := jsonb_build_object('outbox_id', NEW.id::TEXT)
        );
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.email_outbox
        SET error_message = left('Dispatch error: ' || SQLERRM, 500)
        WHERE id = NEW.id AND status = 'pending';
    END;

    RETURN NEW;
END;
$$;

-- Seed URL (service role key must be set separately with real secret).
INSERT INTO public.marvi_runtime_settings (key, value)
VALUES ('edge_function_url', 'https://gaswjuvyzliislqrljof.supabase.co/functions/v1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000017_enable_pg_net_dispatch.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Enable pg_net for outbox dispatch + lock down runtime settings (no client-readable secrets).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Ensure search_path can resolve net.* helpers used by pg_net.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'net') THEN
        -- Older/newer pg_net variants may install functions under extensions only.
        NULL;
    END IF;
END $$;

REVOKE ALL ON public.marvi_runtime_settings FROM authenticated;
REVOKE ALL ON public.marvi_runtime_settings FROM PUBLIC;
DROP POLICY IF EXISTS marvi_runtime_settings_admin ON public.marvi_runtime_settings;
-- No policies for authenticated: only service_role / SECURITY DEFINER can read.

CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    v_endpoint TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';

    IF v_url IS NULL OR v_key IS NULL OR length(coalesce(v_url, '')) < 10 OR coalesce(v_key, '') IN ('', 'YOUR_SERVICE_ROLE_KEY') THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured — set marvi_runtime_settings or Database Webhook to send-email'
        WHERE id = NEW.id AND status = 'pending';
        RETURN NEW;
    END IF;

    v_endpoint := rtrim(v_url, '/') || '/send-email';

    BEGIN
        -- Prefer net.http_post when schema exists; otherwise extensions.http_post.
        IF to_regprocedure('net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer)') IS NOT NULL THEN
            PERFORM net.http_post(
                url := v_endpoint,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_key
                ),
                body := jsonb_build_object('outbox_id', NEW.id::TEXT)
            );
        ELSIF to_regprocedure('extensions.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer)') IS NOT NULL THEN
            PERFORM extensions.http_post(
                url := v_endpoint,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_key
                ),
                body := jsonb_build_object('outbox_id', NEW.id::TEXT)
            );
        ELSE
            UPDATE public.email_outbox
            SET error_message = 'pg_net http_post unavailable — create Database Webhook on email_outbox INSERT'
            WHERE id = NEW.id AND status = 'pending';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.email_outbox
        SET error_message = left('Dispatch error: ' || SQLERRM, 500)
        WHERE id = NEW.id AND status = 'pending';
    END;

    RETURN NEW;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000018_auto_redeem_invite_from_metadata.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Auto-apply invite_code from auth user metadata on signup (Auth invite / magic-link path).

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
    v_is_review BOOLEAN := lower(coalesce(NEW.email, '')) = 'review@marvisociety.com';
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_tiktok := coalesce(NEW.raw_user_meta_data ->> 'tiktok_handle', '');
    v_invite := public.normalize_invite_code(coalesce(NEW.raw_user_meta_data ->> 'invite_code', ''));
    v_locale := public.infer_user_locale(
        NEW.raw_user_meta_data ->> 'locale',
        v_city,
        NULL
    );

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (
        NEW.id,
        NEW.email,
        'creator',
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END,
        v_locale
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, tiktok_handle, city, languages, status)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_tiktok,
        v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END,
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END
    );

    IF NOT v_is_review THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
        VALUES (
            'creator_application',
            NEW.id,
            'New creator application',
            coalesce(nullif(v_handle, ''), NEW.email, 'Unknown'),
            'High'
        );

        PERFORM public.queue_transactional_email(
            NEW.id,
            NEW.email,
            'welcome_application',
            v_locale,
            jsonb_build_object(
                'name', v_name,
                'city', v_city,
                'site_url', 'https://marvisociety.com'
            )
        );
    END IF;

    -- If Auth invite/magic-link carried an invite code, redeem it immediately.
    IF v_invite <> '' THEN
        BEGIN
            UPDATE public.referral_codes
            SET uses_count = uses_count + 1
            WHERE upper(code) = v_invite
              AND (max_uses IS NULL OR uses_count < max_uses)
              AND (
                  invite_email IS NULL
                  OR trim(invite_email) = ''
                  OR lower(trim(invite_email)) = lower(trim(NEW.email))
              );

            IF FOUND THEN
                UPDATE public.profiles
                SET referral_code = v_invite
                WHERE id = NEW.id;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL; -- never block signup on invite auto-apply
        END;
    END IF;

    RETURN NEW;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000019_fix_email_dispatch_http.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Fix email_outbox auto-dispatch (pg_net http_post) after invite Auth fallback.

CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    v_endpoint TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';

    IF v_url IS NULL OR v_key IS NULL OR length(coalesce(v_url, '')) < 10 OR coalesce(v_key, '') IN ('', 'YOUR_SERVICE_ROLE_KEY') THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured — set marvi_runtime_settings or call send-email manually'
        WHERE id = NEW.id AND status = 'pending';
        RETURN NEW;
    END IF;

    v_endpoint := rtrim(v_url, '/') || '/send-email';

    BEGIN
        PERFORM net.http_post(
            url := v_endpoint,
            body := jsonb_build_object('outbox_id', NEW.id::TEXT),
            params := '{}'::jsonb,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            timeout_milliseconds := 5000
        );
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.email_outbox
        SET error_message = left('Dispatch error: ' || SQLERRM, 500)
        WHERE id = NEW.id AND status = 'pending';
    END;

    RETURN NEW;
END;
$$;

-- Helper: flush pending/failed invite emails by invoking send-email for each row.
CREATE OR REPLACE FUNCTION public.admin_flush_pending_emails(p_limit INTEGER DEFAULT 20)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    r RECORD;
    v_count INTEGER := 0;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';
    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE EXCEPTION 'Dispatch settings missing';
    END IF;

    FOR r IN
        SELECT id
        FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
          AND template = 'invite_code'
        ORDER BY created_at ASC
        LIMIT greatest(1, coalesce(p_limit, 20))
    LOOP
        UPDATE public.email_outbox
        SET status = 'pending', error_message = NULL
        WHERE id = r.id;

        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            body := jsonb_build_object('outbox_id', r.id::TEXT),
            params := '{}'::jsonb,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            timeout_milliseconds := 5000
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('queued_dispatches', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_flush_pending_emails(INTEGER) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000020_email_auth_fallback_flush.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Broaden email flush + tolerate sending claim status; keep dispatch locked down.

-- Stuck "sending" rows (crashed edge workers) can be retried.
UPDATE public.email_outbox
SET status = 'pending',
    error_message = NULL
WHERE status = 'sending'
  AND created_at < now() - interval '10 minutes';

CREATE OR REPLACE FUNCTION public.admin_flush_pending_emails(p_limit INTEGER DEFAULT 40)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    r RECORD;
    v_count INTEGER := 0;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';
    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE EXCEPTION 'Dispatch settings missing';
    END IF;

    -- Recover stuck sends
    UPDATE public.email_outbox
    SET status = 'pending', error_message = NULL
    WHERE status = 'sending'
      AND created_at < now() - interval '5 minutes';

    FOR r IN
        SELECT id
        FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
        ORDER BY created_at ASC
        LIMIT greatest(1, coalesce(p_limit, 40))
    LOOP
        UPDATE public.email_outbox
        SET status = 'pending', error_message = NULL
        WHERE id = r.id;

        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            body := jsonb_build_object('outbox_id', r.id::TEXT),
            params := '{}'::jsonb,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            timeout_milliseconds := 8000
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('queued_dispatches', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_flush_pending_emails(INTEGER) TO authenticated;

-- Service-role friendly flush via PostgREST (no is_admin gate).
CREATE OR REPLACE FUNCTION public.service_flush_pending_emails(p_limit INTEGER DEFAULT 40)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    r RECORD;
    v_count INTEGER := 0;
BEGIN
    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';
    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE EXCEPTION 'Dispatch settings missing';
    END IF;

    UPDATE public.email_outbox
    SET status = 'pending', error_message = NULL
    WHERE status = 'sending'
      AND created_at < now() - interval '5 minutes';

    FOR r IN
        SELECT id
        FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
        ORDER BY created_at ASC
        LIMIT greatest(1, coalesce(p_limit, 40))
    LOOP
        UPDATE public.email_outbox
        SET status = 'pending', error_message = NULL
        WHERE id = r.id;

        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            body := jsonb_build_object('outbox_id', r.id::TEXT),
            params := '{}'::jsonb,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            timeout_milliseconds := 8000
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('queued_dispatches', v_count);
END;
$$;

REVOKE ALL ON FUNCTION public.service_flush_pending_emails(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.service_flush_pending_emails(INTEGER) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.service_flush_pending_emails(INTEGER) TO service_role;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000021_soften_social_handle_requirement.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Soften social gates: require Instagram OR TikTok (at least one), not both.

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
    v_profile public.profiles%ROWTYPE;
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
        SELECT * INTO v_profile FROM public.profiles WHERE id = v_creator_user;
        IF v_profile.referral_code IS NULL OR trim(v_profile.referral_code) = '' THEN
            RAISE EXCEPTION 'Invite code required before accepting offers';
        END IF;

        SELECT * INTO v_creator FROM public.creator_profiles WHERE id = v_creator_id;
        IF coalesce(trim(v_creator.instagram_handle), '') = ''
            AND coalesce(trim(v_creator.tiktok_handle), '') = '' THEN
            RAISE EXCEPTION 'Instagram or TikTok handle required';
        END IF;

        IF v_creator.social_verification_verified_at IS NULL THEN
            RAISE EXCEPTION 'Social verification required before accepting offers';
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

CREATE OR REPLACE FUNCTION public.submit_social_verification_dm()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.creator_profiles%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row
    FROM public.creator_profiles
    WHERE user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    IF v_row.social_verification_code IS NULL
        OR (
            public.normalize_social_handle(v_row.instagram_handle) = ''
            AND public.normalize_social_handle(v_row.tiktok_handle) = ''
        ) THEN
        RAISE EXCEPTION 'Save Instagram or TikTok handle first';
    END IF;

    IF v_row.social_verification_verified_at IS NOT NULL THEN
        RETURN public.ensure_social_verification_code();
    END IF;

    UPDATE public.creator_profiles
    SET social_verification_submitted_at = now(),
        updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

    IF NOT EXISTS (
        SELECT 1 FROM public.admin_tasks
        WHERE type = 'social_verification'
          AND subject_id = v_uid
          AND status = 'open'
    ) THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
        VALUES (
            'social_verification',
            v_uid,
            'Instagram DM verification',
            '@' || coalesce(nullif(public.normalize_social_handle(v_row.instagram_handle), ''), '—')
                || ' · TikTok @' || coalesce(nullif(public.normalize_social_handle(v_row.tiktok_handle), ''), '—')
                || ' · code ' || v_row.social_verification_code,
            'High'
        );
    END IF;

    RETURN public.ensure_social_verification_code();
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000022_remove_invite_gate_from_accept.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Remove invite-code requirement from accept_offer.
-- Membership no longer depends on redeeming a referral/invite code.

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

        IF v_creator.social_verification_verified_at IS NULL THEN
            RAISE EXCEPTION 'Social verification required before accepting offers';
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000023_fix_social_union_order_by.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: invalid UNION/INTERSECT/EXCEPT ORDER BY + activity.created_at missing
-- Root cause: UNION branches lacked explicit output aliases; ORDER BY referenced
-- names that were not real output columns (e.g. followers, activity.created_at).

CREATE OR REPLACE FUNCTION public.search_members(
    p_query TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    profile_ref_id UUID,
    user_id UUID,
    member_type TEXT,
    full_name TEXT,
    instagram_handle TEXT,
    tiktok_handle TEXT,
    city TEXT,
    score NUMERIC,
    followers BIGINT,
    is_following BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_query TEXT;
    v_limit INTEGER;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_query := lower(trim(coalesce(p_query, '')));
    v_limit := greatest(1, least(coalesce(p_limit, 30), 50));

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            cp.id AS profile_ref_id,
            cp.user_id AS user_id,
            'creator'::TEXT AS member_type,
            cp.full_name AS full_name,
            cp.instagram_handle AS instagram_handle,
            cp.tiktok_handle AS tiktok_handle,
            cp.city AS city,
            cp.score AS score,
            (SELECT count(*)::BIGINT FROM public.follows f WHERE f.followee_id = cp.user_id) AS followers,
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = cp.user_id
            ) AS is_following
        FROM public.creator_profiles cp
        JOIN public.profiles p ON p.id = cp.user_id
        WHERE cp.status = 'approved'
          AND p.status = 'approved'
          AND cp.user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(coalesce(cp.full_name, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.tiktok_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.city, '')) LIKE '%' || v_query || '%'
              OR EXISTS (
                  SELECT 1 FROM unnest(coalesce(cp.niches, ARRAY[]::TEXT[])) n
                  WHERE lower(n) LIKE '%' || v_query || '%'
              )
          )

        UNION ALL

        SELECT
            vp.id AS profile_ref_id,
            vp.owner_user_id AS user_id,
            'venue'::TEXT AS member_type,
            vp.venue_name AS full_name,
            vp.venue_name AS instagram_handle,
            ''::TEXT AS tiktok_handle,
            vp.area AS city,
            0::NUMERIC AS score,
            (SELECT count(*)::BIGINT FROM public.follows f WHERE f.followee_id = vp.owner_user_id) AS followers,
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = vp.owner_user_id
            ) AS is_following
        FROM public.venue_profiles vp
        JOIN public.profiles p ON p.id = vp.owner_user_id
        WHERE vp.status = 'approved'
          AND p.status = 'approved'
          AND vp.owner_user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(vp.venue_name) LIKE '%' || v_query || '%'
              OR lower(vp.area) LIKE '%' || v_query || '%'
              OR lower(vp.category::TEXT) LIKE '%' || v_query || '%'
          )
    ) AS members
    ORDER BY members.score DESC NULLS LAST, members.followers DESC
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_members(TEXT, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit INTEGER DEFAULT 40)
RETURNS TABLE (
    activity_id UUID,
    actor_user_id UUID,
    actor_creator_id UUID,
    actor_venue_id UUID,
    actor_name TEXT,
    action_type TEXT,
    title TEXT,
    subtitle TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            b.id AS activity_id,
            cp.user_id AS actor_user_id,
            cp.id AS actor_creator_id,
            NULL::UUID AS actor_venue_id,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'checked_in'::TEXT AS action_type,
            coalesce(o.title, v.venue_name, 'Collaboration') AS title,
            coalesce(v.area, '') AS subtitle,
            coalesce(b.updated_at, b.created_at) AS created_at
        FROM public.bookings b
        JOIN public.creator_profiles cp ON cp.id = b.creator_id
        JOIN public.offers o ON o.id = b.offer_id
        JOIN public.venue_profiles v ON v.id = o.venue_id
        JOIN public.follows f ON f.followee_id = cp.user_id AND f.follower_id = auth.uid()
        WHERE b.stage IN ('checked_in', 'proof_due', 'completed')

        UNION ALL

        SELECT
            cs.id AS activity_id,
            cs.user_id AS actor_user_id,
            cp.id AS actor_creator_id,
            NULL::UUID AS actor_venue_id,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator') AS actor_name,
            'showcase_added'::TEXT AS action_type,
            CASE
                WHEN cs.caption <> '' THEN cs.caption
                WHEN cs.external_url <> '' THEN 'New showcase post'
                ELSE 'New showcase photo'
            END AS title,
            coalesce(cs.external_url, cs.media_url, '') AS subtitle,
            cs.created_at AS created_at
        FROM public.creator_showcase cs
        JOIN public.creator_profiles cp ON cp.user_id = cs.user_id
        JOIN public.follows f ON f.followee_id = cs.user_id AND f.follower_id = auth.uid()

        UNION ALL

        SELECT
            o.id AS activity_id,
            vp.owner_user_id AS actor_user_id,
            NULL::UUID AS actor_creator_id,
            vp.id AS actor_venue_id,
            vp.venue_name AS actor_name,
            'venue_offer'::TEXT AS action_type,
            o.title AS title,
            coalesce(vp.area, o.category::TEXT) AS subtitle,
            o.created_at AS created_at
        FROM public.offers o
        JOIN public.venue_profiles vp ON vp.id = o.venue_id
        JOIN public.follows f ON f.followee_id = vp.owner_user_id AND f.follower_id = auth.uid()
        WHERE o.status = 'live'
          AND o.created_at > now() - interval '30 days'
    ) AS activity
    ORDER BY activity.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_following_activity(INTEGER) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000024_soften_social_verify_accept_gate.sql
-- ═══════════════════════════════════════════════════════════════════════════
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000025_public_profile_media_urls.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Expose avatar_url / cover_url on public creator profiles and member search
-- so other members can see uploaded profile media (social loop).

CREATE OR REPLACE FUNCTION public.get_creator_public_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator public.creator_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_reviews JSONB;
    v_collabs JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_creator FROM public.creator_profiles WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = p_user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = p_user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows WHERE follower_id = auth.uid() AND followee_id = p_user_id
    ) INTO v_is_following;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'venue_name', v.venue_name,
        'punctuality', vr.punctuality,
        'presentation', vr.presentation,
        'comment', vr.comment,
        'date', vr.created_at
    ) ORDER BY vr.created_at DESC), '[]'::JSONB)
    INTO v_reviews
    FROM public.venue_reviews vr
    JOIN public.venue_profiles v ON v.id = vr.venue_id
    WHERE vr.creator_id = v_creator.id;

    SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'venue_name', v.venue_name,
        'area', v.area,
        'category', v.category
    )), '[]'::JSONB)
    INTO v_collabs
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE b.creator_id = v_creator.id
      AND b.stage IN ('checked_in', 'proof_due', 'completed');

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'full_name', v_creator.full_name,
        'instagram_handle', v_creator.instagram_handle,
        'tiktok_handle', v_creator.tiktok_handle,
        'city', v_creator.city,
        'bio', v_creator.bio,
        'niches', v_creator.niches,
        'score', v_creator.score,
        'proof_rate', v_creator.proof_rate,
        'avatar_url', coalesce(v_creator.avatar_url, ''),
        'cover_url', coalesce(v_creator.cover_url, ''),
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_creator_public_profile_by_creator_id(p_creator_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator public.creator_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_reviews JSONB;
    v_collabs JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_creator FROM public.creator_profiles WHERE id = p_creator_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = v_creator.user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = v_creator.user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = auth.uid() AND followee_id = v_creator.user_id
    ) INTO v_is_following;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'venue_name', v.venue_name,
        'punctuality', vr.punctuality,
        'presentation', vr.presentation,
        'comment', vr.comment,
        'date', vr.created_at
    ) ORDER BY vr.created_at DESC), '[]'::JSONB)
    INTO v_reviews
    FROM public.venue_reviews vr
    JOIN public.venue_profiles v ON v.id = vr.venue_id
    WHERE vr.creator_id = v_creator.id;

    SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
        'venue_name', v.venue_name,
        'area', v.area,
        'category', v.category
    )), '[]'::JSONB)
    INTO v_collabs
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE b.creator_id = v_creator.id
      AND b.stage IN ('checked_in', 'proof_due', 'completed');

    RETURN jsonb_build_object(
        'creator_id', v_creator.id,
        'user_id', v_creator.user_id,
        'full_name', v_creator.full_name,
        'instagram_handle', v_creator.instagram_handle,
        'tiktok_handle', v_creator.tiktok_handle,
        'city', v_creator.city,
        'bio', v_creator.bio,
        'niches', v_creator.niches,
        'score', v_creator.score,
        'proof_rate', v_creator.proof_rate,
        'avatar_url', coalesce(v_creator.avatar_url, ''),
        'cover_url', coalesce(v_creator.cover_url, ''),
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'reviews_received', v_reviews,
        'collaborations', v_collabs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_creator_public_profile_by_creator_id(UUID) TO authenticated;

-- Changing RETURNS TABLE requires drop first (Postgres cannot alter OUT params in place).
DROP FUNCTION IF EXISTS public.search_members(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.search_members(
    p_query TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    profile_ref_id UUID,
    user_id UUID,
    member_type TEXT,
    full_name TEXT,
    instagram_handle TEXT,
    tiktok_handle TEXT,
    city TEXT,
    score NUMERIC,
    followers BIGINT,
    is_following BOOLEAN,
    avatar_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_query TEXT;
    v_limit INTEGER;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_query := lower(trim(coalesce(p_query, '')));
    v_limit := greatest(1, least(coalesce(p_limit, 30), 50));

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            cp.id AS profile_ref_id,
            cp.user_id AS user_id,
            'creator'::TEXT AS member_type,
            cp.full_name AS full_name,
            cp.instagram_handle AS instagram_handle,
            cp.tiktok_handle AS tiktok_handle,
            cp.city AS city,
            cp.score AS score,
            (SELECT count(*)::BIGINT FROM public.follows f WHERE f.followee_id = cp.user_id) AS followers,
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = cp.user_id
            ) AS is_following,
            coalesce(cp.avatar_url, '') AS avatar_url
        FROM public.creator_profiles cp
        JOIN public.profiles p ON p.id = cp.user_id
        WHERE cp.status = 'approved'
          AND p.status = 'approved'
          AND cp.user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(coalesce(cp.full_name, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.tiktok_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.city, '')) LIKE '%' || v_query || '%'
              OR EXISTS (
                  SELECT 1 FROM unnest(coalesce(cp.niches, ARRAY[]::TEXT[])) n
                  WHERE lower(n) LIKE '%' || v_query || '%'
              )
          )

        UNION ALL

        SELECT
            vp.id AS profile_ref_id,
            vp.owner_user_id AS user_id,
            'venue'::TEXT AS member_type,
            vp.venue_name AS full_name,
            vp.venue_name AS instagram_handle,
            ''::TEXT AS tiktok_handle,
            vp.area AS city,
            0::NUMERIC AS score,
            (SELECT count(*)::BIGINT FROM public.follows f WHERE f.followee_id = vp.owner_user_id) AS followers,
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = vp.owner_user_id
            ) AS is_following,
            ''::TEXT AS avatar_url
        FROM public.venue_profiles vp
        JOIN public.profiles p ON p.id = vp.owner_user_id
        WHERE vp.status = 'approved'
          AND p.status = 'approved'
          AND vp.owner_user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(vp.venue_name) LIKE '%' || v_query || '%'
              OR lower(vp.area) LIKE '%' || v_query || '%'
              OR lower(vp.category::TEXT) LIKE '%' || v_query || '%'
          )
    ) AS members
    ORDER BY members.score DESC NULLS LAST, members.followers DESC
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_members(TEXT, INTEGER) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260630000026_campaign_media_and_fields.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Campaign create: real offer image + editable description/time/requirements/host note.
-- Also allow venue owners to update their own draft/review campaigns.

DROP FUNCTION IF EXISTS public.submit_campaign_for_review(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[], UUID);

CREATE OR REPLACE FUNCTION public.submit_campaign_for_review(
    p_title TEXT,
    p_category TEXT,
    p_model TEXT,
    p_date_label TEXT,
    p_value_label TEXT,
    p_slots INTEGER,
    p_deliverables TEXT[],
    p_venue_id UUID DEFAULT NULL,
    p_image_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_time_label TEXT DEFAULT NULL,
    p_requirements TEXT[] DEFAULT NULL,
    p_host_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue public.venue_profiles%ROWTYPE;
    v_offer_id UUID;
    v_venue_id UUID;
    v_image TEXT;
    v_description TEXT;
    v_time TEXT;
    v_requirements TEXT[];
    v_host_note TEXT;
BEGIN
    v_venue_id := public.resolve_active_venue_id(p_venue_id);

    SELECT * INTO v_venue
    FROM public.venue_profiles
    WHERE id = v_venue_id;

    IF v_venue.status <> 'approved' THEN
        RAISE EXCEPTION 'Venue must be approved before creating campaigns';
    END IF;

    v_image := coalesce(nullif(btrim(p_image_name), ''), 'venue-placeholder');
    v_description := coalesce(
        nullif(btrim(p_description), ''),
        p_title || ' — submitted via Marvi Society.'
    );
    v_time := coalesce(nullif(btrim(p_time_label), ''), 'Flexible');
    v_requirements := CASE
        WHEN p_requirements IS NULL OR cardinality(p_requirements) = 0
            THEN ARRAY['Approved creator membership']::TEXT[]
        ELSE p_requirements
    END;
    v_host_note := coalesce(
        nullif(btrim(p_host_note), ''),
        'Submitted for admin review.'
    );

    INSERT INTO public.offers (
        venue_id,
        title,
        category,
        model,
        date_label,
        time_label,
        value_label,
        capacity,
        remaining_slots,
        description,
        deliverables,
        requirements,
        host_note,
        image_name,
        status,
        lat,
        lng
    ) VALUES (
        v_venue.id,
        p_title,
        p_category::public.offer_category,
        p_model::public.collaboration_model,
        p_date_label,
        v_time,
        p_value_label,
        p_slots,
        p_slots,
        v_description,
        COALESCE(p_deliverables, ARRAY[]::TEXT[]),
        v_requirements,
        v_host_note,
        v_image,
        'review',
        v_venue.lat,
        v_venue.lng
    )
    RETURNING id INTO v_offer_id;

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
    VALUES (
        'campaign_review',
        v_offer_id,
        p_title,
        v_venue.venue_name || ' requested ' || p_slots::TEXT || ' creator slots.',
        'High',
        'open'
    );

    RETURN v_offer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_campaign_for_review(
    TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[], UUID, TEXT, TEXT, TEXT, TEXT[], TEXT
) TO authenticated;

-- Venue can edit own campaigns while still draft/review (before admin goes live).
CREATE OR REPLACE FUNCTION public.update_own_campaign(
    p_offer_id UUID,
    p_title TEXT DEFAULT NULL,
    p_date_label TEXT DEFAULT NULL,
    p_value_label TEXT DEFAULT NULL,
    p_slots INTEGER DEFAULT NULL,
    p_deliverables TEXT[] DEFAULT NULL,
    p_image_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_time_label TEXT DEFAULT NULL,
    p_requirements TEXT[] DEFAULT NULL,
    p_host_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_offer public.offers%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT o.* INTO v_offer
    FROM public.offers o
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE o.id = p_offer_id
      AND v.owner_user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign not found';
    END IF;

    IF v_offer.status NOT IN ('draft', 'review') THEN
        RAISE EXCEPTION 'Only draft or review campaigns can be edited';
    END IF;

    UPDATE public.offers SET
        title = coalesce(nullif(btrim(p_title), ''), title),
        date_label = coalesce(nullif(btrim(p_date_label), ''), date_label),
        value_label = coalesce(nullif(btrim(p_value_label), ''), value_label),
        capacity = CASE
            WHEN p_slots IS NOT NULL AND p_slots > 0 THEN p_slots
            ELSE capacity
        END,
        remaining_slots = CASE
            WHEN p_slots IS NOT NULL AND p_slots > 0 THEN greatest(p_slots - (capacity - remaining_slots), 0)
            ELSE remaining_slots
        END,
        deliverables = CASE
            WHEN p_deliverables IS NOT NULL THEN p_deliverables
            ELSE deliverables
        END,
        image_name = coalesce(nullif(btrim(p_image_name), ''), image_name),
        description = coalesce(nullif(btrim(p_description), ''), description),
        time_label = coalesce(nullif(btrim(p_time_label), ''), time_label),
        requirements = CASE
            WHEN p_requirements IS NOT NULL AND cardinality(p_requirements) > 0 THEN p_requirements
            ELSE requirements
        END,
        host_note = coalesce(nullif(btrim(p_host_note), ''), host_note),
        updated_at = now()
    WHERE id = p_offer_id;

    UPDATE public.admin_tasks
    SET title = coalesce(nullif(btrim(p_title), ''), title),
        subtitle = CASE
            WHEN p_slots IS NOT NULL AND p_slots > 0
                THEN regexp_replace(subtitle, '[0-9]+ creator slots', p_slots::TEXT || ' creator slots')
            ELSE subtitle
        END
    WHERE subject_id = p_offer_id
      AND type = 'campaign_review'
      AND status = 'open';

    RETURN p_offer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_own_campaign(
    UUID, TEXT, TEXT, TEXT, INTEGER, TEXT[], TEXT, TEXT, TEXT, TEXT[], TEXT
) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260715000001_repair_venue_reviews.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Repair: recreate public.venue_reviews on environments where the original
-- 20260613000001 migration was recorded as applied but its table DDL never
-- ran (the migration file was edited after being pushed, so `db push` skipped
-- it). fetch_venue_review_queue() and the public-profile functions LEFT JOIN
-- this table, so its absence surfaces as
-- `relation "public.venue_reviews" does not exist` on the Venue Studio screen.
-- Fully idempotent so it is safe on databases that already have the table.

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

DROP POLICY IF EXISTS venue_reviews_select ON public.venue_reviews;
CREATE POLICY venue_reviews_select ON public.venue_reviews
    FOR SELECT USING (
        created_by = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = venue_reviews.venue_id AND v.owner_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS venue_reviews_insert ON public.venue_reviews;
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


-- ═══════════════════════════════════════════════════════════════════════════
-- 20260717000001_proof_upload_retry_policy.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Allow creators to replace a proof screenshot for the same booking.
-- The clients upload with x-upsert=true, which becomes UPDATE when the
-- deterministic object path already exists.

DROP POLICY IF EXISTS proof_update_own ON storage.objects;
CREATE POLICY proof_update_own ON storage.objects
    FOR UPDATE
    USING (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );


