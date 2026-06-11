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
