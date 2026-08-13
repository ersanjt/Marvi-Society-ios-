-- Simple marketplace loop: approved venues publish campaigns live immediately.
-- Creators see them on Explore and can apply; venues can still invite via swipe/shortlist.
-- Admins can unpublish later from Campaigns if needed.

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

    -- Audit only — do not block Explore with an open queue task.
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
