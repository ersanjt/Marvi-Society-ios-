-- Istanbul demo seed (run after migrations in dev/staging)
-- Uses fixed UUIDs for reproducible mobile testing

-- Demo admin user must be created in Supabase Auth dashboard first, then:
-- UPDATE public.profiles SET role = 'admin', status = 'approved' WHERE email = 'admin@marvisociety.com';

INSERT INTO public.venue_profiles (
    id, owner_user_id, venue_name, area, category, address, status, lat, lng
) VALUES
    (
        'a1000001-0000-4000-8000-000000000001',
        '00000000-0000-0000-0000-000000000001', -- placeholder; replace after auth seed
        'Karaköy House',
        'Karaköy',
        'dining',
        'Kemankeş Karamustafa Paşa, Istanbul',
        'approved',
        41.0256,
        28.9744
    ),
    (
        'a1000001-0000-4000-8000-000000000002',
        '00000000-0000-0000-0000-000000000001',
        'Bosphorus Terrace',
        'Beşiktaş',
        'nightlife',
        'Beşiktaş, Istanbul',
        'approved',
        41.0422,
        29.0067
    ),
    (
        'a1000001-0000-4000-8000-000000000003',
        '00000000-0000-0000-0000-000000000001',
        'Nişantaşı Glow Clinic',
        'Nişantaşı',
        'beauty',
        'Nişantaşı, Istanbul',
        'approved',
        41.0520,
        28.9940
    )
ON CONFLICT DO NOTHING;

INSERT INTO public.offers (
    id, venue_id, title, category, model, date_label, time_label, value_label,
    capacity, remaining_slots, description, deliverables, requirements, host_note, status
) VALUES
    (
        'b2000001-0000-4000-8000-000000000001',
        'a1000001-0000-4000-8000-000000000001',
        'Chef''s Table Tasting',
        'dining',
        'invitation',
        'Friday, Jun 14',
        '19:30',
        '₺2,400 tasting menu',
        4, 2,
        'Seasonal tasting menu for two creators with photography-friendly plating.',
        ARRAY['1 Instagram Reel', '2 Story frames with venue tag'],
        ARRAY['Minimum 8K followers', 'Food or lifestyle niche', 'Smart casual dress'],
        'Ask for the mezzanine table for best lighting.',
        'live'
    ),
    (
        'b2000001-0000-4000-8000-000000000002',
        'a1000001-0000-4000-8000-000000000002',
        'Sunset Rooftop Preview',
        'nightlife',
        'event',
        'Saturday, Jun 15',
        '21:00',
        'VIP table + drinks',
        8, 5,
        'Preview night for new summer cocktail program.',
        ARRAY['1 TikTok', '1 Instagram Story set'],
        ARRAY['Nightlife or lifestyle niche', '21+ only'],
        'Check in at the host stand with your code.',
        'live'
    ),
    (
        'b2000001-0000-4000-8000-000000000003',
        'a1000001-0000-4000-8000-000000000003',
        'Skin Reset Session',
        'beauty',
        'gift',
        'Flexible',
        'Any weekday',
        '₺1,800 facial',
        6, 4,
        'Complimentary facial in exchange for before/after content.',
        ARRAY['1 Reel', '1 static post'],
        ARRAY['Beauty niche preferred', 'No filters on before/after'],
        'Arrive 10 minutes early for consultation photos.',
        'live'
    ),
    (
        'b2000001-0000-4000-8000-000000000004',
        'a1000001-0000-4000-8000-000000000001',
        'Morning Flat White',
        'dining',
        'instant',
        'Today',
        'Anytime',
        'Coffee + pastry',
        20, 18,
        'Walk-in collaboration for nearby creators. Open the map and check in.',
        ARRAY['1 Story with location tag'],
        ARRAY['Within 500m', 'Post within 2 hours'],
        'Show this screen at the counter.',
        'live'
    )
ON CONFLICT DO NOTHING;
