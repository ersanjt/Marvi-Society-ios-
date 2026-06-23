-- Marvi Society — production patches (idempotent)
-- Generated: 2026-06-23T20:22:23Z
-- Run in Supabase SQL Editor on EXISTING projects (schema already deployed).
-- Safe to re-run. Do not use on empty DB — use ALL_MIGRATIONS_COMBINED.sql instead.

-- ═══════════════════════════════════════════════════════════════════════════
-- apply-referral-fix.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Referral fix only — safe to run in Supabase SQL Editor.
-- Does NOT touch fetch_swipe_candidates (avoids migration rollback).

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS referral_code TEXT;

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

GRANT SELECT ON public.referral_codes TO anon, authenticated;

INSERT INTO public.referral_codes (code, owner_type, max_uses)
VALUES
    ('MARVI-IST', 'creator', 500),
    ('TURGUT', 'creator', 500),
    ('MARVI2026', 'venue', 100)
ON CONFLICT (code) DO NOTHING;

SELECT 'referral_codes' AS check_name, code, uses_count, max_uses
FROM public.referral_codes
ORDER BY code;


-- ═══════════════════════════════════════════════════════════════════════════
-- apply-admin-operations.sql
-- ═══════════════════════════════════════════════════════════════════════════
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


-- ═══════════════════════════════════════════════════════════════════════════
-- apply-push-outbox.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Run after apply-admin-operations.sql

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
-- apply-account-lifecycle.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Self-service account lifecycle — run in Supabase SQL Editor (safe to re-run)

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

SELECT 'account_lifecycle applied' AS status;


-- ═══════════════════════════════════════════════════════════════════════════
-- apply-multi-venue.sql
-- ═══════════════════════════════════════════════════════════════════════════
-- Run in Supabase SQL Editor after other apply-*.sql scripts.
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


