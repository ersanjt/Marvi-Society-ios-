-- Business / venue registration must lock the account into the venue workspace.
-- Previously register_venue_location left profiles.role as creator, and iOS then
-- exposed both Creator + Mekân switches whenever a venue profile existed.

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

-- Existing business accounts that registered a venue but stayed on creator role.
-- Bypass privilege guard (migrations are not an admin JWT session).
ALTER TABLE public.profiles DISABLE TRIGGER guard_profiles_privileged;
UPDATE public.profiles p
SET
    role = 'venue'::public.user_role,
    updated_at = now()
WHERE p.role = 'creator'::public.user_role
  AND EXISTS (
      SELECT 1
      FROM public.venue_profiles vp
      WHERE vp.owner_user_id = p.id
  );
ALTER TABLE public.profiles ENABLE TRIGGER guard_profiles_privileged;
