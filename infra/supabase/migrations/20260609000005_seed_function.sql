-- Runnable Istanbul seed (call after creating venue owner in Auth)

CREATE OR REPLACE FUNCTION public.seed_istanbul_demo(p_owner_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_karakoy UUID;
    v_luma UUID;
    v_kadikoy UUID;
BEGIN
    INSERT INTO public.venue_profiles (owner_user_id, venue_name, area, category, address, status, lat, lng)
    VALUES (p_owner_id, 'Karaköy House', 'Karaköy', 'nightlife', 'Karaköy, Istanbul', 'approved', 41.0256, 28.9744)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.venue_profiles (owner_user_id, venue_name, area, category, address, status, lat, lng)
    VALUES (p_owner_id, 'Nişantaşı Glow Clinic', 'Nişantaşı', 'beauty', 'Nişantaşı, Istanbul', 'approved', 41.0520, 28.9940)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.venue_profiles (owner_user_id, venue_name, area, category, address, status, lat, lng)
    VALUES (p_owner_id, 'Kadıköy Brew Lab', 'Kadıköy', 'dining', 'Kadıköy, Istanbul', 'approved', 40.9903, 29.0244)
    ON CONFLICT DO NOTHING;

    SELECT id INTO v_karakoy FROM public.venue_profiles WHERE venue_name = 'Karaköy House' AND owner_user_id = p_owner_id LIMIT 1;
    SELECT id INTO v_luma FROM public.venue_profiles WHERE venue_name = 'Nişantaşı Glow Clinic' AND owner_user_id = p_owner_id LIMIT 1;
    SELECT id INTO v_kadikoy FROM public.venue_profiles WHERE venue_name = 'Kadıköy Brew Lab' AND owner_user_id = p_owner_id LIMIT 1;

    INSERT INTO public.offers (venue_id, title, category, model, date_label, time_label, value_label, capacity, remaining_slots, description, deliverables, requirements, host_note, status, lat, lng)
    VALUES
        (v_karakoy, 'Sunset Rooftop Preview', 'nightlife', 'event', 'Saturday, Jun 15', '21:00', 'VIP table + drinks', 8, 5,
         'Preview night for summer cocktail program.',
         ARRAY['1 TikTok', '1 Instagram Story set'], ARRAY['Nightlife niche', '21+ only'], 'Check in at host stand.', 'live', 41.0256, 28.9744),
        (v_luma, 'Skin Reset Session', 'beauty', 'gift', 'Flexible', 'Weekdays', '₺1,800 facial', 6, 4,
         'Complimentary facial for before/after content.',
         ARRAY['1 Reel', '1 post'], ARRAY['Beauty niche'], 'Arrive 10 min early.', 'live', 41.0520, 28.9940),
        (v_kadikoy, 'Morning Flat White', 'dining', 'instant', 'Today', 'Anytime', 'Coffee + pastry', 20, 18,
         'Walk-in grab-and-go. Open map, accept, visit within 2 hours.',
         ARRAY['1 Story with location tag'], ARRAY['Within 1 km'], 'Show check-in code at counter.', 'live', 40.9903, 29.0244);

    INSERT INTO public.referral_codes (code, owner_type, max_uses)
    VALUES ('MARVI-IST', 'creator', 500), ('TURGUT', 'creator', 500), ('MARVI2026', 'venue', 100)
    ON CONFLICT (code) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.seed_istanbul_demo(UUID) TO authenticated;
