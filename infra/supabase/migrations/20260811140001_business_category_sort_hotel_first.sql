-- Product sort: Hotel first, Restaurant second, then remaining catalog.
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
