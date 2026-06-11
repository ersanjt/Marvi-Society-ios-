-- Grant admin to the account you actually use in the iOS app
-- Step 1: Run diagnose-user.sql and copy your id from auth.users
-- Step 2: Replace PASTE_USER_ID below, then Run

DO $$
DECLARE
    v_user_id UUID := 'PASTE_USER_ID'::UUID;  -- e.g. bbed645c-389a-48e4-a232-4115248d632f
    v_email TEXT;
BEGIN
    SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'No auth.users row for id %. Run diagnose-user.sql first.', v_user_id;
    END IF;

    INSERT INTO public.profiles (id, email, role, status)
    VALUES (v_user_id, v_email, 'admin', 'approved')
    ON CONFLICT (id) DO UPDATE SET
        role = 'admin',
        status = 'approved',
        email = COALESCE(public.profiles.email, EXCLUDED.email),
        updated_at = now();

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, city, status)
    VALUES (v_user_id, '', '', 'istanbul', 'approved')
    ON CONFLICT (user_id) DO UPDATE SET
        status = 'approved',
        updated_at = now();

    RAISE NOTICE 'Admin granted for % (%)', v_email, v_user_id;
END;
$$;

-- Verify (should show role = admin)
SELECT p.id, u.email, p.role, p.status, cp.status AS creator_status
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
WHERE p.id = 'PASTE_USER_ID'::UUID;
