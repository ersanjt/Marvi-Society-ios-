-- ═══════════════════════════════════════════════════════════════════════════
-- Apple Review account — RUN ONLY IN SUPABASE SQL EDITOR (not bash / not WHM)
-- Creates auth user + approved creator profile in one step.
-- Password: MarviReview2026!
-- Invite code for onboarding: MARVI-IST
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
            '{"full_name":"Apple Review","locale":"en"}'::jsonb,
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

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (v_user_id, v_email, 'creator', 'approved', 'en')
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        role = 'creator',
        status = 'approved',
        preferred_locale = 'en',
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
        ARRAY['Dining', 'Lifestyle'],
        ARRAY['English', 'Turkish']
    )
    ON CONFLICT (user_id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        instagram_handle = EXCLUDED.instagram_handle,
        city = 'istanbul',
        status = 'approved',
        updated_at = now();

    RAISE NOTICE 'Review account ready: % (%) password: MarviReview2026!', v_email, v_user_id;
END;
$$;

-- Verify
SELECT 'auth_user' AS check_name, id, email, email_confirmed_at IS NOT NULL AS confirmed
FROM auth.users WHERE email = 'review@marvisociety.com';

SELECT 'profiles' AS check_name, email, role, status
FROM public.profiles WHERE email = 'review@marvisociety.com';

SELECT 'creator' AS check_name, cp.full_name, cp.city, cp.status
FROM public.creator_profiles cp
JOIN auth.users u ON u.id = cp.user_id
WHERE u.email = 'review@marvisociety.com';

SELECT 'offers_live' AS check_name, count(*)::text AS value FROM public.offers WHERE status = 'live';

SELECT 'referral' AS check_name, code, owner_type, uses_count, max_uses
FROM public.referral_codes WHERE code = 'MARVI-IST';
