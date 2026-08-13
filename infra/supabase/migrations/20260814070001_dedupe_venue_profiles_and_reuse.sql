-- Soft-delete duplicate establishments for the same owner + name (+ area),
-- then prevent future accidental duplicates on create/register.

-- 1) Merge duplicates: keep the strongest row, soft-delete the rest,
--    move offers / active_venue_id onto the keeper.
DO $$
DECLARE
    r RECORD;
    v_keep UUID;
    v_dup UUID;
BEGIN
    FOR r IN
        SELECT
            owner_user_id,
            lower(trim(venue_name)) AS nkey,
            lower(trim(coalesce(nullif(area, ''), 'pending'))) AS akey,
            array_agg(id ORDER BY
                CASE status
                    WHEN 'approved' THEN 0
                    WHEN 'under_review' THEN 1
                    WHEN 'paused' THEN 2
                    ELSE 3
                END,
                (
                    SELECT count(*) FROM public.offers o
                    WHERE o.venue_id = venue_profiles.id AND o.deleted_at IS NULL
                ) DESC,
                created_at ASC
            ) AS ids
        FROM public.venue_profiles
        WHERE deleted_at IS NULL
          AND coalesce(trim(venue_name), '') <> ''
        GROUP BY 1, 2, 3
        HAVING count(*) > 1
    LOOP
        v_keep := r.ids[1];
        FOREACH v_dup IN ARRAY r.ids[2:array_length(r.ids, 1)]
        LOOP
            UPDATE public.offers
            SET venue_id = v_keep
            WHERE venue_id = v_dup
              AND deleted_at IS NULL;

            UPDATE public.profiles
            SET active_venue_id = v_keep,
                updated_at = now()
            WHERE active_venue_id = v_dup;

            UPDATE public.venue_profiles
            SET deleted_at = now(),
                updated_at = now()
            WHERE id = v_dup
              AND deleted_at IS NULL;
        END LOOP;
    END LOOP;
END $$;

-- 2) create_establishment_draft: reuse an existing live row with same name
CREATE OR REPLACE FUNCTION public.create_establishment_draft(
    p_brand_id UUID,
    p_establishment_name TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_name TEXT := trim(p_establishment_name);
    v_venue_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_name = '' THEN
        RAISE EXCEPTION 'Name can''t be empty.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.brands b
        JOIN public.organizations o ON o.id = b.organization_id
        WHERE b.id = p_brand_id AND o.owner_user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'Brand not found on your account';
    END IF;

    -- Reuse same-name draft/active venue instead of creating a twin chip.
    SELECT v.id INTO v_venue_id
    FROM public.venue_profiles v
    WHERE v.owner_user_id = v_uid
      AND v.deleted_at IS NULL
      AND lower(trim(v.venue_name)) = lower(v_name)
    ORDER BY
        CASE v.status
            WHEN 'approved' THEN 0
            WHEN 'under_review' THEN 1
            ELSE 2
        END,
        v.created_at
    LIMIT 1;

    IF v_venue_id IS NOT NULL THEN
        UPDATE public.profiles
        SET active_venue_id = v_venue_id, updated_at = now()
        WHERE id = v_uid;
        RETURN v_venue_id;
    END IF;

    INSERT INTO public.venue_profiles (
        owner_user_id,
        brand_id,
        venue_name,
        draft_name,
        area,
        category,
        status
    ) VALUES (
        v_uid,
        p_brand_id,
        v_name,
        v_name,
        'pending',
        'dining',
        'under_review'
    )
    RETURNING id INTO v_venue_id;

    UPDATE public.profiles
    SET active_venue_id = v_venue_id, updated_at = now()
    WHERE id = v_uid;

    RETURN v_venue_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_establishment_draft(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_establishment_draft(UUID, TEXT) TO authenticated, service_role;

-- 3) register_venue_location: reuse same owner+name+area
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
    v_name TEXT := regexp_replace(trim(coalesce(p_venue_name, '')), '\s+', ' ', 'g');
    v_area TEXT := regexp_replace(trim(coalesce(p_area, '')), '\s+', ' ', 'g');
    v_label TEXT := regexp_replace(trim(coalesce(p_category, '')), '\s+', ' ', 'g');
    v_offer_category public.offer_category;
    v_brand UUID;
    v_org UUID;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF v_name = '' OR v_area = '' THEN RAISE EXCEPTION 'Venue name and area are required'; END IF;
    IF char_length(v_label) NOT BETWEEN 2 AND 80 THEN RAISE EXCEPTION 'Choose a business category'; END IF;

    SELECT v.id INTO v_venue_id
    FROM public.venue_profiles v
    WHERE v.owner_user_id = v_uid
      AND v.deleted_at IS NULL
      AND lower(trim(v.venue_name)) = lower(v_name)
      AND lower(trim(coalesce(nullif(v.area, ''), 'pending'))) = lower(v_area)
    ORDER BY
        CASE v.status
            WHEN 'approved' THEN 0
            WHEN 'under_review' THEN 1
            ELSE 2
        END,
        v.created_at
    LIMIT 1;

    IF v_venue_id IS NOT NULL THEN
        UPDATE public.profiles
        SET
            active_venue_id = v_venue_id,
            role = CASE
                WHEN role = 'admin'::public.user_role THEN role
                ELSE 'venue'::public.user_role
            END,
            updated_at = now()
        WHERE id = v_uid;
        RETURN v_venue_id;
    END IF;

    SELECT bc.offer_category INTO v_offer_category
    FROM public.business_categories bc
    WHERE lower(bc.slug) = lower(v_label)
       OR lower(bc.name_en) = lower(v_label)
       OR lower(bc.name_tr) = lower(v_label)
    ORDER BY bc.is_active DESC
    LIMIT 1;

    IF v_offer_category IS NULL THEN
        PERFORM public.suggest_business_category(v_label);
        v_offer_category := CASE
            WHEN lower(v_label) ~ '(restaurant|cafe|coffee|food|bakery|restaurant|kafe|yemek)' THEN 'dining'::public.offer_category
            WHEN lower(v_label) ~ '(bar|pub|club|lounge|night|music|event|gece|etkinlik)' THEN 'nightlife'::public.offer_category
            WHEN lower(v_label) ~ '(gym|fitness|sport|yoga|pilates|spor)' THEN 'fitness'::public.offer_category
            WHEN lower(v_label) ~ '(beauty|salon|hair|nail|cosmetic|güzellik|kuaför)' THEN 'beauty'::public.offer_category
            WHEN lower(v_label) ~ '(spa|wellness|hotel|resort|clinic|health|otel|sağlık)' THEN 'wellness'::public.offer_category
            ELSE 'retail'::public.offer_category
        END;
    END IF;

    SELECT b.id INTO v_brand
    FROM public.brands b JOIN public.organizations o ON o.id = b.organization_id
    WHERE o.owner_user_id = v_uid ORDER BY b.created_at LIMIT 1;

    IF v_brand IS NULL THEN
        INSERT INTO public.organizations (owner_user_id, name) VALUES (v_uid, v_name) RETURNING id INTO v_org;
        INSERT INTO public.brands (organization_id, name) VALUES (v_org, v_name) RETURNING id INTO v_brand;
    END IF;

    INSERT INTO public.venue_profiles (
        owner_user_id, brand_id, venue_name, draft_name, area, city, category, categories,
        address, address_line1, contact_name, contact_phone, lat, lng, status,
        details_complete, address_complete
    ) VALUES (
        v_uid, v_brand, v_name, v_name, v_area, v_area, v_offer_category, ARRAY[v_label],
        coalesce(p_address, ''), coalesce(p_address, ''), coalesce(p_contact_name, ''),
        coalesce(p_contact_phone, ''), p_lat, p_lng, 'under_review', true,
        (p_lat IS NOT NULL OR coalesce(p_address, '') <> '')
    ) RETURNING id INTO v_venue_id;

    INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
    VALUES ('venue_application', v_venue_id, v_name, v_area || ' · ' || v_label, 'High', 'open');

    UPDATE public.profiles
    SET
        active_venue_id = v_venue_id,
        role = CASE
            WHEN role = 'admin'::public.user_role THEN role
            ELSE 'venue'::public.user_role
        END,
        updated_at = now()
    WHERE id = v_uid;

    RETURN v_venue_id;
END;
$$;

REVOKE ALL ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;
