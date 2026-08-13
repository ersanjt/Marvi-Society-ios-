-- Admin can soft-delete venues; hide deleted from directories and partner lists.

ALTER TABLE public.venue_profiles
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_venue_profiles_deleted_at
    ON public.venue_profiles (deleted_at)
    WHERE deleted_at IS NULL;

CREATE OR REPLACE FUNCTION public.admin_list_venues(
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    venue_id UUID,
    venue_name TEXT,
    area TEXT,
    category TEXT,
    status public.membership_status,
    owner_user_id UUID,
    owner_email TEXT,
    owner_name TEXT,
    offer_count INTEGER,
    live_offer_count INTEGER,
    booking_count INTEGER,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
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
        v.id,
        v.venue_name,
        v.area,
        v.category::TEXT,
        v.status,
        v.owner_user_id,
        coalesce(p.email, u.email),
        coalesce(cp.full_name, p.email, u.email),
        (SELECT count(*)::INTEGER FROM public.offers o WHERE o.venue_id = v.id AND o.deleted_at IS NULL),
        (SELECT count(*)::INTEGER FROM public.offers o WHERE o.venue_id = v.id AND o.deleted_at IS NULL AND o.status = 'live'),
        (SELECT count(*)::INTEGER FROM public.bookings b JOIN public.offers o ON o.id = b.offer_id WHERE o.venue_id = v.id AND o.deleted_at IS NULL),
        v.created_at,
        v.updated_at
    FROM public.venue_profiles v
    LEFT JOIN public.profiles p ON p.id = v.owner_user_id
    LEFT JOIN auth.users u ON u.id = v.owner_user_id
    LEFT JOIN public.creator_profiles cp ON cp.user_id = v.owner_user_id
    WHERE v.deleted_at IS NULL
    AND (
        p_search IS NULL OR trim(p_search) = ''
        OR lower(coalesce(v.venue_name, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(v.area, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(p.email, u.email, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.full_name, '')) LIKE '%' || lower(trim(p_search)) || '%'
    )
    AND (
        p_status IS NULL OR trim(p_status) = ''
        OR v.status::TEXT = lower(trim(p_status))
    )
    ORDER BY
        CASE v.status
            WHEN 'under_review' THEN 0
            WHEN 'approved' THEN 1
            ELSE 2
        END,
        v.updated_at DESC NULLS LAST,
        v.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 100), 300));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_venues(TEXT, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_venues(TEXT, TEXT, INTEGER) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_delete_venue(p_venue_id UUID)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.venue_profiles;
    v_locale TEXT;
    v_has_other_approved BOOLEAN := false;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;
    IF p_venue_id IS NULL THEN
        RAISE EXCEPTION 'Venue required';
    END IF;

    UPDATE public.venue_profiles
    SET
        deleted_at = now(),
        status = 'paused'::public.membership_status,
        updated_at = now()
    WHERE id = p_venue_id
      AND deleted_at IS NULL
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found or already deleted';
    END IF;

    -- Soft-delete campaigns so they leave Explore.
    UPDATE public.offers
    SET
        deleted_at = coalesce(deleted_at, now()),
        status = CASE
            WHEN status = 'live'::public.offer_status THEN 'completed'::public.offer_status
            ELSE status
        END,
        updated_at = now()
    WHERE venue_id = p_venue_id
      AND deleted_at IS NULL;

    -- Cancel open bookings tied to this venue's offers.
    UPDATE public.bookings b
    SET
        stage = 'cancelled',
        updated_at = now()
    FROM public.offers o
    WHERE o.id = b.offer_id
      AND o.venue_id = p_venue_id
      AND b.stage IS DISTINCT FROM 'cancelled'
      AND b.stage IS DISTINCT FROM 'completed';

    SELECT EXISTS (
        SELECT 1 FROM public.venue_profiles
        WHERE owner_user_id = v_row.owner_user_id
          AND id IS DISTINCT FROM p_venue_id
          AND deleted_at IS NULL
          AND status = 'approved'
    ) INTO v_has_other_approved;

    UPDATE public.profiles
    SET
        status = CASE
            WHEN v_has_other_approved THEN status
            WHEN role = 'venue' THEN 'paused'::public.membership_status
            ELSE status
        END,
        updated_at = now()
    WHERE id = v_row.owner_user_id;

    SELECT preferred_locale INTO v_locale FROM public.profiles WHERE id = v_row.owner_user_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_row.owner_user_id,
        CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekân kaldırıldı' ELSE 'Venue removed' END,
        CASE WHEN coalesce(v_locale, 'en') = 'tr'
            THEN coalesce(nullif(v_row.venue_name, ''), 'Mekânın') || ' yönetici tarafından kaldırıldı. Kampanyalar yayından alındı.'
            ELSE coalesce(nullif(v_row.venue_name, ''), 'Your venue') || ' was removed by an admin. Its campaigns were taken offline.'
        END,
        'membership',
        'trash',
        'tomato',
        jsonb_build_object('deep_link', 'marvisociety://studio', 'venue_id', v_row.id, 'deleted', true)
    );

    RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_delete_venue(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_venue(UUID) TO authenticated, service_role;

-- Partner-facing venue queries should ignore soft-deleted rows.
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

    IF v_active IS NULL OR EXISTS (
        SELECT 1 FROM public.venue_profiles vx
        WHERE vx.id = v_active AND (vx.deleted_at IS NOT NULL OR vx.owner_user_id IS DISTINCT FROM v_uid)
    ) THEN
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
      AND v.deleted_at IS NULL
    ORDER BY
        (v.id = v_active) DESC,
        CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END,
        v.created_at;
END;
$$;

REVOKE ALL ON FUNCTION public.fetch_my_venues() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fetch_my_venues() TO authenticated, service_role;
