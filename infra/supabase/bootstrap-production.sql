-- Marvi Society — one-shot production bootstrap (Supabase SQL Editor)
-- Prerequisites: migrations applied (head 20260614000001), user signed in at least once.
--
-- 1) Change the email below to your Auth user
-- 2) Run entire script
-- 3) In app: Profile → Sync from server

DO $$
DECLARE
    v_email TEXT := 'ersanjt.tab@gmail.com';
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE lower(email) = lower(v_email);

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'No auth user for %. Sign in to the iOS app once, then re-run this script.',
            v_email;
    END IF;

    -- Profile + creator row
    INSERT INTO public.profiles (id, email, role, status)
    VALUES (v_user_id, v_email, 'admin', 'approved')
    ON CONFLICT (id) DO UPDATE SET
        role = 'admin',
        status = 'approved',
        email = EXCLUDED.email,
        updated_at = now();

    INSERT INTO public.creator_profiles (
        user_id, full_name, instagram_handle, city, status, score, audience_count, proof_rate, niches, languages
    )
    VALUES (
        v_user_id,
        split_part(v_email, '@', 1),
        '@marvisociety',
        'istanbul',
        'approved',
        88,
        15000,
        97,
        ARRAY['Dining', 'Nightlife'],
        ARRAY['English', 'Turkish']
    )
    ON CONFLICT (user_id) DO UPDATE SET
        status = 'approved',
        city = 'istanbul',
        niches = EXCLUDED.niches,
        languages = EXCLUDED.languages,
        updated_at = now();

    -- Demo venues, live offers, invite codes
    PERFORM public.seed_istanbul_demo(v_user_id);

    RAISE NOTICE 'Bootstrap complete for % (%)', v_email, v_user_id;
END;
$$;

-- Verify
SELECT 'profiles' AS check_name, email, role, status FROM public.profiles ORDER BY updated_at DESC LIMIT 3;
SELECT 'offers_live' AS check_name, count(*) FROM public.offers WHERE status = 'live';
SELECT 'offers_public' AS check_name, count(*) FROM public.offers_public;
SELECT 'referral_codes' AS check_name, code, uses_count, max_uses FROM public.referral_codes ORDER BY code;
