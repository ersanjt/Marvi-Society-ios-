-- Run in Supabase SQL Editor AFTER migrations and creating your first Auth user.
-- Replace YOUR_AUTH_USER_UUID with the UUID from Authentication → Users.

-- 1) Seed Istanbul demo venues + offers + referral codes
SELECT seed_istanbul_demo('YOUR_AUTH_USER_UUID');

-- 2) Promote your account to admin (for /admin console)
UPDATE public.profiles
SET role = 'admin', status = 'approved'
WHERE id = 'YOUR_AUTH_USER_UUID';

-- 3) Optional: create a test venue owner (run after creating user in Auth dashboard)
-- UPDATE public.profiles SET role = 'venue', status = 'approved' WHERE email = 'venue@example.com';

-- 4) Verify
SELECT venue_name, area, status FROM public.venue_profiles LIMIT 5;
SELECT title, status, model FROM public.offers LIMIT 5;
SELECT code FROM public.referral_codes;
