-- Open member onboarding, extensible business categories, and easy collaboration requests.

CREATE TABLE IF NOT EXISTS public.business_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    name_en TEXT NOT NULL CHECK (char_length(trim(name_en)) BETWEEN 2 AND 80),
    name_tr TEXT NOT NULL CHECK (char_length(trim(name_tr)) BETWEEN 2 AND 80),
    group_key TEXT NOT NULL DEFAULT 'other',
    offer_category public.offer_category NOT NULL DEFAULT 'retail',
    is_custom BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS business_categories_name_en_uidx
    ON public.business_categories (lower(name_en));

ALTER TABLE public.business_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS business_categories_read ON public.business_categories;
CREATE POLICY business_categories_read ON public.business_categories
    FOR SELECT TO authenticated
    USING (is_active OR created_by = (SELECT auth.uid()) OR public.is_admin());

DROP POLICY IF EXISTS business_categories_admin_manage ON public.business_categories;
DROP POLICY IF EXISTS business_categories_admin_insert ON public.business_categories;
CREATE POLICY business_categories_admin_insert ON public.business_categories
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS business_categories_admin_update ON public.business_categories;
CREATE POLICY business_categories_admin_update ON public.business_categories
    FOR UPDATE TO authenticated
    USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS business_categories_admin_delete ON public.business_categories;
CREATE POLICY business_categories_admin_delete ON public.business_categories
    FOR DELETE TO authenticated USING (public.is_admin());

GRANT SELECT ON public.business_categories TO authenticated;
GRANT ALL ON public.business_categories TO service_role;

INSERT INTO public.business_categories (slug, name_en, name_tr, group_key, offer_category)
VALUES
    ('restaurant', 'Restaurant', 'Restoran', 'food-drink', 'dining'),
    ('cafe', 'Cafe', 'Kafe', 'food-drink', 'dining'),
    ('coffee-shop', 'Coffee shop', 'Kahve dükkanı', 'food-drink', 'dining'),
    ('bakery', 'Bakery', 'Fırın', 'food-drink', 'dining'),
    ('patisserie', 'Patisserie', 'Pastane', 'food-drink', 'dining'),
    ('dessert-shop', 'Dessert shop', 'Tatlıcı', 'food-drink', 'dining'),
    ('fast-food', 'Fast food', 'Fast food', 'food-drink', 'dining'),
    ('food-truck', 'Food truck', 'Yemek kamyonu', 'food-drink', 'dining'),
    ('catering', 'Catering', 'Catering', 'food-drink', 'dining'),
    ('bar-pub', 'Bar / Pub', 'Bar / Pub', 'nightlife', 'nightlife'),
    ('lounge', 'Lounge', 'Lounge', 'nightlife', 'nightlife'),
    ('nightclub', 'Nightclub', 'Gece kulübü', 'nightlife', 'nightlife'),
    ('live-music-venue', 'Live music venue', 'Canlı müzik mekanı', 'nightlife', 'nightlife'),
    ('hotel', 'Hotel', 'Otel', 'hospitality', 'wellness'),
    ('resort', 'Resort', 'Tatil köyü', 'hospitality', 'wellness'),
    ('hostel', 'Hostel', 'Hostel', 'hospitality', 'wellness'),
    ('spa', 'Spa', 'Spa', 'wellness', 'wellness'),
    ('wellness-center', 'Wellness center', 'Wellness merkezi', 'wellness', 'wellness'),
    ('yoga-pilates', 'Yoga / Pilates studio', 'Yoga / Pilates stüdyosu', 'wellness', 'wellness'),
    ('gym-fitness', 'Gym / Fitness center', 'Spor salonu', 'fitness', 'fitness'),
    ('sports-club', 'Sports club', 'Spor kulübü', 'fitness', 'fitness'),
    ('dance-studio', 'Dance studio', 'Dans stüdyosu', 'fitness', 'fitness'),
    ('beauty-salon', 'Beauty salon', 'Güzellik salonu', 'beauty', 'beauty'),
    ('hair-salon', 'Hair salon / Barber', 'Kuaför / Berber', 'beauty', 'beauty'),
    ('nail-studio', 'Nail studio', 'Tırnak stüdyosu', 'beauty', 'beauty'),
    ('cosmetics', 'Cosmetics', 'Kozmetik', 'beauty', 'beauty'),
    ('clinic', 'Clinic', 'Klinik', 'health', 'wellness'),
    ('dentist', 'Dentist', 'Diş kliniği', 'health', 'wellness'),
    ('pharmacy', 'Pharmacy', 'Eczane', 'health', 'wellness'),
    ('fashion', 'Fashion / Clothing', 'Moda / Giyim', 'retail', 'retail'),
    ('shoes-accessories', 'Shoes / Accessories', 'Ayakkabı / Aksesuar', 'retail', 'retail'),
    ('jewelry', 'Jewelry', 'Mücevher', 'retail', 'retail'),
    ('home-decor', 'Home decor / Furniture', 'Ev dekorasyonu / Mobilya', 'retail', 'retail'),
    ('electronics', 'Electronics', 'Elektronik', 'retail', 'retail'),
    ('grocery-market', 'Grocery / Market', 'Market', 'retail', 'retail'),
    ('bookstore', 'Bookstore', 'Kitapçı', 'retail', 'retail'),
    ('concept-store', 'Concept store', 'Konsept mağaza', 'retail', 'retail'),
    ('ecommerce', 'E-commerce / Online store', 'E-ticaret / Online mağaza', 'retail', 'retail'),
    ('cinema-theater', 'Cinema / Theater', 'Sinema / Tiyatro', 'entertainment', 'nightlife'),
    ('museum-gallery', 'Museum / Art gallery', 'Müze / Sanat galerisi', 'culture', 'retail'),
    ('entertainment-center', 'Entertainment center', 'Eğlence merkezi', 'entertainment', 'nightlife'),
    ('event-venue', 'Event venue', 'Etkinlik mekanı', 'events', 'nightlife'),
    ('event-planner', 'Event planner', 'Etkinlik organizasyonu', 'events', 'retail'),
    ('photography-studio', 'Photography / Video studio', 'Fotoğraf / Video stüdyosu', 'creative', 'retail'),
    ('education-training', 'Education / Training', 'Eğitim / Kurs', 'education', 'retail'),
    ('coworking', 'Coworking space', 'Ortak çalışma alanı', 'business-services', 'retail'),
    ('professional-services', 'Professional services', 'Profesyonel hizmetler', 'business-services', 'retail'),
    ('real-estate', 'Real estate', 'Gayrimenkul', 'property', 'retail'),
    ('travel-tourism', 'Travel / Tourism', 'Seyahat / Turizm', 'travel', 'wellness'),
    ('car-dealer-rental', 'Car dealer / Rental', 'Otomotiv / Araç kiralama', 'automotive', 'retail'),
    ('pet-services', 'Pet shop / Pet services', 'Evcil hayvan hizmetleri', 'pets', 'retail'),
    ('kids-family', 'Kids / Family services', 'Çocuk / Aile hizmetleri', 'family', 'retail'),
    ('home-services', 'Home services', 'Ev hizmetleri', 'services', 'retail'),
    ('digital-technology', 'Digital / Technology', 'Dijital / Teknoloji', 'technology', 'retail'),
    ('nonprofit-community', 'Nonprofit / Community', 'STK / Topluluk', 'community', 'retail')
ON CONFLICT (slug) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_tr = EXCLUDED.name_tr,
    group_key = EXCLUDED.group_key,
    offer_category = EXCLUDED.offer_category,
    is_active = true,
    updated_at = now();

CREATE OR REPLACE FUNCTION public.suggest_business_category(p_name TEXT)
RETURNS TABLE (
    id UUID,
    label TEXT,
    group_key TEXT,
    offer_category TEXT,
    is_custom BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_name TEXT := regexp_replace(trim(coalesce(p_name, '')), '\\s+', ' ', 'g');
    v_slug TEXT;
    v_row public.business_categories;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF char_length(v_name) NOT BETWEEN 2 AND 80 THEN
        RAISE EXCEPTION 'Category name must be between 2 and 80 characters';
    END IF;

    SELECT * INTO v_row FROM public.business_categories
    WHERE lower(name_en) = lower(v_name) OR lower(name_tr) = lower(v_name)
    LIMIT 1;

    IF NOT FOUND THEN
        v_slug := trim(both '-' FROM regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
        IF v_slug = '' THEN v_slug := 'custom-' || substr(md5(lower(v_name)), 1, 12); END IF;
        INSERT INTO public.business_categories (
            slug, name_en, name_tr, group_key, offer_category, is_custom, is_active, created_by
        ) VALUES (
            v_slug, v_name, v_name, 'custom', 'retail', true, false, v_uid
        )
        ON CONFLICT (slug) DO UPDATE SET updated_at = now()
        RETURNING * INTO v_row;
    END IF;

    RETURN QUERY SELECT v_row.id, v_name, v_row.group_key,
        v_row.offer_category::TEXT, v_row.is_custom;
END;
$$;

REVOKE ALL ON FUNCTION public.suggest_business_category(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.suggest_business_category(TEXT) TO authenticated, service_role;

-- Business social accounts are optional; selected custom categories are recorded for review.
CREATE OR REPLACE FUNCTION public.upsert_establishment_details(
    p_venue_id UUID,
    p_instagram_handle TEXT,
    p_description TEXT,
    p_categories TEXT[],
    p_contact_name TEXT,
    p_contact_phone TEXT,
    p_contact_is_self BOOLEAN DEFAULT false,
    p_offer_category TEXT DEFAULT 'retail'
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
    v_category_label TEXT;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Establishment not found'; END IF;
    IF v_ig <> '' AND length(v_ig) < 2 THEN RAISE EXCEPTION 'Invalid Instagram handle'; END IF;
    IF v_desc = '' OR length(v_desc) > 200 THEN
        RAISE EXCEPTION 'Description is required (max 200 characters)';
    END IF;
    IF p_categories IS NULL OR array_length(p_categories, 1) IS NULL THEN
        RAISE EXCEPTION 'Choose at least one category';
    END IF;
    IF trim(coalesce(p_contact_name, '')) = '' OR trim(coalesce(p_contact_phone, '')) = '' THEN
        RAISE EXCEPTION 'Contact details are required';
    END IF;

    FOREACH v_category_label IN ARRAY p_categories LOOP
        PERFORM public.suggest_business_category(v_category_label);
    END LOOP;

    UPDATE public.venue_profiles SET
        instagram_handle = v_ig,
        description = v_desc,
        categories = ARRAY(
            SELECT DISTINCT regexp_replace(trim(value), '\\s+', ' ', 'g')
            FROM unnest(p_categories) AS value
            WHERE char_length(trim(value)) BETWEEN 2 AND 80
        ),
        contact_name = trim(p_contact_name),
        contact_phone = trim(p_contact_phone),
        contact_is_self = coalesce(p_contact_is_self, false),
        category = coalesce(nullif(p_offer_category, ''), 'retail')::public.offer_category,
        details_complete = true,
        updated_at = now()
    WHERE id = p_venue_id RETURNING * INTO v_row;
    RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_establishment_details(UUID, TEXT, TEXT, TEXT[], TEXT, TEXT, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_establishment_details(UUID, TEXT, TEXT, TEXT[], TEXT, TEXT, BOOLEAN, TEXT) TO authenticated, service_role;

-- Existing accounts that are not paused can use the member workspace immediately.
ALTER TABLE public.profiles DISABLE TRIGGER guard_profiles_privileged;
ALTER TABLE public.creator_profiles DISABLE TRIGGER guard_creator_profiles_privileged;

UPDATE public.profiles
SET status = 'approved', updated_at = now()
WHERE role = 'creator' AND status = 'under_review';

UPDATE public.creator_profiles
SET status = 'approved', updated_at = now()
WHERE status = 'under_review';

ALTER TABLE public.profiles ENABLE TRIGGER guard_profiles_privileged;
ALTER TABLE public.creator_profiles ENABLE TRIGGER guard_creator_profiles_privileged;

UPDATE public.admin_tasks
SET status = 'approved', resolved_at = coalesce(resolved_at, now())
WHERE type = 'creator_application' AND status = 'open';

-- New members are active immediately; venue approval remains separate per venue profile.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_locale TEXT;
    v_city TEXT;
    v_name TEXT;
    v_handle TEXT;
    v_tiktok TEXT;
    v_invite TEXT;
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_tiktok := coalesce(NEW.raw_user_meta_data ->> 'tiktok_handle', '');
    v_invite := public.normalize_invite_code(coalesce(NEW.raw_user_meta_data ->> 'invite_code', ''));
    v_locale := public.infer_user_locale(NEW.raw_user_meta_data ->> 'locale', v_city, NULL);

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (NEW.id, NEW.email, 'creator', 'approved', v_locale);

    INSERT INTO public.creator_profiles (
        user_id, full_name, instagram_handle, tiktok_handle, city, languages, status
    ) VALUES (
        NEW.id, v_name, v_handle, v_tiktok, v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END,
        'approved'
    );

    PERFORM public.queue_transactional_email(
        NEW.id, NEW.email, 'welcome_application', v_locale,
        jsonb_build_object('name', v_name, 'city', v_city, 'site_url', 'https://marvisociety.com')
    );

    IF v_invite <> '' THEN
        BEGIN
            UPDATE public.referral_codes SET uses_count = uses_count + 1
            WHERE upper(code) = v_invite
              AND (max_uses IS NULL OR uses_count < max_uses)
              AND (invite_email IS NULL OR trim(invite_email) = ''
                   OR lower(trim(invite_email)) = lower(trim(NEW.email)));
            IF FOUND THEN
                UPDATE public.profiles SET referral_code = v_invite WHERE id = NEW.id;
            END IF;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;
    RETURN NEW;
END;
$$;

-- The existing RPC now accepts a canonical key or any owner-provided label.
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
    v_name TEXT := regexp_replace(trim(coalesce(p_venue_name, '')), '\\s+', ' ', 'g');
    v_area TEXT := regexp_replace(trim(coalesce(p_area, '')), '\\s+', ' ', 'g');
    v_label TEXT := regexp_replace(trim(coalesce(p_category, '')), '\\s+', ' ', 'g');
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

    UPDATE public.profiles SET active_venue_id = v_venue_id, updated_at = now() WHERE id = v_uid;
    RETURN v_venue_id;
END;
$$;

REVOKE ALL ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_venue_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;

-- Any active, non-paused member can request a live collaboration. Capacity and duplicate guards remain atomic.
CREATE OR REPLACE FUNCTION public.accept_offer(
    p_offer_id UUID,
    p_shipping_address TEXT DEFAULT NULL,
    p_rsvp_guests INTEGER DEFAULT NULL
)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_creator_user UUID;
    v_creator_status public.membership_status;
    v_profile_status public.membership_status;
    v_offer public.offers;
    v_booking public.bookings;
    v_code TEXT;
    v_venue_user UUID;
BEGIN
    v_creator_id := public.current_creator_id();
    IF v_creator_id IS NULL THEN RAISE EXCEPTION 'Member profile not found'; END IF;
    PERFORM set_config('marvi.allow_booking_mutation', '1', true);

    SELECT cp.user_id, cp.status, p.status
    INTO v_creator_user, v_creator_status, v_profile_status
    FROM public.creator_profiles cp JOIN public.profiles p ON p.id = cp.user_id
    WHERE cp.id = v_creator_id;

    IF v_creator_status = 'paused' OR v_profile_status = 'paused' THEN
        RAISE EXCEPTION 'Membership is paused';
    END IF;

    SELECT * INTO v_offer FROM public.offers
    WHERE id = p_offer_id AND status = 'live' FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Offer not available'; END IF;
    IF v_offer.remaining_slots <= 0 THEN RAISE EXCEPTION 'No slots remaining'; END IF;
    IF v_offer.model = 'gift' AND coalesce(trim(p_shipping_address), '') = '' THEN
        RAISE EXCEPTION 'Shipping address required for gift collaborations';
    END IF;
    IF v_offer.model = 'event' AND coalesce(p_rsvp_guests, 0) < 1 THEN
        RAISE EXCEPTION 'RSVP guest count required for event collaborations';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.bookings
        WHERE offer_id = p_offer_id AND creator_id = v_creator_id AND stage <> 'cancelled'
    ) THEN RAISE EXCEPTION 'Already requested'; END IF;

    v_code := lpad((floor(random() * 9000) + 1000)::TEXT, 4, '0');
    INSERT INTO public.bookings (
        offer_id, creator_id, stage, check_in_code, proof_deadline, proof_deadline_label,
        shipping_address, rsvp_guests
    ) VALUES (
        p_offer_id, v_creator_id, 'invited', v_code,
        coalesce(v_offer.date_end, now() + interval '1 day'),
        coalesce(v_offer.date_label, 'Today') || ', 22:00',
        nullif(trim(p_shipping_address), ''), p_rsvp_guests
    )
    ON CONFLICT (offer_id, creator_id) DO UPDATE SET
        stage = 'invited',
        check_in_code = EXCLUDED.check_in_code,
        proof_deadline = EXCLUDED.proof_deadline,
        proof_deadline_label = EXCLUDED.proof_deadline_label,
        shipping_address = EXCLUDED.shipping_address,
        rsvp_guests = EXCLUDED.rsvp_guests,
        proof_status = 'not_started',
        proof_links = '{}',
        updated_at = now()
    RETURNING * INTO v_booking;

    UPDATE public.offers
    SET remaining_slots = greatest(remaining_slots - 1, 0), updated_at = now()
    WHERE id = p_offer_id;

    INSERT INTO public.collaboration_requests (
        offer_id, creator_id, venue_id, initiated_by, status, booking_id,
        creator_accepted_at, venue_accepted_at
    ) VALUES (
        p_offer_id, v_creator_id, v_offer.venue_id, 'creator', 'pending_venue',
        v_booking.id, now(), NULL
    ) ON CONFLICT (offer_id, creator_id) DO UPDATE SET
        booking_id = EXCLUDED.booking_id, status = 'pending_venue',
        creator_accepted_at = now(), venue_accepted_at = NULL, updated_at = now();

    SELECT owner_user_id INTO v_venue_user FROM public.venue_profiles WHERE id = v_offer.venue_id;
    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        v_creator_user, 'Request sent', 'Waiting for the business to confirm your request.',
        'booking', 'hourglass', 'gold',
        jsonb_build_object('booking_id', v_booking.id, 'offer_id', p_offer_id)
    );
    IF v_venue_user IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            v_venue_user, 'New collaboration request',
            'A member wants to collaborate with your business. Review the request to continue.',
            'collaboration', 'person.badge.plus', 'rose',
            jsonb_build_object('booking_id', v_booking.id, 'offer_id', p_offer_id)
        );
    END IF;

    PERFORM public.log_activity_event(
        'offer_requested', 'booking', v_booking.id, jsonb_build_object('offer_id', p_offer_id)
    );
    RETURN v_booking;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_offer(UUID, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_offer(UUID, TEXT, INTEGER) TO authenticated, service_role;

-- Repair capacity counters from the authoritative non-cancelled bookings.
UPDATE public.offers o
SET remaining_slots = greatest(
        o.capacity - (
            SELECT count(*)::INTEGER
            FROM public.bookings b
            WHERE b.offer_id = o.id AND b.stage <> 'cancelled'
        ),
        0
    ),
    updated_at = now();

INSERT INTO supabase_migrations.schema_migrations (version, name, statements)
VALUES (
    '20260809170901',
    'business_categories_and_open_member_requests',
    ARRAY[]::TEXT[]
)
ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;
