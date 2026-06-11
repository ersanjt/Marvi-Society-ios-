-- Marvi Society — fix production account + dedupe duplicate seed data
-- Run in Supabase Dashboard → SQL Editor
-- Primary account: ersanjt.tab@gmail.com
-- Legacy UUID script below may use an older auth user — prefer grant-admin-ersanjt.sql
--
-- ═══ 0) Production hardening (run once per project) ═══
GRANT SELECT ON public.offers_public TO anon, authenticated;

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
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

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

-- Account deletion (Apple App Store)
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

-- ═══ 1) Your account UUID (from Auth → Users) ═══
-- bbed645c-389a-48e4-a232-4115248d632f

-- Approve creator + enable admin workspace in the app
-- (Use auth user id — profiles.email may be empty so do not rely on email alone.)
UPDATE public.profiles
SET role = 'admin', status = 'approved', email = COALESCE(email, 'ersanjahedtabrizi@gmail.com')
WHERE id = 'bbed645c-389a-48e4-a232-4115248d632f';

-- Ensure creator profile row exists (required for iOS sync)
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

-- ═══ 2) Remove duplicate offers from running seed twice ═══
-- Keeps the oldest row per (venue_id, title)
DELETE FROM public.offers o
USING public.offers o2
WHERE o.venue_id = o2.venue_id
  AND o.title = o2.title
  AND o.created_at > o2.created_at;

-- ═══ 3) Remove duplicate venue profiles (same name + owner) ═══
DELETE FROM public.venue_profiles v
USING public.venue_profiles v2
WHERE v.venue_name = v2.venue_name
  AND v.owner_user_id = v2.owner_user_id
  AND v.created_at > v2.created_at;

-- ═══ 4) Optional: link venues to your account for Venue Studio ═══
-- Only if you want venue workspace — assigns unowned/demo venues to you
-- UPDATE public.venue_profiles
-- SET owner_user_id = 'bbed645c-389a-48e4-a232-4115248d632f', status = 'approved'
-- WHERE owner_user_id != 'bbed645c-389a-48e4-a232-4115248d632f'
--   AND venue_name IN ('Karaköy House', 'Nişantaşı Glow Clinic', 'Kadıköy Brew Lab');

-- ═══ 5) RPC for reliable admin role sync in iOS Profile ═══
CREATE OR REPLACE FUNCTION public.fetch_account_context()
RETURNS TABLE (
    role public.user_role,
    status public.membership_status,
    has_venue_profile BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
        INSERT INTO public.profiles (id, email, role, status)
        SELECT u.id, u.email, 'creator'::public.user_role, 'under_review'::public.membership_status
        FROM auth.users u
        WHERE u.id = v_uid;
    END IF;

    RETURN QUERY
    SELECT
        p.role,
        p.status,
        EXISTS (SELECT 1 FROM public.venue_profiles v WHERE v.owner_user_id = v_uid)
    FROM public.profiles p
    WHERE p.id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_account_context() TO authenticated;

-- ═══ 6) Verify ═══
SELECT 'profiles' AS tbl, email, role, status FROM public.profiles WHERE id = 'bbed645c-389a-48e4-a232-4115248d632f';
SELECT 'creator_profiles' AS tbl, full_name, city, status FROM public.creator_profiles WHERE user_id = 'bbed645c-389a-48e4-a232-4115248d632f';
SELECT 'live offers' AS tbl, COUNT(*) FROM public.offers WHERE status = 'live';
SELECT title, status FROM public.offers WHERE status = 'live' ORDER BY title;
SELECT code FROM public.referral_codes ORDER BY code;
