-- Keep admin Queue in sync with Venues/Users/Campaigns actions.
-- Also stop creator membership approve from auto-approving all venues.

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
    v_has_other_approved BOOLEAN := false;
    v_task_status public.admin_task_status;
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
      AND deleted_at IS NULL
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venue not found';
    END IF;

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

    -- Keep Queue synchronized with Venues-tab actions.
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
                THEN coalesce(nullif(v_row.venue_name, ''), 'Mekânın') || ' onaylandı. Stüdyo’dan kampanya oluştur; admin canlı yayınladıktan sonra Keşfet’te görünür.'
                ELSE coalesce(nullif(v_row.venue_name, ''), 'Your venue') || ' was approved. Create a campaign in Studio — it appears on Explore after admin publishes it live.'
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

CREATE OR REPLACE FUNCTION public.admin_set_membership_status(
    p_user_id UUID,
    p_status public.membership_status
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role public.user_role;
    v_task_status public.admin_task_status;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot change your own status';
    END IF;

    UPDATE public.profiles
    SET
        status = p_status,
        paused_by_self = CASE WHEN p_status = 'paused' THEN false ELSE paused_by_self END,
        updated_at = now()
    WHERE id = p_user_id
    RETURNING role INTO v_role;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    UPDATE public.creator_profiles
    SET status = p_status, updated_at = now()
    WHERE user_id = p_user_id;

    -- Only cascade membership onto venues for venue-role accounts.
    -- Creator approve must NOT auto-approve business locations.
    IF v_role = 'venue' THEN
        UPDATE public.venue_profiles
        SET
            status = CASE
                WHEN p_status = 'approved' THEN 'approved'::public.membership_status
                WHEN p_status = 'under_review' THEN 'under_review'::public.membership_status
                ELSE 'paused'::public.membership_status
            END,
            updated_at = now()
        WHERE owner_user_id = p_user_id
          AND deleted_at IS NULL;
    END IF;

    v_task_status := CASE
        WHEN p_status = 'approved' THEN 'approved'::public.admin_task_status
        ELSE 'rejected'::public.admin_task_status
    END;

    UPDATE public.admin_tasks
    SET
        status = v_task_status,
        resolved_at = now(),
        assigned_admin_id = coalesce(assigned_admin_id, auth.uid())
    WHERE type = 'creator_application'
      AND subject_id = p_user_id
      AND status = 'open';

    -- If this is a venue account, also settle open venue application tasks for their venues.
    IF v_role = 'venue' THEN
        UPDATE public.admin_tasks t
        SET
            status = v_task_status,
            resolved_at = now(),
            assigned_admin_id = coalesce(t.assigned_admin_id, auth.uid())
        FROM public.venue_profiles v
        WHERE t.type = 'venue_application'
          AND t.subject_id = v.id
          AND v.owner_user_id = p_user_id
          AND t.status = 'open';
    END IF;

    PERFORM public.log_activity_event(
        'admin_membership_status',
        'profile',
        p_user_id,
        jsonb_build_object('status', p_status, 'role', v_role)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_membership_status(UUID, public.membership_status) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_membership_status(UUID, public.membership_status) TO authenticated, service_role;

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

    UPDATE public.bookings b
    SET
        stage = 'cancelled',
        updated_at = now()
    FROM public.offers o
    WHERE o.id = b.offer_id
      AND o.venue_id = p_venue_id
      AND b.stage IS DISTINCT FROM 'cancelled'
      AND b.stage IS DISTINCT FROM 'completed';

    UPDATE public.admin_tasks
    SET
        status = 'rejected',
        resolved_at = now(),
        assigned_admin_id = coalesce(assigned_admin_id, auth.uid())
    WHERE status = 'open'
      AND (
            (type = 'venue_application' AND subject_id = p_venue_id)
            OR (
                type = 'campaign_review'
                AND subject_id IN (SELECT id FROM public.offers WHERE venue_id = p_venue_id)
            )
        );

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
