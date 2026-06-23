-- Run in Supabase SQL Editor to enable full admin console in the iOS app.
-- Safe to re-run.

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
