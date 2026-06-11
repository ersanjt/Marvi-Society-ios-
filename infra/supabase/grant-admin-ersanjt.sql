-- Grant admin to ersanjt.tab@gmail.com
-- Run in Supabase Dashboard → SQL Editor
-- User must exist in Authentication → Users (sign in to the app at least once).

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
            'No auth user for %. Open the iOS app, sign in with this email, then run this script again.',
            v_email;
    END IF;

    INSERT INTO public.profiles (id, email, role, status)
    VALUES (v_user_id, v_email, 'admin', 'approved')
    ON CONFLICT (id) DO UPDATE SET
        role = 'admin',
        status = 'approved',
        email = v_email,
        updated_at = now();

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, status, score, audience_count, proof_rate)
    VALUES (v_user_id, 'Ersan', '@ersanjt', 'istanbul', 'approved', 85, 12000, 96)
    ON CONFLICT (user_id) DO UPDATE SET
        status = 'approved',
        city = 'istanbul',
        updated_at = now();
END;
$$;

-- fetch_account_context RPC (safe to re-run)
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

-- Verify
SELECT
    u.id,
    u.email,
    p.role,
    p.status,
    cp.instagram_handle,
    cp.status AS creator_status
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
LEFT JOIN public.creator_profiles cp ON cp.user_id = u.id
WHERE lower(u.email) = lower('ersanjt.tab@gmail.com');
