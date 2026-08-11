-- =============================================================================
-- Marvi Society — DB integrity pack (2026-08-11)
-- Paste in Supabase SQL Editor → Run (project: gaswjuvyzliislqrljof)
-- Idempotent: safe to re-run.
--
-- Fixes:
--  1) Creator profile/photo persistence RPCs (upsert_my_creator_profile, set_my_profile_image)
--  2) Public read for profile-media storage URLs
--  3) business_categories.sort_order (Hotel=10, Restaurant=20, …)
--  4) Integrity diagnostic RPC for ops checks
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Creator profile upsert + image RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_my_creator_profile(
    p_full_name TEXT DEFAULT NULL,
    p_instagram_handle TEXT DEFAULT NULL,
    p_tiktok_handle TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_bio TEXT DEFAULT NULL,
    p_niches TEXT[] DEFAULT NULL,
    p_languages TEXT[] DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL,
    p_cover_url TEXT DEFAULT NULL
)
RETURNS public.creator_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_profile public.creator_profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    PERFORM public.ensure_creator_profile();

    UPDATE public.creator_profiles
    SET
        full_name = COALESCE(NULLIF(trim(p_full_name), ''), full_name),
        instagram_handle = COALESCE(NULLIF(trim(p_instagram_handle), ''), instagram_handle),
        tiktok_handle = COALESCE(NULLIF(trim(p_tiktok_handle), ''), tiktok_handle),
        city = lower(COALESCE(NULLIF(trim(p_city), ''), city, 'istanbul')),
        bio = COALESCE(p_bio, bio),
        niches = COALESCE(p_niches, niches),
        languages = COALESCE(p_languages, languages),
        avatar_url = CASE
            WHEN p_avatar_url IS NULL OR trim(p_avatar_url) = '' THEN avatar_url
            ELSE trim(p_avatar_url)
        END,
        cover_url = CASE
            WHEN p_cover_url IS NULL OR trim(p_cover_url) = '' THEN cover_url
            ELSE trim(p_cover_url)
        END,
        updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_profile;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_my_creator_profile(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT[], TEXT, TEXT
) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_my_profile_image(
    p_kind TEXT,
    p_url TEXT
)
RETURNS public.creator_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_profile public.creator_profiles;
    v_url TEXT := trim(COALESCE(p_url, ''));
    v_kind TEXT := lower(trim(COALESCE(p_kind, '')));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_url = '' THEN
        RAISE EXCEPTION 'Photo URL missing';
    END IF;
    IF v_kind NOT IN ('avatar', 'cover') THEN
        RAISE EXCEPTION 'Invalid image kind';
    END IF;

    PERFORM public.ensure_creator_profile();

    IF v_kind = 'avatar' THEN
        UPDATE public.creator_profiles
        SET avatar_url = v_url, updated_at = now()
        WHERE user_id = v_uid
        RETURNING * INTO v_profile;
    ELSE
        UPDATE public.creator_profiles
        SET cover_url = v_url, updated_at = now()
        WHERE user_id = v_uid
        RETURNING * INTO v_profile;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_my_profile_image(TEXT, TEXT) TO authenticated;

DROP POLICY IF EXISTS profile_media_public_read ON storage.objects;
CREATE POLICY profile_media_public_read ON storage.objects
    FOR SELECT
    USING (bucket_id = 'profile-media');

-- ---------------------------------------------------------------------------
-- 2) Business category sort order (Hotel first, Restaurant second)
-- ---------------------------------------------------------------------------
ALTER TABLE public.business_categories
    ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 1000;

UPDATE public.business_categories SET sort_order = CASE slug
    WHEN 'hotel' THEN 10
    WHEN 'restaurant' THEN 20
    WHEN 'resort' THEN 30
    WHEN 'hostel' THEN 40
    WHEN 'cafe' THEN 50
    WHEN 'coffee-shop' THEN 60
    WHEN 'bakery' THEN 70
    WHEN 'patisserie' THEN 80
    WHEN 'dessert-shop' THEN 90
    WHEN 'fast-food' THEN 100
    WHEN 'food-truck' THEN 110
    WHEN 'catering' THEN 120
    WHEN 'bar-pub' THEN 130
    WHEN 'lounge' THEN 140
    WHEN 'nightclub' THEN 150
    WHEN 'live-music-venue' THEN 160
    WHEN 'spa' THEN 170
    WHEN 'wellness-center' THEN 180
    WHEN 'yoga-pilates' THEN 190
    WHEN 'gym-fitness' THEN 200
    WHEN 'sports-club' THEN 210
    WHEN 'dance-studio' THEN 220
    WHEN 'beauty-salon' THEN 230
    WHEN 'hair-salon' THEN 240
    WHEN 'nail-studio' THEN 250
    WHEN 'cosmetics' THEN 260
    WHEN 'clinic' THEN 270
    WHEN 'dentist' THEN 280
    WHEN 'pharmacy' THEN 290
    WHEN 'fashion' THEN 300
    WHEN 'shoes-accessories' THEN 310
    WHEN 'jewelry' THEN 320
    WHEN 'home-decor' THEN 330
    WHEN 'electronics' THEN 340
    WHEN 'grocery-market' THEN 350
    WHEN 'bookstore' THEN 360
    WHEN 'concept-store' THEN 370
    WHEN 'ecommerce' THEN 380
    WHEN 'cinema-theater' THEN 390
    WHEN 'museum-gallery' THEN 400
    WHEN 'entertainment-center' THEN 410
    WHEN 'event-venue' THEN 420
    WHEN 'event-planner' THEN 430
    WHEN 'photography-studio' THEN 440
    WHEN 'education-training' THEN 450
    WHEN 'coworking' THEN 460
    WHEN 'professional-services' THEN 470
    WHEN 'real-estate' THEN 480
    WHEN 'travel-tourism' THEN 490
    WHEN 'car-dealer-rental' THEN 500
    WHEN 'pet-services' THEN 510
    WHEN 'kids-family' THEN 520
    WHEN 'home-services' THEN 530
    WHEN 'digital-technology' THEN 540
    WHEN 'nonprofit-community' THEN 550
    ELSE 1000
END;

CREATE INDEX IF NOT EXISTS business_categories_active_sort_idx
    ON public.business_categories (is_active, sort_order, name_tr);

-- Ensure canonical seed rows exist (no-op if already present).
INSERT INTO public.business_categories (slug, name_en, name_tr, group_key, offer_category, sort_order)
VALUES
    ('hotel', 'Hotel', 'Otel', 'hospitality', 'wellness', 10),
    ('restaurant', 'Restaurant', 'Restoran', 'food-drink', 'dining', 20),
    ('resort', 'Resort', 'Tatil köyü', 'hospitality', 'wellness', 30),
    ('hostel', 'Hostel', 'Hostel', 'hospitality', 'wellness', 40),
    ('cafe', 'Cafe', 'Kafe', 'food-drink', 'dining', 50),
    ('coffee-shop', 'Coffee shop', 'Kahve dükkanı', 'food-drink', 'dining', 60),
    ('bakery', 'Bakery', 'Fırın', 'food-drink', 'dining', 70),
    ('patisserie', 'Patisserie', 'Pastane', 'food-drink', 'dining', 80),
    ('dessert-shop', 'Dessert shop', 'Tatlıcı', 'food-drink', 'dining', 90),
    ('fast-food', 'Fast food', 'Fast food', 'food-drink', 'dining', 100),
    ('food-truck', 'Food truck', 'Yemek kamyonu', 'food-drink', 'dining', 110),
    ('catering', 'Catering', 'Catering', 'food-drink', 'dining', 120),
    ('bar-pub', 'Bar / Pub', 'Bar / Pub', 'nightlife', 'nightlife', 130),
    ('lounge', 'Lounge', 'Lounge', 'nightlife', 'nightlife', 140),
    ('nightclub', 'Nightclub', 'Gece kulübü', 'nightlife', 'nightlife', 150),
    ('live-music-venue', 'Live music venue', 'Canlı müzik mekanı', 'nightlife', 'nightlife', 160),
    ('spa', 'Spa', 'Spa', 'wellness', 'wellness', 170),
    ('wellness-center', 'Wellness center', 'Wellness merkezi', 'wellness', 'wellness', 180),
    ('yoga-pilates', 'Yoga / Pilates studio', 'Yoga / Pilates stüdyosu', 'wellness', 'wellness', 190),
    ('gym-fitness', 'Gym / Fitness center', 'Spor salonu', 'fitness', 'fitness', 200),
    ('sports-club', 'Sports club', 'Spor kulübü', 'fitness', 'fitness', 210),
    ('dance-studio', 'Dance studio', 'Dans stüdyosu', 'fitness', 'fitness', 220),
    ('beauty-salon', 'Beauty salon', 'Güzellik salonu', 'beauty', 'beauty', 230),
    ('hair-salon', 'Hair salon / Barber', 'Kuaför / Berber', 'beauty', 'beauty', 240),
    ('nail-studio', 'Nail studio', 'Tırnak stüdyosu', 'beauty', 'beauty', 250),
    ('cosmetics', 'Cosmetics', 'Kozmetik', 'beauty', 'beauty', 260),
    ('clinic', 'Clinic', 'Klinik', 'health', 'wellness', 270),
    ('dentist', 'Dentist', 'Diş kliniği', 'health', 'wellness', 280),
    ('pharmacy', 'Pharmacy', 'Eczane', 'health', 'wellness', 290),
    ('fashion', 'Fashion / Clothing', 'Moda / Giyim', 'retail', 'retail', 300),
    ('shoes-accessories', 'Shoes / Accessories', 'Ayakkabı / Aksesuar', 'retail', 'retail', 310),
    ('jewelry', 'Jewelry', 'Mücevher', 'retail', 'retail', 320),
    ('home-decor', 'Home decor / Furniture', 'Ev dekorasyonu / Mobilya', 'retail', 'retail', 330),
    ('electronics', 'Electronics', 'Elektronik', 'retail', 'retail', 340),
    ('grocery-market', 'Grocery / Market', 'Market', 'retail', 'retail', 350),
    ('bookstore', 'Bookstore', 'Kitapçı', 'retail', 'retail', 360),
    ('concept-store', 'Concept store', 'Konsept mağaza', 'retail', 'retail', 370),
    ('ecommerce', 'E-commerce / Online store', 'E-ticaret / Online mağaza', 'retail', 'retail', 380),
    ('cinema-theater', 'Cinema / Theater', 'Sinema / Tiyatro', 'entertainment', 'nightlife', 390),
    ('museum-gallery', 'Museum / Art gallery', 'Müze / Sanat galerisi', 'culture', 'retail', 400),
    ('entertainment-center', 'Entertainment center', 'Eğlence merkezi', 'entertainment', 'nightlife', 410),
    ('event-venue', 'Event venue', 'Etkinlik mekanı', 'events', 'nightlife', 420),
    ('event-planner', 'Event planner', 'Etkinlik organizasyonu', 'events', 'retail', 430),
    ('photography-studio', 'Photography / Video studio', 'Fotoğraf / Video stüdyosu', 'creative', 'retail', 440),
    ('education-training', 'Education / Training', 'Eğitim / Kurs', 'education', 'retail', 450),
    ('coworking', 'Coworking space', 'Ortak çalışma alanı', 'business-services', 'retail', 460),
    ('professional-services', 'Professional services', 'Profesyonel hizmetler', 'business-services', 'retail', 470),
    ('real-estate', 'Real estate', 'Gayrimenkul', 'property', 'retail', 480),
    ('travel-tourism', 'Travel / Tourism', 'Seyahat / Turizm', 'travel', 'wellness', 490),
    ('car-dealer-rental', 'Car dealer / Rental', 'Otomotiv / Araç kiralama', 'automotive', 'retail', 500),
    ('pet-services', 'Pet shop / Pet services', 'Evcil hayvan hizmetleri', 'pets', 'retail', 510),
    ('kids-family', 'Kids / Family services', 'Çocuk / Aile hizmetleri', 'family', 'retail', 520),
    ('home-services', 'Home services', 'Ev hizmetleri', 'services', 'retail', 530),
    ('digital-technology', 'Digital / Technology', 'Dijital / Teknoloji', 'technology', 'retail', 540),
    ('nonprofit-community', 'Nonprofit / Community', 'STK / Topluluk', 'community', 'retail', 550)
ON CONFLICT (slug) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_tr = EXCLUDED.name_tr,
    group_key = EXCLUDED.group_key,
    offer_category = EXCLUDED.offer_category,
    sort_order = EXCLUDED.sort_order,
    is_active = true,
    updated_at = now();

-- ---------------------------------------------------------------------------
-- 3) Ops integrity check (callable with service_role or SQL Editor)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.marvi_db_integrity_check()
RETURNS TABLE (
    check_name TEXT,
    ok BOOLEAN,
    detail TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 'rpc_upsert_my_creator_profile'::TEXT,
           EXISTS (
               SELECT 1 FROM pg_proc p
               JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'upsert_my_creator_profile'
           ),
           'Creator profile save RPC'::TEXT;

    RETURN QUERY
    SELECT 'rpc_set_my_profile_image'::TEXT,
           EXISTS (
               SELECT 1 FROM pg_proc p
               JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'set_my_profile_image'
           ),
           'Creator photo save RPC'::TEXT;

    RETURN QUERY
    SELECT 'col_business_categories_sort_order'::TEXT,
           EXISTS (
               SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'business_categories'
                 AND column_name = 'sort_order'
           ),
           'Hotel/Restaurant sort column'::TEXT;

    RETURN QUERY
    SELECT 'seed_business_categories_count'::TEXT,
           (SELECT COUNT(*) FROM public.business_categories WHERE is_active) >= 50,
           format('active categories=%s', (SELECT COUNT(*) FROM public.business_categories WHERE is_active));

    RETURN QUERY
    SELECT 'hotel_sort_first'::TEXT,
           COALESCE((SELECT slug FROM public.business_categories ORDER BY sort_order ASC, name_tr ASC LIMIT 1), '') = 'hotel',
           format('first=%s', (SELECT slug FROM public.business_categories ORDER BY sort_order ASC, name_tr ASC LIMIT 1));

    RETURN QUERY
    SELECT 'live_offers'::TEXT,
           (SELECT COUNT(*) FROM public.offers WHERE status = 'live') > 0,
           format('live=%s', (SELECT COUNT(*) FROM public.offers WHERE status = 'live'));
END;
$$;

REVOKE ALL ON FUNCTION public.marvi_db_integrity_check() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.marvi_db_integrity_check() TO service_role;

COMMIT;

-- After run, verify in SQL Editor:
--   SELECT * FROM public.marvi_db_integrity_check();
-- Expect all ok = true.
