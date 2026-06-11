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
