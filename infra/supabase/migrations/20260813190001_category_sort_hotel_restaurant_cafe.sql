-- Product sort: Hotel → Restaurant → Cafe at the top of business category pickers.
UPDATE public.business_categories SET sort_order = CASE slug
    WHEN 'hotel' THEN 10
    WHEN 'restaurant' THEN 20
    WHEN 'cafe' THEN 30
    WHEN 'coffee-shop' THEN 40
    WHEN 'bakery' THEN 50
    WHEN 'patisserie' THEN 60
    WHEN 'dessert-shop' THEN 70
    WHEN 'fast-food' THEN 80
    WHEN 'food-truck' THEN 90
    WHEN 'catering' THEN 100
    WHEN 'resort' THEN 110
    WHEN 'hostel' THEN 120
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
END,
updated_at = now()
WHERE is_active;

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
    SELECT 'top_categories_order'::TEXT,
           COALESCE((
               SELECT array_agg(slug ORDER BY sort_order ASC, name_tr ASC)
               FROM (
                   SELECT slug, sort_order, name_tr
                   FROM public.business_categories
                   WHERE is_active
                   ORDER BY sort_order ASC, name_tr ASC
                   LIMIT 3
               ) t
           ), ARRAY[]::TEXT[]) = ARRAY['hotel','restaurant','cafe']::TEXT[],
           format('top3=%s', (
               SELECT string_agg(slug, ',' ORDER BY sort_order ASC, name_tr ASC)
               FROM (
                   SELECT slug, sort_order, name_tr
                   FROM public.business_categories
                   WHERE is_active
                   ORDER BY sort_order ASC, name_tr ASC
                   LIMIT 3
               ) t
           ));

    RETURN QUERY
    SELECT 'live_offers'::TEXT,
           (SELECT COUNT(*) FROM public.offers WHERE status = 'live') > 0,
           format('live=%s', (SELECT COUNT(*) FROM public.offers WHERE status = 'live'));
END;
$$;

REVOKE ALL ON FUNCTION public.marvi_db_integrity_check() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.marvi_db_integrity_check() TO service_role;
