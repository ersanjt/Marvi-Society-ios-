-- ═══════════════════════════════════════════════════════════════════════════
-- Apple App Review account — RUN IN SUPABASE SQL EDITOR ONLY
-- Email: review@marvisociety.com
-- Password: MarviReview2026!
-- Role: admin (Creator + Venue + Admin workspaces in Profile)
-- Pre-filled: 9+ live offers, approved creator, demo venue profile
-- ═══════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    v_email TEXT := 'review@marvisociety.com';
    v_password TEXT := 'MarviReview2026!';
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE lower(email) = lower(v_email);

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();

        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            recovery_sent_at,
            last_sign_in_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            email_change,
            email_change_token_new,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_email,
            crypt(v_password, gen_salt('bf')),
            NOW(),
            NOW(),
            NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name":"Apple Review","locale":"en","city":"istanbul"}'::jsonb,
            NOW(),
            NOW(),
            '',
            '',
            '',
            ''
        );

        INSERT INTO auth.identities (
            id,
            user_id,
            provider_id,
            identity_data,
            provider,
            last_sign_in_at,
            created_at,
            updated_at
        ) VALUES (
            v_user_id,
            v_user_id,
            v_user_id::text,
            jsonb_build_object('sub', v_user_id::text, 'email', v_email),
            'email',
            NOW(),
            NOW(),
            NOW()
        );
    END IF;

    INSERT INTO public.profiles (id, email, role, status, preferred_locale, referral_code)
    VALUES (v_user_id, v_email, 'admin', 'approved', 'en', 'MARVI-IST')
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        role = 'admin',
        status = 'approved',
        preferred_locale = 'en',
        referral_code = 'MARVI-IST',
        updated_at = now();

    INSERT INTO public.creator_profiles (
        user_id, full_name, instagram_handle, city, status, score, audience_count, proof_rate, niches, languages
    )
    VALUES (
        v_user_id,
        'Apple Review',
        '@marvisociety_review',
        'istanbul',
        'approved',
        90,
        12000,
        98,
        ARRAY['Dining', 'Lifestyle', 'Nightlife'],
        ARRAY['English', 'Turkish']
    )
    ON CONFLICT (user_id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        instagram_handle = EXCLUDED.instagram_handle,
        city = 'istanbul',
        status = 'approved',
        niches = EXCLUDED.niches,
        updated_at = now();

    IF NOT EXISTS (
        SELECT 1 FROM public.venue_profiles WHERE owner_user_id = v_user_id
    ) THEN
        INSERT INTO public.venue_profiles (
            owner_user_id,
            venue_name,
            area,
            category,
            address,
            contact_name,
            status,
            lat,
            lng
        ) VALUES (
            v_user_id,
            'Marvi Review Venue',
            'Karaköy',
            'dining',
            'Karaköy, Istanbul',
            'Apple Review',
            'approved',
            41.0256,
            28.9744
        );
    ELSE
        UPDATE public.venue_profiles
        SET status = 'approved', updated_at = now()
        WHERE owner_user_id = v_user_id;
    END IF;

    -- Demo booking so My Events (Etkinliklerim) is pre-populated for App Review
    INSERT INTO public.bookings (
        offer_id,
        creator_id,
        stage,
        check_in_code,
        proof_deadline,
        proof_deadline_label,
        guest_name,
        proof_status
    )
    SELECT
        o.id,
        cp.id,
        'confirmed',
        '4242',
        COALESCE(o.date_end, now() + interval '2 days'),
        COALESCE(o.date_label, 'Tomorrow') || ', 20:00',
        'Apple Review',
        'not_started'
    FROM public.creator_profiles cp
    JOIN auth.users u ON u.id = cp.user_id
    CROSS JOIN LATERAL (
        SELECT id, date_end, date_label
        FROM public.offers
        WHERE status = 'live'
        ORDER BY created_at DESC
        LIMIT 1
    ) o
    WHERE lower(u.email) = lower(v_email)
    ON CONFLICT (offer_id, creator_id) DO UPDATE SET
        stage = 'confirmed',
        check_in_code = EXCLUDED.check_in_code,
        proof_deadline_label = EXCLUDED.proof_deadline_label,
        updated_at = now();

    RAISE NOTICE 'Review account ready: % (admin + creator + venue + demo booking)', v_email;
END;
$$;

-- Verify
SELECT 'auth_user' AS check_name, id, email, email_confirmed_at IS NOT NULL AS confirmed
FROM auth.users WHERE email = 'review@marvisociety.com';

SELECT 'profiles' AS check_name, email, role, status, referral_code
FROM public.profiles WHERE email = 'review@marvisociety.com';

SELECT 'creator' AS check_name, cp.full_name, cp.city, cp.status
FROM public.creator_profiles cp
JOIN auth.users u ON u.id = cp.user_id
WHERE u.email = 'review@marvisociety.com';

SELECT 'venue' AS check_name, venue_name, area, status
FROM public.venue_profiles vp
JOIN auth.users u ON u.id = vp.owner_user_id
WHERE u.email = 'review@marvisociety.com';

SELECT 'offers_live' AS check_name, count(*)::text AS value FROM public.offers WHERE status = 'live';

SELECT 'bookings' AS check_name, count(*)::text AS value
FROM public.bookings b
JOIN public.creator_profiles cp ON cp.id = b.creator_id
JOIN auth.users u ON u.id = cp.user_id
WHERE u.email = 'review@marvisociety.com';

SELECT 'referral' AS check_name, code, owner_type, uses_count, max_uses
FROM public.referral_codes WHERE code = 'MARVI-IST';
