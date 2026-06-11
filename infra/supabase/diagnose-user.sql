-- Marvi Society — find YOUR auth user before granting admin
-- Run in Supabase Dashboard → SQL Editor
-- "Success. No rows returned" on UPDATE = no matching user/profile row was found.

-- ═══ 1) List all auth users (pick your id from here) ═══
SELECT
    id,
    email,
    created_at,
    last_sign_in_at,
    raw_user_meta_data ->> 'instagram_handle' AS instagram
FROM auth.users
ORDER BY created_at DESC
LIMIT 20;

-- ═══ 2) Profiles linked to those users ═══
SELECT
    p.id,
    p.email AS profile_email,
    p.role,
    p.status,
    u.email AS auth_email,
    cp.instagram_handle,
    cp.status AS creator_status
FROM public.profiles p
LEFT JOIN auth.users u ON u.id = p.id
LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
ORDER BY p.created_at DESC
LIMIT 20;

-- ═══ 3) Orphans: auth user exists but NO profiles row ═══
SELECT u.id, u.email
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;

-- ═══ 4) After you copy the correct UUID from step 1, run:
-- UPDATE public.profiles
-- SET role = 'admin', status = 'approved', email = COALESCE(email, u.email)
-- FROM auth.users u
-- WHERE public.profiles.id = u.id
--   AND public.profiles.id = 'PASTE-YOUR-UUID-HERE';
