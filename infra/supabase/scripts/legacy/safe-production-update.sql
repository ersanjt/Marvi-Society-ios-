-- ═══════════════════════════════════════════════════════════════════════════
-- Marvi Society — SAFE production update (idempotent)
-- Run this in Supabase SQL Editor when schema ALREADY exists.
--
-- ⛔ DO NOT run initial_schema / ALL_MIGRATIONS_COMBINED again.
--    Error "type user_role already exists" = schema is fine; skip migrations.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) iOS Explore view access
GRANT SELECT ON public.offers_public TO anon, authenticated;

-- 2) Self-healing creator profile on sign-in
CREATE OR REPLACE FUNCTION public.ensure_creator_profile()
RETURNS public.creator_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user auth.users%ROWTYPE;
    v_profile public.creator_profiles;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    SELECT * INTO v_profile FROM public.creator_profiles WHERE user_id = auth.uid();
    IF FOUND THEN RETURN v_profile; END IF;
    SELECT * INTO v_user FROM auth.users WHERE id = auth.uid();
    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, status)
    VALUES (
        auth.uid(),
        COALESCE(v_user.raw_user_meta_data ->> 'full_name', ''),
        COALESCE(v_user.raw_user_meta_data ->> 'instagram_handle', ''),
        COALESCE(v_user.raw_user_meta_data ->> 'city', 'istanbul'),
        'under_review'
    )
    ON CONFLICT (user_id) DO UPDATE SET updated_at = now()
    RETURNING * INTO v_profile;
    RETURN v_profile;
END;
$$;
GRANT EXECUTE ON FUNCTION public.ensure_creator_profile() TO authenticated;

-- 3) Account deletion (Apple App Store)
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    v_creator_id := public.current_creator_id();
    DELETE FROM public.saved_offers WHERE user_id = v_user_id;
    DELETE FROM public.notifications WHERE user_id = v_user_id;
    IF v_creator_id IS NOT NULL THEN
        DELETE FROM public.proof_submissions WHERE creator_id = v_creator_id;
        DELETE FROM public.bookings WHERE creator_id = v_creator_id;
        DELETE FROM public.strikes WHERE creator_id = v_creator_id;
    END IF;
    DELETE FROM public.creator_profiles WHERE user_id = v_user_id;
    DELETE FROM public.venue_profiles WHERE owner_user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;
    UPDATE public.deletion_requests SET completed_at = now()
    WHERE email = (SELECT email FROM auth.users WHERE id = v_user_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- 4) Your production account (ersanjahedtabrizi@gmail.com)
UPDATE public.profiles
SET role = 'admin', status = 'approved'
WHERE id = 'bbed645c-389a-48e4-a232-4115248d632f';

INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, status, score, audience_count, proof_rate)
VALUES (
    'bbed645c-389a-48e4-a232-4115248d632f',
    'Ersan Jahed',
    '@ersanjahedtabrizi',
    'istanbul',
    'approved',
    85,
    12000,
    96
)
ON CONFLICT (user_id) DO UPDATE SET
    status = 'approved',
    city = 'istanbul',
    full_name = EXCLUDED.full_name,
    instagram_handle = EXCLUDED.instagram_handle;

-- 5) Dedupe duplicate seed rows (safe to re-run)
DELETE FROM public.offers o
USING public.offers o2
WHERE o.venue_id = o2.venue_id
  AND o.title = o2.title
  AND o.created_at > o2.created_at;

DELETE FROM public.venue_profiles v
USING public.venue_profiles v2
WHERE v.venue_name = v2.venue_name
  AND v.owner_user_id = v2.owner_user_id
  AND v.created_at > v2.created_at;

-- 6) Verify (read results below)
SELECT 'profiles' AS check_name, email, role, status
FROM public.profiles WHERE id = 'bbed645c-389a-48e4-a232-4115248d632f';

SELECT 'creator_profiles' AS check_name, full_name, city, status
FROM public.creator_profiles WHERE user_id = 'bbed645c-389a-48e4-a232-4115248d632f';

SELECT 'live_offers_count' AS check_name, COUNT(*)::text AS value
FROM public.offers WHERE status = 'live';

SELECT 'referral_codes' AS check_name, code FROM public.referral_codes ORDER BY code;
