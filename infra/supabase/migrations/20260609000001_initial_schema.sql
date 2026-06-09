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
