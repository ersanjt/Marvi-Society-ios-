-- Apple App Store review account bootstrap
-- ⚠️  Run ONLY in Supabase SQL Editor — NOT bash scripts here.
-- Prefer: infra/supabase/provision-review-account.sql (creates auth user + profile in one step)

DO $$
DECLARE
    v_email TEXT := 'review@marvisociety.com';
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE lower(email) = lower(v_email);

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'No auth user for %. Run: bash scripts/app-store/provision-review-account.sh (or sign up once in the app), then re-run this SQL.',
            v_email;
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

    -- Mark referral as redeemed if user used MARVI-IST at signup
    UPDATE public.referral_codes
    SET uses_count = GREATEST(uses_count, 1)
    WHERE code = 'MARVI-IST' AND uses_count = 0;

    RAISE NOTICE 'Review account ready: % (%)', v_email, v_user_id;
END;
$$;

SELECT 'profiles' AS check_name, email, role, status FROM public.profiles WHERE email = 'review@marvisociety.com';
SELECT 'creator' AS check_name, full_name, city, status FROM public.creator_profiles cp
JOIN auth.users u ON u.id = cp.user_id WHERE u.email = 'review@marvisociety.com';
SELECT 'offers_live' AS check_name, count(*) FROM public.offers WHERE status = 'live';
SELECT 'referral_creator' AS check_name, code, owner_type, uses_count, max_uses FROM public.referral_codes WHERE code = 'MARVI-IST';
