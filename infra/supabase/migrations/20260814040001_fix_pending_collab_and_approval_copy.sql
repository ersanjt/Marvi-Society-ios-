-- Fix broken marketplace loops found in three-panel audit.

-- 1) Pending venue invites never loaded: venue_profiles has venue_name, not name.
CREATE OR REPLACE FUNCTION public.get_my_pending_collaboration_requests()
RETURNS TABLE (
    id UUID,
    offer_id UUID,
    offer_title TEXT,
    venue_name TEXT,
    status TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_venue_ids UUID[];
BEGIN
    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NOT NULL THEN
        RETURN QUERY
        SELECT
            cr.id,
            cr.offer_id,
            o.title,
            vp.venue_name,
            cr.status,
            cr.created_at
        FROM public.collaboration_requests cr
        JOIN public.offers o ON o.id = cr.offer_id
        JOIN public.venue_profiles vp ON vp.id = cr.venue_id
        WHERE cr.creator_id = v_creator_id
          AND cr.status = 'pending_creator'
        ORDER BY cr.created_at DESC;
        RETURN;
    END IF;

    SELECT array_agg(vp.id) INTO v_venue_ids
    FROM public.venue_profiles vp
    WHERE vp.owner_user_id = auth.uid()
      AND vp.deleted_at IS NULL;

    IF v_venue_ids IS NOT NULL THEN
        RETURN QUERY
        SELECT
            cr.id,
            cr.offer_id,
            o.title,
            vp.venue_name,
            cr.status,
            cr.created_at
        FROM public.collaboration_requests cr
        JOIN public.offers o ON o.id = cr.offer_id
        JOIN public.venue_profiles vp ON vp.id = cr.venue_id
        WHERE cr.venue_id = ANY (v_venue_ids)
          AND cr.status = 'pending_venue'
        ORDER BY cr.created_at DESC;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_pending_collaboration_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_pending_collaboration_requests() TO authenticated, service_role;

-- 2) Approval notification must match auto-live campaigns.
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
    v_has_other_approved BOOLEAN;
    v_task_status public.admin_task_status;
    v_locale TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    v_status := p_status::public.membership_status;

    UPDATE public.venue_profiles
    SET status = v_status, updated_at = now()
    WHERE id = p_venue_id
      AND deleted_at IS NULL
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.venue_profiles vp
        WHERE vp.owner_user_id = v_row.owner_user_id
          AND vp.id <> v_row.id
          AND vp.status = 'approved'
          AND vp.deleted_at IS NULL
    ) INTO v_has_other_approved;

    UPDATE public.profiles
    SET
        status = CASE
            WHEN v_status = 'approved' THEN 'approved'::public.membership_status
            WHEN v_status = 'paused' AND v_has_other_approved THEN status
            WHEN v_status = 'paused' AND role = 'venue' THEN 'paused'::public.membership_status
            WHEN v_status = 'under_review' AND role = 'venue' AND NOT v_has_other_approved
                THEN 'under_review'::public.membership_status
            ELSE status
        END,
        role = CASE
            WHEN v_status = 'approved' AND role IS DISTINCT FROM 'admin' THEN 'venue'::public.user_role
            ELSE role
        END,
        updated_at = now()
    WHERE id = v_row.owner_user_id;

    v_task_status := CASE
        WHEN v_status = 'approved' THEN 'approved'::public.admin_task_status
        ELSE 'rejected'::public.admin_task_status
    END;

    UPDATE public.admin_tasks
    SET
        status = v_task_status,
        resolved_at = now(),
        assigned_admin_id = coalesce(assigned_admin_id, auth.uid())
    WHERE type = 'venue_application'
      AND subject_id = p_venue_id
      AND status = 'open';

    SELECT preferred_locale INTO v_locale FROM public.profiles WHERE id = v_row.owner_user_id;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_row.owner_user_id,
        CASE
            WHEN v_status = 'approved' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekânın onaylandı' ELSE 'Venue approved' END
            WHEN v_status = 'paused' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekân güncellemesi gerekli' ELSE 'Venue needs updates' END
            ELSE CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekân durumu güncellendi' ELSE 'Venue status updated' END
        END,
        CASE
            WHEN v_status = 'approved' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr'
                THEN coalesce(nullif(v_row.venue_name, ''), 'Mekânın') || ' onaylandı. Stüdyo’dan kampanya oluştur — Keşfet’te hemen canlı olur; creator başvurabilir veya sen davet edebilirsin.'
                ELSE coalesce(nullif(v_row.venue_name, ''), 'Your venue') || ' was approved. Create a campaign in Studio — it goes live on Explore immediately; creators can apply or you can invite them.'
            END
            WHEN v_status = 'paused' THEN CASE WHEN coalesce(v_locale, 'en') = 'tr'
                THEN coalesce(nullif(v_row.venue_name, ''), 'Mekânın') || ' için düzeltme istendi. Stüdyo’dan düzenleyip tekrar incelemeye gönder.'
                ELSE coalesce(nullif(v_row.venue_name, ''), 'Your venue') || ' needs changes. Edit it in Studio and resubmit for review.'
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
