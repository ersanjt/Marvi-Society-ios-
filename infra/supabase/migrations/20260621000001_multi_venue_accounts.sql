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
