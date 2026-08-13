-- Admin directory: all venues + all bookings for operations console.

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
        (SELECT count(*)::INTEGER FROM public.offers o WHERE o.venue_id = v.id),
        (SELECT count(*)::INTEGER FROM public.offers o WHERE o.venue_id = v.id AND o.status = 'live'),
        (SELECT count(*)::INTEGER FROM public.bookings b JOIN public.offers o ON o.id = b.offer_id WHERE o.venue_id = v.id),
        v.created_at,
        v.updated_at
    FROM public.venue_profiles v
    LEFT JOIN public.profiles p ON p.id = v.owner_user_id
    LEFT JOIN auth.users u ON u.id = v.owner_user_id
    LEFT JOIN public.creator_profiles cp ON cp.user_id = v.owner_user_id
    WHERE (
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

CREATE OR REPLACE FUNCTION public.admin_list_bookings(
    p_search TEXT DEFAULT NULL,
    p_stage TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    booking_id UUID,
    offer_id UUID,
    offer_title TEXT,
    venue_id UUID,
    venue_name TEXT,
    creator_user_id UUID,
    guest_name TEXT,
    guest_email TEXT,
    stage TEXT,
    date_label TEXT,
    proof_status TEXT,
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
        b.id,
        o.id,
        o.title,
        v.id,
        v.venue_name,
        cp.user_id,
        coalesce(nullif(trim(cp.full_name), ''), nullif(trim(cp.instagram_handle), ''), p.email, u.email, 'Creator'),
        coalesce(p.email, u.email),
        b.stage::TEXT,
        o.date_label,
        b.proof_status::TEXT,
        b.created_at,
        b.updated_at
    FROM public.bookings b
    JOIN public.offers o ON o.id = b.offer_id
    JOIN public.venue_profiles v ON v.id = o.venue_id
    JOIN public.creator_profiles cp ON cp.id = b.creator_id
    LEFT JOIN public.profiles p ON p.id = cp.user_id
    LEFT JOIN auth.users u ON u.id = cp.user_id
    WHERE (
        p_search IS NULL OR trim(p_search) = ''
        OR lower(coalesce(o.title, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(v.venue_name, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(cp.full_name, '')) LIKE '%' || lower(trim(p_search)) || '%'
        OR lower(coalesce(p.email, u.email, '')) LIKE '%' || lower(trim(p_search)) || '%'
    )
    AND (
        p_stage IS NULL OR trim(p_stage) = ''
        OR b.stage::TEXT = lower(trim(p_stage))
    )
    ORDER BY b.updated_at DESC NULLS LAST, b.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 100), 300));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_bookings(TEXT, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_bookings(TEXT, TEXT, INTEGER) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_set_venue_status(
    p_venue_id UUID,
    p_status TEXT
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.venue_profiles;
    v_status public.membership_status;
    v_locale TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;
    IF p_venue_id IS NULL THEN
        RAISE EXCEPTION 'Venue required';
    END IF;

    v_status := lower(trim(coalesce(p_status, '')))::public.membership_status;

    UPDATE public.venue_profiles
    SET status = v_status, updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found';
    END IF;

    UPDATE public.profiles
    SET
        status = CASE
            WHEN v_status = 'approved' THEN 'approved'::public.membership_status
            WHEN v_status = 'paused' AND role = 'venue' THEN 'paused'::public.membership_status
            ELSE status
        END,
        role = CASE
            WHEN v_status = 'approved' AND role IS DISTINCT FROM 'admin' THEN 'venue'::public.user_role
            ELSE role
        END,
        updated_at = now()
    WHERE id = v_row.owner_user_id;

    SELECT preferred_locale INTO v_locale FROM public.profiles WHERE id = v_row.owner_user_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_row.owner_user_id,
        CASE
            WHEN v_status = 'approved' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekânın onaylandı' ELSE 'Venue approved' END
            WHEN v_status = 'paused' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekân duraklatıldı' ELSE 'Venue paused' END
            ELSE CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekân durumu güncellendi' ELSE 'Venue status updated' END
        END,
        CASE
            WHEN v_status = 'approved' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr'
                THEN coalesce(nullif(v_row.venue_name, ''), 'Mekânın') || ' onaylandı. Stüdyo’dan kampanya oluşturabilirsin.'
                ELSE coalesce(nullif(v_row.venue_name, ''), 'Your venue') || ' was approved. You can create campaigns in Studio.'
            END
            WHEN v_status = 'paused' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr'
                THEN coalesce(nullif(v_row.venue_name, ''), 'Mekânın') || ' duraklatıldı. Detay için Gelen Kutusu’na bak.'
                ELSE coalesce(nullif(v_row.venue_name, ''), 'Your venue') || ' was paused. Check Inbox for details.'
            END
            ELSE CASE WHEN coalesce(v_locale, 'en') = 'tr'
                THEN coalesce(nullif(v_row.venue_name, ''), 'Mekân') || ' incelemede.'
                ELSE coalesce(nullif(v_row.venue_name, ''), 'Venue') || ' is under review.'
            END
        END,
        'membership',
        CASE WHEN v_status = 'approved' THEN 'checkmark.seal.fill' ELSE 'exclamationmark.triangle.fill' END,
        CASE WHEN v_status = 'approved' THEN 'emerald' WHEN v_status = 'paused' THEN 'tomato' ELSE 'gold' END,
        jsonb_build_object('deep_link', 'marvisociety://studio', 'venue_id', v_row.id)
    );

    RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_venue_status(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_venue_status(UUID, TEXT) TO authenticated, service_role;
