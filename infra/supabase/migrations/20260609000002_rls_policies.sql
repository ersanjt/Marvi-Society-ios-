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
