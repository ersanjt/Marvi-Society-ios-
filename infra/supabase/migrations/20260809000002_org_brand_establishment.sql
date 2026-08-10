-- Organization → Brand → Establishment (venue_profiles) hierarchy

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS organizations_owner_name_uidx
    ON public.organizations (owner_user_id, lower(name));

CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS brands_org_name_uidx
    ON public.brands (organization_id, lower(name));

ALTER TABLE public.venue_profiles
    ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES public.brands (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS instagram_handle TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS is_physical BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS country TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS city TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS address_line1 TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS address_line2 TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS postal_code TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS contact_is_self BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS logo_url TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS gallery_urls TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS categories TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS details_complete BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS address_complete BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS photos_complete BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS draft_name TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_venue_profiles_brand ON public.venue_profiles (brand_id);

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS organizations_owner ON public.organizations;
CREATE POLICY organizations_owner ON public.organizations
    FOR ALL USING (owner_user_id = auth.uid() OR public.is_admin())
    WITH CHECK (owner_user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS brands_owner ON public.brands;
CREATE POLICY brands_owner ON public.brands
    FOR ALL USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.organizations o
            WHERE o.id = brands.organization_id AND o.owner_user_id = auth.uid()
        )
    )
    WITH CHECK (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.organizations o
            WHERE o.id = brands.organization_id AND o.owner_user_id = auth.uid()
        )
    );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.organizations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.brands TO authenticated;
GRANT ALL ON public.organizations TO service_role;
GRANT ALL ON public.brands TO service_role;

-- Backfill existing venues into org/brand
DO $$
DECLARE
    r RECORD;
    v_org UUID;
    v_brand UUID;
BEGIN
    FOR r IN
        SELECT DISTINCT ON (owner_user_id) id, owner_user_id, venue_name
        FROM public.venue_profiles
        WHERE brand_id IS NULL
        ORDER BY owner_user_id, created_at
    LOOP
        SELECT id INTO v_org
        FROM public.organizations
        WHERE owner_user_id = r.owner_user_id
        ORDER BY created_at
        LIMIT 1;

        IF v_org IS NULL THEN
            INSERT INTO public.organizations (owner_user_id, name)
            VALUES (r.owner_user_id, coalesce(nullif(trim(r.venue_name), ''), 'My Organization'))
            RETURNING id INTO v_org;
        END IF;

        INSERT INTO public.brands (organization_id, name)
        VALUES (v_org, coalesce(nullif(trim(r.venue_name), ''), 'My Brand'))
        RETURNING id INTO v_brand;

        UPDATE public.venue_profiles
        SET brand_id = v_brand,
            draft_name = venue_name,
            city = CASE WHEN city = '' THEN area ELSE city END,
            address_line1 = CASE WHEN address_line1 = '' THEN address ELSE address_line1 END,
            details_complete = true,
            address_complete = (coalesce(lat, 0) <> 0 OR address <> ''),
            photos_complete = false
        WHERE owner_user_id = r.owner_user_id AND brand_id IS NULL;
    END LOOP;
END;
$$;

-- Tighten venue-media uploads to owner folder
DROP POLICY IF EXISTS "venue media upload" ON storage.objects;
DROP POLICY IF EXISTS venue_media_upload ON storage.objects;
DROP POLICY IF EXISTS venue_media_public_read ON storage.objects;
DROP POLICY IF EXISTS venue_media_insert ON storage.objects;
DROP POLICY IF EXISTS venue_media_update ON storage.objects;
DROP POLICY IF EXISTS venue_media_select ON storage.objects;
DROP POLICY IF EXISTS venue_media_delete ON storage.objects;

CREATE POLICY venue_media_insert ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY venue_media_update ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage upsert requires SELECT in addition to INSERT and UPDATE.
CREATE POLICY venue_media_select ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY venue_media_delete ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'venue-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_organization_with_brand(
    p_organization_name TEXT,
    p_brand_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_org public.organizations;
    v_brand public.brands;
    v_org_name TEXT := trim(p_organization_name);
    v_brand_name TEXT := trim(p_brand_name);
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_org_name = '' OR v_brand_name = '' THEN
        RAISE EXCEPTION 'Organization and brand names are required';
    END IF;

    INSERT INTO public.organizations (owner_user_id, name)
    VALUES (v_uid, v_org_name)
    RETURNING * INTO v_org;

    INSERT INTO public.brands (organization_id, name)
    VALUES (v_org.id, v_brand_name)
    RETURNING * INTO v_brand;

    RETURN jsonb_build_object(
        'organization_id', v_org.id,
        'organization_name', v_org.name,
        'brand_id', v_brand.id,
        'brand_name', v_brand.name
    );
END;
$$;

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

CREATE OR REPLACE FUNCTION public.upsert_establishment_details(
    p_venue_id UUID,
    p_instagram_handle TEXT,
    p_description TEXT,
    p_categories TEXT[],
    p_contact_name TEXT,
    p_contact_phone TEXT,
    p_contact_is_self BOOLEAN DEFAULT false,
    p_offer_category TEXT DEFAULT 'dining'
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_ig TEXT := lower(trim(both '@' FROM coalesce(p_instagram_handle, '')));
    v_desc TEXT := trim(coalesce(p_description, ''));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF v_ig = '' OR length(v_ig) < 2 THEN
        RAISE EXCEPTION 'Invalid Instagram handle';
    END IF;
    IF v_desc = '' OR length(v_desc) > 200 THEN
        RAISE EXCEPTION 'Description is required (max 200 characters)';
    END IF;
    IF p_categories IS NULL OR array_length(p_categories, 1) IS NULL THEN
        RAISE EXCEPTION 'Choose at least one category';
    END IF;
    IF trim(coalesce(p_contact_name, '')) = '' OR trim(coalesce(p_contact_phone, '')) = '' THEN
        RAISE EXCEPTION 'Contact details are required';
    END IF;

    UPDATE public.venue_profiles
    SET
        instagram_handle = v_ig,
        description = v_desc,
        categories = p_categories,
        contact_name = trim(p_contact_name),
        contact_phone = trim(p_contact_phone),
        contact_is_self = coalesce(p_contact_is_self, false),
        category = coalesce(p_offer_category, 'dining')::public.offer_category,
        details_complete = true,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_establishment_address(
    p_venue_id UUID,
    p_is_physical BOOLEAN,
    p_country TEXT,
    p_city TEXT,
    p_location_label TEXT,
    p_address_line1 TEXT,
    p_address_line2 TEXT DEFAULT '',
    p_postal_code TEXT DEFAULT '',
    p_lat DOUBLE PRECISION DEFAULT NULL,
    p_lng DOUBLE PRECISION DEFAULT NULL
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_city TEXT := trim(coalesce(p_city, ''));
    v_country TEXT := trim(coalesce(p_country, ''));
    v_line1 TEXT := trim(coalesce(p_address_line1, ''));
    v_area TEXT := trim(coalesce(p_location_label, v_city));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF coalesce(p_is_physical, true) THEN
        IF v_country = '' OR v_city = '' OR v_line1 = '' THEN
            RAISE EXCEPTION 'Country, city, and address are required for physical venues';
        END IF;
        IF p_lat IS NULL OR p_lng IS NULL THEN
            RAISE EXCEPTION 'Locate the venue on the map';
        END IF;
    ELSE
        IF v_country = '' OR v_city = '' THEN
            RAISE EXCEPTION 'Country and city are required';
        END IF;
    END IF;

    UPDATE public.venue_profiles
    SET
        is_physical = coalesce(p_is_physical, true),
        country = v_country,
        city = v_city,
        area = CASE WHEN v_area = '' THEN v_city ELSE v_area END,
        address_line1 = v_line1,
        address_line2 = trim(coalesce(p_address_line2, '')),
        postal_code = trim(coalesce(p_postal_code, '')),
        address = trim(concat_ws(', ', nullif(v_line1, ''), nullif(trim(coalesce(p_address_line2, '')), ''), nullif(v_city, ''), nullif(v_country, ''))),
        lat = p_lat,
        lng = p_lng,
        address_complete = true,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_establishment_photos(
    p_venue_id UUID,
    p_logo_url TEXT,
    p_gallery_urls TEXT[]
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_gallery TEXT[] := coalesce(p_gallery_urls, '{}');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF trim(coalesce(p_logo_url, '')) = '' THEN
        RAISE EXCEPTION 'Upload your establishment logo';
    END IF;
    IF array_length(v_gallery, 1) IS NULL OR array_length(v_gallery, 1) < 3 THEN
        RAISE EXCEPTION 'Upload at least 3 photos';
    END IF;

    UPDATE public.venue_profiles
    SET
        logo_url = trim(p_logo_url),
        gallery_urls = v_gallery,
        photos_complete = true,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_establishment_for_review(p_venue_id UUID)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
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

    IF trim(v_row.venue_name) = '' AND trim(v_row.draft_name) = '' THEN
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
        WHERE type = 'venue_application' AND subject_id = v_row.id AND status = 'open'
    ) THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority, status)
        VALUES (
            'venue_application',
            v_row.id,
            v_row.venue_name,
            coalesce(nullif(v_row.city, ''), v_row.area) || ' · establishment submitted for review',
            'High',
            'open'
        );
    END IF;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_my_brands()
RETURNS TABLE (
    organization_id UUID,
    organization_name TEXT,
    brand_id UUID,
    brand_name TEXT
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
    SELECT o.id, o.name, b.id, b.name
    FROM public.organizations o
    JOIN public.brands b ON b.organization_id = o.id
    WHERE o.owner_user_id = auth.uid()
    ORDER BY o.created_at, b.created_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_establishment_draft(p_venue_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.venue_profiles;
BEGIN
    SELECT * INTO v_row
    FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    RETURN to_jsonb(v_row);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_organization_with_brand(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_establishment_draft(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_establishment_details(UUID, TEXT, TEXT, TEXT[], TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_establishment_address(UUID, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_establishment_photos(UUID, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_establishment_for_review(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_my_brands() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_establishment_draft(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.create_organization_with_brand(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_establishment_draft(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_establishment_details(UUID, TEXT, TEXT, TEXT[], TEXT, TEXT, BOOLEAN, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_establishment_address(UUID, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_establishment_photos(UUID, TEXT, TEXT[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_establishment_for_review(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fetch_my_brands() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fetch_establishment_draft(UUID) FROM PUBLIC;

-- Keep legacy register_venue_location working: auto-create brand if needed
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
    v_brand UUID;
    v_org UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_name = '' OR v_area = '' THEN
        RAISE EXCEPTION 'Venue name and area are required';
    END IF;

    SELECT b.id INTO v_brand
    FROM public.brands b
    JOIN public.organizations o ON o.id = b.organization_id
    WHERE o.owner_user_id = v_uid
    ORDER BY b.created_at
    LIMIT 1;

    IF v_brand IS NULL THEN
        INSERT INTO public.organizations (owner_user_id, name)
        VALUES (v_uid, v_name)
        RETURNING id INTO v_org;

        INSERT INTO public.brands (organization_id, name)
        VALUES (v_org, v_name)
        RETURNING id INTO v_brand;
    END IF;

    INSERT INTO public.venue_profiles (
        owner_user_id,
        brand_id,
        venue_name,
        draft_name,
        area,
        city,
        category,
        address,
        address_line1,
        contact_name,
        contact_phone,
        lat,
        lng,
        status,
        details_complete,
        address_complete
    ) VALUES (
        v_uid,
        v_brand,
        v_name,
        v_name,
        v_area,
        v_area,
        p_category::public.offer_category,
        COALESCE(p_address, ''),
        COALESCE(p_address, ''),
        COALESCE(p_contact_name, ''),
        COALESCE(p_contact_phone, ''),
        p_lat,
        p_lng,
        'under_review'::public.membership_status,
        true,
        (p_lat IS NOT NULL OR coalesce(p_address, '') <> '')
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

REVOKE ALL ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
