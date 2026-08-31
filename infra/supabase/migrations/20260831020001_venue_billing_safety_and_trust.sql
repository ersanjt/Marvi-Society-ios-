-- Venue B2B billing (Partner + Featured Boost), safety reports, 18+ persistence,
-- and close public INSERT policies that the anon key could spam.

-- ---------------------------------------------------------------------------
-- Billing schema
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'venue_plan') THEN
        CREATE TYPE public.venue_plan AS ENUM ('free', 'partner');
    END IF;
END
$$;

ALTER TABLE public.venue_profiles
    ADD COLUMN IF NOT EXISTS plan public.venue_plan NOT NULL DEFAULT 'free';

ALTER TABLE public.offers
    ADD COLUMN IF NOT EXISTS featured_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS boost_purchase_id UUID;

CREATE INDEX IF NOT EXISTS offers_featured_until_idx
    ON public.offers (featured_until)
    WHERE featured_until IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS public.venue_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    owner_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    plan public.venue_plan NOT NULL DEFAULT 'partner',
    status TEXT NOT NULL DEFAULT 'inactive',
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT UNIQUE,
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT venue_subscriptions_status_chk CHECK (
        status IN ('inactive', 'active', 'past_due', 'canceled')
    )
);

CREATE INDEX IF NOT EXISTS venue_subscriptions_venue_idx
    ON public.venue_subscriptions (venue_id, status);

CREATE TABLE IF NOT EXISTS public.boost_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    offer_id UUID NOT NULL REFERENCES public.offers (id) ON DELETE CASCADE,
    buyer_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    stripe_checkout_session_id TEXT UNIQUE,
    stripe_payment_intent_id TEXT,
    amount_cents INTEGER NOT NULL DEFAULT 4900,
    currency TEXT NOT NULL DEFAULT 'usd',
    featured_until TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT boost_purchases_status_chk CHECK (
        status IN ('pending', 'paid', 'refunded')
    )
);

CREATE INDEX IF NOT EXISTS boost_purchases_offer_idx ON public.boost_purchases (offer_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'offers_boost_purchase_fk'
    ) THEN
        ALTER TABLE public.offers
            ADD CONSTRAINT offers_boost_purchase_fk
            FOREIGN KEY (boost_purchase_id) REFERENCES public.boost_purchases (id)
            ON DELETE SET NULL;
    END IF;
END
$$;

ALTER TABLE public.venue_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boost_purchases ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.venue_subscriptions TO authenticated;
GRANT SELECT ON public.boost_purchases TO authenticated;

DROP POLICY IF EXISTS venue_subscriptions_owner_select ON public.venue_subscriptions;
CREATE POLICY venue_subscriptions_owner_select ON public.venue_subscriptions
    FOR SELECT USING (
        owner_user_id = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = venue_id AND v.owner_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS boost_purchases_owner_select ON public.boost_purchases;
CREATE POLICY boost_purchases_owner_select ON public.boost_purchases
    FOR SELECT USING (
        buyer_user_id = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = venue_id AND v.owner_user_id = auth.uid()
        )
    );

DROP VIEW IF EXISTS public.offers_public;
CREATE VIEW public.offers_public AS
SELECT
    o.*,
    v.venue_name,
    v.area
FROM public.offers o
JOIN public.venue_profiles v ON v.id = o.venue_id
WHERE o.status = 'live'
  AND o.deleted_at IS NULL
  AND v.status = 'approved';

ALTER VIEW public.offers_public SET (security_invoker = true);
GRANT SELECT ON public.offers_public TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.venue_has_partner_access(p_venue_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.venue_profiles v
        LEFT JOIN public.venue_subscriptions s
            ON s.venue_id = v.id
           AND s.status = 'active'
           AND (s.current_period_end IS NULL OR s.current_period_end > now())
        WHERE v.id = p_venue_id
          AND v.deleted_at IS NULL
          AND (v.plan = 'partner' OR s.id IS NOT NULL)
    );
$$;

REVOKE ALL ON FUNCTION public.venue_has_partner_access(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.venue_has_partner_access(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.venue_billing_status(p_venue_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue_id UUID;
    v_plan public.venue_plan;
    v_live INTEGER;
    v_sub public.venue_subscriptions%ROWTYPE;
    v_partner BOOLEAN;
BEGIN
    v_venue_id := public.resolve_active_venue_id(p_venue_id);

    SELECT plan INTO v_plan
    FROM public.venue_profiles
    WHERE id = v_venue_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found';
    END IF;

    v_partner := public.venue_has_partner_access(v_venue_id);

    SELECT * INTO v_sub
    FROM public.venue_subscriptions
    WHERE venue_id = v_venue_id
    ORDER BY updated_at DESC
    LIMIT 1;

    SELECT count(*)::INTEGER INTO v_live
    FROM public.offers
    WHERE venue_id = v_venue_id
      AND status = 'live'
      AND deleted_at IS NULL;

    RETURN jsonb_build_object(
        'venue_id', v_venue_id,
        'plan', CASE WHEN v_partner THEN 'partner' ELSE coalesce(v_plan::TEXT, 'free') END,
        'partner', v_partner,
        'live_campaigns', v_live,
        'live_campaign_limit', CASE WHEN v_partner THEN NULL ELSE 1 END,
        'subscription_status', v_sub.status,
        'current_period_end', v_sub.current_period_end,
        'stripe_customer_id', v_sub.stripe_customer_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.venue_billing_status(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.venue_billing_status(UUID) TO authenticated, service_role;

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
    v_live INTEGER;
BEGIN
    v_venue_id := public.resolve_active_venue_id(p_venue_id);

    SELECT * INTO v_venue
    FROM public.venue_profiles
    WHERE id = v_venue_id
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found';
    END IF;

    IF v_venue.status <> 'approved' THEN
        RAISE EXCEPTION 'Venue must be approved before creating campaigns';
    END IF;

    IF NOT public.venue_has_partner_access(v_venue.id) THEN
        SELECT count(*)::INTEGER INTO v_live
        FROM public.offers
        WHERE venue_id = v_venue.id
          AND status = 'live'
          AND deleted_at IS NULL;
        IF v_live >= 1 THEN
            RAISE EXCEPTION 'Free plan allows 1 live campaign. Upgrade to Partner to publish more.';
        END IF;
    END IF;

    v_image := coalesce(nullif(btrim(p_image_name), ''), 'venue-placeholder');
    v_description := coalesce(
        nullif(btrim(p_description), ''),
        p_title || ' — published via Marvi Society.'
    );
    v_time := coalesce(nullif(btrim(p_time_label), ''), 'Flexible');
    v_requirements := CASE
        WHEN p_requirements IS NULL OR cardinality(p_requirements) = 0
            THEN ARRAY['Approved creator membership']::TEXT[]
        ELSE p_requirements
    END;
    v_host_note := coalesce(
        nullif(btrim(p_host_note), ''),
        'Live for creators on Explore.'
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
        'live',
        v_venue.lat,
        v_venue.lng
    )
    RETURNING id INTO v_offer_id;

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status, resolved_at)
    VALUES (
        'campaign_review',
        v_offer_id,
        p_title,
        v_venue.venue_name || ' published ' || p_slots::TEXT || ' creator slots (auto-live).',
        'Normal',
        'approved',
        now()
    );

    BEGIN
        PERFORM public.log_activity_event(
            'campaign_auto_live',
            'offer',
            v_offer_id,
            jsonb_build_object(
                'venue_id', v_venue.id,
                'venue_name', v_venue.venue_name,
                'title', p_title,
                'slots', p_slots
            )
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN v_offer_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_campaign_for_review(
    TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[], UUID, TEXT, TEXT, TEXT, TEXT[], TEXT
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.submit_campaign_for_review(
    TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[], UUID, TEXT, TEXT, TEXT, TEXT[], TEXT
) TO authenticated, service_role;

-- Webhook helpers (service role only). Stripe Checkout must confirm payment first.

CREATE OR REPLACE FUNCTION public.apply_paid_boost(
    p_offer_id UUID,
    p_session_id TEXT,
    p_days INTEGER DEFAULT 7,
    p_amount_cents INTEGER DEFAULT 4900,
    p_payment_intent TEXT DEFAULT NULL
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_offer public.offers%ROWTYPE;
    v_venue public.venue_profiles%ROWTYPE;
    v_until TIMESTAMPTZ;
    v_purchase_id UUID;
    v_uid UUID := auth.uid();
BEGIN
    SELECT * INTO v_offer FROM public.offers WHERE id = p_offer_id AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found';
    END IF;

    SELECT * INTO v_venue FROM public.venue_profiles WHERE id = v_offer.venue_id AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found';
    END IF;

    IF auth.role() <> 'service_role' THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    IF nullif(btrim(p_session_id), '') IS NULL THEN
        RAISE EXCEPTION 'Stripe session required';
    END IF;

    IF v_offer.status <> 'live' THEN
        RAISE EXCEPTION 'Only live campaigns can be featured';
    END IF;

    v_until := now() + make_interval(days => GREATEST(p_days, 1));

    INSERT INTO public.boost_purchases (
        venue_id, offer_id, buyer_user_id, stripe_checkout_session_id,
        stripe_payment_intent_id, amount_cents, featured_until, status
    ) VALUES (
        v_venue.id,
        v_offer.id,
        coalesce(v_uid, v_venue.owner_user_id),
        nullif(p_session_id, ''),
        nullif(p_payment_intent, ''),
        p_amount_cents,
        v_until,
        'paid'
    )
    ON CONFLICT (stripe_checkout_session_id)
    DO UPDATE SET status = 'paid', featured_until = EXCLUDED.featured_until
    RETURNING id INTO v_purchase_id;

    UPDATE public.offers
    SET featured_until = v_until,
        boost_purchase_id = v_purchase_id,
        updated_at = now()
    WHERE id = v_offer.id;

    RETURN v_until;
END;
$$;

REVOKE ALL ON FUNCTION public.apply_paid_boost(UUID, TEXT, INTEGER, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_paid_boost(UUID, TEXT, INTEGER, INTEGER, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.activate_partner_subscription(
    p_venue_id UUID,
    p_customer_id TEXT,
    p_subscription_id TEXT,
    p_period_end TIMESTAMPTZ,
    p_status TEXT DEFAULT 'active'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_owner UUID;
    v_status TEXT := lower(coalesce(nullif(btrim(p_status), ''), 'active'));
BEGIN
    IF auth.role() <> 'service_role' THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    SELECT owner_user_id INTO v_owner
    FROM public.venue_profiles
    WHERE id = p_venue_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found';
    END IF;

    IF v_status NOT IN ('inactive', 'active', 'past_due', 'canceled') THEN
        v_status := 'active';
    END IF;

    INSERT INTO public.venue_subscriptions (
        venue_id, owner_user_id, plan, status,
        stripe_customer_id, stripe_subscription_id, current_period_end, updated_at
    ) VALUES (
        p_venue_id, v_owner, 'partner', v_status,
        nullif(p_customer_id, ''), nullif(p_subscription_id, ''), p_period_end, now()
    )
    ON CONFLICT (stripe_subscription_id)
    DO UPDATE SET
        status = EXCLUDED.status,
        stripe_customer_id = coalesce(EXCLUDED.stripe_customer_id, public.venue_subscriptions.stripe_customer_id),
        current_period_end = EXCLUDED.current_period_end,
        updated_at = now();

    UPDATE public.venue_profiles
    SET plan = CASE WHEN v_status = 'active' THEN 'partner'::public.venue_plan ELSE 'free'::public.venue_plan END,
        updated_at = now()
    WHERE id = p_venue_id;
END;
$$;

REVOKE ALL ON FUNCTION public.activate_partner_subscription(UUID, TEXT, TEXT, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.activate_partner_subscription(UUID, TEXT, TEXT, TIMESTAMPTZ, TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Age confirmation
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS age_confirmed_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.confirm_age_18()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_at TIMESTAMPTZ;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.profiles
    SET age_confirmed_at = coalesce(age_confirmed_at, now()),
        updated_at = now()
    WHERE id = v_uid
    RETURNING age_confirmed_at INTO v_at;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    RETURN v_at;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_age_18() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_age_18() TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Safety reports
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.safety_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
    reporter_email TEXT,
    category TEXT NOT NULL DEFAULT 'safety',
    body TEXT NOT NULL,
    target_type TEXT,
    target_id UUID,
    status TEXT NOT NULL DEFAULT 'open',
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT safety_reports_status_chk CHECK (
        status IN ('open', 'reviewing', 'resolved', 'dismissed')
    )
);

CREATE INDEX IF NOT EXISTS safety_reports_status_idx ON public.safety_reports (status, created_at DESC);

ALTER TABLE public.safety_reports ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.safety_reports TO authenticated;

DROP POLICY IF EXISTS safety_reports_own_select ON public.safety_reports;
CREATE POLICY safety_reports_own_select ON public.safety_reports
    FOR SELECT USING (reporter_id = auth.uid() OR public.is_admin());

CREATE OR REPLACE FUNCTION public.submit_safety_report(
    p_body TEXT,
    p_category TEXT DEFAULT 'safety',
    p_target_type TEXT DEFAULT NULL,
    p_target_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_id UUID;
    v_body TEXT := nullif(btrim(p_body), '');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_body IS NULL OR char_length(v_body) < 8 THEN
        RAISE EXCEPTION 'Please describe the issue';
    END IF;

    INSERT INTO public.safety_reports (reporter_id, category, body, target_type, target_id)
    VALUES (
        v_uid,
        coalesce(nullif(btrim(p_category), ''), 'safety'),
        left(v_body, 4000),
        nullif(btrim(p_target_type), ''),
        p_target_id
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_safety_report(TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_safety_report(TEXT, TEXT, TEXT, UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_list_safety_reports(p_limit INTEGER DEFAULT 80)
RETURNS SETOF public.safety_reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    RETURN QUERY
    SELECT *
    FROM public.safety_reports
    ORDER BY created_at DESC
    LIMIT GREATEST(1, LEAST(coalesce(p_limit, 80), 200));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_safety_reports(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_safety_reports(INTEGER) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_set_safety_report_status(
    p_id UUID,
    p_status TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_status TEXT := lower(btrim(p_status));
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    IF v_status NOT IN ('open', 'reviewing', 'resolved', 'dismissed') THEN
        RAISE EXCEPTION 'Invalid status';
    END IF;

    UPDATE public.safety_reports
    SET status = v_status,
        admin_notes = coalesce(nullif(btrim(p_notes), ''), admin_notes),
        updated_at = now()
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Report not found';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_safety_report_status(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_safety_report_status(UUID, TEXT, TEXT) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Demo lead CRM
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_list_demo_requests(p_limit INTEGER DEFAULT 80)
RETURNS SETOF public.demo_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    RETURN QUERY
    SELECT *
    FROM public.demo_requests
    ORDER BY created_at DESC
    LIMIT GREATEST(1, LEAST(coalesce(p_limit, 80), 200));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_demo_requests(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_demo_requests(INTEGER) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_set_demo_request_status(p_id UUID, p_status TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_status TEXT := lower(btrim(p_status));
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    IF v_status NOT IN ('new', 'contacted', 'qualified', 'won', 'closed') THEN
        RAISE EXCEPTION 'Invalid status';
    END IF;
    UPDATE public.demo_requests SET status = v_status WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lead not found';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_demo_request_status(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_demo_request_status(UUID, TEXT) TO authenticated, service_role;

DROP POLICY IF EXISTS demo_requests_admin_update ON public.demo_requests;
CREATE POLICY demo_requests_admin_update ON public.demo_requests
    FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ---------------------------------------------------------------------------
-- Close public inserts (anon key must not flood these tables)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS demo_requests_insert_public ON public.demo_requests;
DROP POLICY IF EXISTS deletion_insert ON public.deletion_requests;
