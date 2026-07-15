-- Campaign create: real offer image + editable description/time/requirements/host note.
-- Also allow venue owners to update their own draft/review campaigns.

DROP FUNCTION IF EXISTS public.submit_campaign_for_review(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[], UUID);

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
    WHERE id = v_venue_id;

    IF v_venue.status <> 'approved' THEN
        RAISE EXCEPTION 'Venue must be approved before creating campaigns';
    END IF;

    v_image := coalesce(nullif(btrim(p_image_name), ''), 'venue-placeholder');
    v_description := coalesce(
        nullif(btrim(p_description), ''),
        p_title || ' — submitted via Marvi Society.'
    );
    v_time := coalesce(nullif(btrim(p_time_label), ''), 'Flexible');
    v_requirements := CASE
        WHEN p_requirements IS NULL OR cardinality(p_requirements) = 0
            THEN ARRAY['Approved creator membership']::TEXT[]
        ELSE p_requirements
    END;
    v_host_note := coalesce(
        nullif(btrim(p_host_note), ''),
        'Submitted for admin review.'
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

GRANT EXECUTE ON FUNCTION public.submit_campaign_for_review(
    TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT[], UUID, TEXT, TEXT, TEXT, TEXT[], TEXT
) TO authenticated;

-- Venue can edit own campaigns while still draft/review (before admin goes live).
CREATE OR REPLACE FUNCTION public.update_own_campaign(
    p_offer_id UUID,
    p_title TEXT DEFAULT NULL,
    p_date_label TEXT DEFAULT NULL,
    p_value_label TEXT DEFAULT NULL,
    p_slots INTEGER DEFAULT NULL,
    p_deliverables TEXT[] DEFAULT NULL,
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
    v_offer public.offers%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT o.* INTO v_offer
    FROM public.offers o
    JOIN public.venue_profiles v ON v.id = o.venue_id
    WHERE o.id = p_offer_id
      AND v.owner_user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign not found';
    END IF;

    IF v_offer.status NOT IN ('draft', 'review') THEN
        RAISE EXCEPTION 'Only draft or review campaigns can be edited';
    END IF;

    UPDATE public.offers SET
        title = coalesce(nullif(btrim(p_title), ''), title),
        date_label = coalesce(nullif(btrim(p_date_label), ''), date_label),
        value_label = coalesce(nullif(btrim(p_value_label), ''), value_label),
        capacity = CASE
            WHEN p_slots IS NOT NULL AND p_slots > 0 THEN p_slots
            ELSE capacity
        END,
        remaining_slots = CASE
            WHEN p_slots IS NOT NULL AND p_slots > 0 THEN greatest(p_slots - (capacity - remaining_slots), 0)
            ELSE remaining_slots
        END,
        deliverables = CASE
            WHEN p_deliverables IS NOT NULL THEN p_deliverables
            ELSE deliverables
        END,
        image_name = coalesce(nullif(btrim(p_image_name), ''), image_name),
        description = coalesce(nullif(btrim(p_description), ''), description),
        time_label = coalesce(nullif(btrim(p_time_label), ''), time_label),
        requirements = CASE
            WHEN p_requirements IS NOT NULL AND cardinality(p_requirements) > 0 THEN p_requirements
            ELSE requirements
        END,
        host_note = coalesce(nullif(btrim(p_host_note), ''), host_note),
        updated_at = now()
    WHERE id = p_offer_id;

    UPDATE public.admin_tasks
    SET title = coalesce(nullif(btrim(p_title), ''), title),
        subtitle = CASE
            WHEN p_slots IS NOT NULL AND p_slots > 0
                THEN regexp_replace(subtitle, '[0-9]+ creator slots', p_slots::TEXT || ' creator slots')
            ELSE subtitle
        END
    WHERE subject_id = p_offer_id
      AND type = 'campaign_review'
      AND status = 'open';

    RETURN p_offer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_own_campaign(
    UUID, TEXT, TEXT, TEXT, INTEGER, TEXT[], TEXT, TEXT, TEXT, TEXT[], TEXT
) TO authenticated;
