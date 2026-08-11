-- Minimal DB integrity (safe re-run) — paste in Supabase SQL Editor and Run
BEGIN;

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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_profile public.creator_profiles;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    PERFORM public.ensure_creator_profile();
    UPDATE public.creator_profiles SET
        full_name = COALESCE(NULLIF(trim(p_full_name), ''), full_name),
        instagram_handle = COALESCE(NULLIF(trim(p_instagram_handle), ''), instagram_handle),
        tiktok_handle = COALESCE(NULLIF(trim(p_tiktok_handle), ''), tiktok_handle),
        city = lower(COALESCE(NULLIF(trim(p_city), ''), city, 'istanbul')),
        bio = COALESCE(p_bio, bio),
        niches = COALESCE(p_niches, niches),
        languages = COALESCE(p_languages, languages),
        avatar_url = CASE WHEN p_avatar_url IS NULL OR trim(p_avatar_url) = '' THEN avatar_url ELSE trim(p_avatar_url) END,
        cover_url = CASE WHEN p_cover_url IS NULL OR trim(p_cover_url) = '' THEN cover_url ELSE trim(p_cover_url) END,
        updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_profile;
    IF NOT FOUND THEN RAISE EXCEPTION 'Creator profile not found'; END IF;
    RETURN v_profile;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_my_creator_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT[], TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_my_profile_image(p_kind TEXT, p_url TEXT)
RETURNS public.creator_profiles
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_profile public.creator_profiles;
    v_url TEXT := trim(COALESCE(p_url, ''));
    v_kind TEXT := lower(trim(COALESCE(p_kind, '')));
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF v_url = '' THEN RAISE EXCEPTION 'Photo URL missing'; END IF;
    IF v_kind NOT IN ('avatar', 'cover') THEN RAISE EXCEPTION 'Invalid image kind'; END IF;
    PERFORM public.ensure_creator_profile();
    IF v_kind = 'avatar' THEN
        UPDATE public.creator_profiles SET avatar_url = v_url, updated_at = now() WHERE user_id = v_uid RETURNING * INTO v_profile;
    ELSE
        UPDATE public.creator_profiles SET cover_url = v_url, updated_at = now() WHERE user_id = v_uid RETURNING * INTO v_profile;
    END IF;
    IF NOT FOUND THEN RAISE EXCEPTION 'Creator profile not found'; END IF;
    RETURN v_profile;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_my_profile_image(TEXT, TEXT) TO authenticated;

DROP POLICY IF EXISTS profile_media_public_read ON storage.objects;
CREATE POLICY profile_media_public_read ON storage.objects FOR SELECT USING (bucket_id = 'profile-media');

ALTER TABLE public.business_categories ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 1000;
UPDATE public.business_categories SET sort_order = 10, is_active = true WHERE slug = 'hotel';
UPDATE public.business_categories SET sort_order = 20, is_active = true WHERE slug = 'restaurant';
UPDATE public.business_categories SET sort_order = CASE slug
    WHEN 'resort' THEN 30 WHEN 'hostel' THEN 40 WHEN 'cafe' THEN 50 WHEN 'coffee-shop' THEN 60
    WHEN 'bakery' THEN 70 WHEN 'patisserie' THEN 80 WHEN 'dessert-shop' THEN 90 WHEN 'fast-food' THEN 100
    WHEN 'food-truck' THEN 110 WHEN 'catering' THEN 120 WHEN 'bar-pub' THEN 130 WHEN 'lounge' THEN 140
    WHEN 'nightclub' THEN 150 WHEN 'live-music-venue' THEN 160 WHEN 'spa' THEN 170 WHEN 'wellness-center' THEN 180
    WHEN 'yoga-pilates' THEN 190 WHEN 'gym-fitness' THEN 200 WHEN 'sports-club' THEN 210 WHEN 'dance-studio' THEN 220
    WHEN 'beauty-salon' THEN 230 WHEN 'hair-salon' THEN 240 WHEN 'nail-studio' THEN 250 WHEN 'cosmetics' THEN 260
    WHEN 'clinic' THEN 270 WHEN 'dentist' THEN 280 WHEN 'pharmacy' THEN 290 WHEN 'fashion' THEN 300
    WHEN 'shoes-accessories' THEN 310 WHEN 'jewelry' THEN 320 WHEN 'home-decor' THEN 330 WHEN 'electronics' THEN 340
    WHEN 'grocery-market' THEN 350 WHEN 'bookstore' THEN 360 WHEN 'concept-store' THEN 370 WHEN 'ecommerce' THEN 380
    WHEN 'cinema-theater' THEN 390 WHEN 'museum-gallery' THEN 400 WHEN 'entertainment-center' THEN 410
    WHEN 'event-venue' THEN 420 WHEN 'event-planner' THEN 430 WHEN 'photography-studio' THEN 440
    WHEN 'education-training' THEN 450 WHEN 'coworking' THEN 460 WHEN 'professional-services' THEN 470
    WHEN 'real-estate' THEN 480 WHEN 'travel-tourism' THEN 490 WHEN 'car-dealer-rental' THEN 500
    WHEN 'pet-services' THEN 510 WHEN 'kids-family' THEN 520 WHEN 'home-services' THEN 530
    WHEN 'digital-technology' THEN 540 WHEN 'nonprofit-community' THEN 550 ELSE sort_order END
WHERE slug <> ALL (ARRAY['hotel','restaurant']);

CREATE INDEX IF NOT EXISTS business_categories_active_sort_idx ON public.business_categories (is_active, sort_order, name_tr);

CREATE OR REPLACE FUNCTION public.marvi_db_integrity_check()
RETURNS TABLE (check_name TEXT, ok BOOLEAN, detail TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    RETURN QUERY SELECT 'rpc_upsert_my_creator_profile'::TEXT, EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='upsert_my_creator_profile'), 'profile save'::TEXT;
    RETURN QUERY SELECT 'rpc_set_my_profile_image'::TEXT, EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='set_my_profile_image'), 'photo save'::TEXT;
    RETURN QUERY SELECT 'col_sort_order'::TEXT, EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='business_categories' AND column_name='sort_order'), 'sort column'::TEXT;
    RETURN QUERY SELECT 'hotel_first'::TEXT, COALESCE((SELECT slug FROM public.business_categories WHERE is_active ORDER BY sort_order, name_tr LIMIT 1),'')='hotel', format('first=%s',(SELECT slug FROM public.business_categories WHERE is_active ORDER BY sort_order, name_tr LIMIT 1));
    RETURN QUERY SELECT 'live_offers'::TEXT, (SELECT COUNT(*) FROM public.offers WHERE status='live')>0, format('live=%s',(SELECT COUNT(*) FROM public.offers WHERE status='live'));
END;
$$;
REVOKE ALL ON FUNCTION public.marvi_db_integrity_check() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.marvi_db_integrity_check() TO service_role;

COMMIT;
SELECT * FROM public.marvi_db_integrity_check();
