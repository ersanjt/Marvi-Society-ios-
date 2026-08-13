-- Venue partners can resubmit paused establishments, and admin pause
-- should not trap the whole account when another venue is still approved.

CREATE OR REPLACE FUNCTION public.submit_establishment_for_review(p_venue_id UUID)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_has_other_approved BOOLEAN := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    PERFORM set_config('marvi.allow_lifecycle', '1', true);

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    -- Heal checklist flags from existing data (legacy / paused resubmits).
    UPDATE public.venue_profiles
    SET
        details_complete = details_complete
            OR (
                nullif(trim(instagram_handle), '') IS NOT NULL
                AND nullif(trim(description), '') IS NOT NULL
                AND coalesce(cardinality(categories), 0) > 0
                AND nullif(trim(contact_name), '') IS NOT NULL
                AND nullif(trim(contact_phone), '') IS NOT NULL
            ),
        address_complete = address_complete
            OR (
                nullif(trim(city), '') IS NOT NULL
                OR nullif(trim(area), '') IS NOT NULL
                OR nullif(trim(address_line1), '') IS NOT NULL
                OR nullif(trim(address), '') IS NOT NULL
            ),
        photos_complete = photos_complete
            OR nullif(trim(logo_url), '') IS NOT NULL,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    IF trim(coalesce(v_row.venue_name, '')) = '' AND trim(coalesce(v_row.draft_name, '')) = '' THEN
        RAISE EXCEPTION 'Name can''t be empty.';
    END IF;

    IF NOT v_row.details_complete OR NOT v_row.address_complete OR NOT v_row.photos_complete THEN
        RAISE EXCEPTION 'Complete establishment details, address, and photos before submitting';
    END IF;

    UPDATE public.venue_profiles
    SET
        venue_name = coalesce(nullif(trim(draft_name), ''), venue_name),
        status = 'under_review',
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    IF NOT EXISTS (
        SELECT 1 FROM public.admin_tasks
        WHERE type = 'venue_application'
          AND subject_id = p_venue_id
          AND status = 'open'
    ) THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
        VALUES (
            'venue_application',
            p_venue_id,
            coalesce(nullif(trim(v_row.venue_name), ''), 'Establishment'),
            coalesce(nullif(v_row.city, ''), v_row.area) || ' · resubmitted for review',
            'High',
            'open'
        );
    END IF;

    -- Unblock the owner so they can stay in Studio while waiting.
    SELECT EXISTS (
        SELECT 1 FROM public.venue_profiles
        WHERE owner_user_id = v_uid
          AND id IS DISTINCT FROM p_venue_id
          AND status = 'approved'
    ) INTO v_has_other_approved;

    UPDATE public.profiles
    SET
        status = CASE
            WHEN v_has_other_approved THEN 'approved'::public.membership_status
            ELSE 'under_review'::public.membership_status
        END,
        updated_at = now()
    WHERE id = v_uid
      AND status = 'paused'::public.membership_status;

    RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_establishment_for_review(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_establishment_for_review(UUID) TO authenticated, service_role;

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

    SELECT EXISTS (
        SELECT 1 FROM public.venue_profiles
        WHERE owner_user_id = v_row.owner_user_id
          AND id IS DISTINCT FROM p_venue_id
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
