-- Run in Supabase SQL Editor AFTER migrations.
-- Easiest path: use bootstrap-production.sql (email-based, no UUID copy-paste).

-- Or run this after replacing YOUR_EMAIL:
-- SELECT * FROM infra/supabase/bootstrap-production.sql

DO $$
DECLARE
    v_email TEXT := 'ersanjt.tab@gmail.com';
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id FROM auth.users WHERE lower(email) = lower(v_email);
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Sign in to the app with % first.', v_email;
    END IF;
    PERFORM public.seed_istanbul_demo(v_user_id);
    UPDATE public.profiles SET role = 'admin', status = 'approved' WHERE id = v_user_id;
END;
$$;

SELECT venue_name, area, status FROM public.venue_profiles LIMIT 5;
SELECT title, status, model FROM public.offers LIMIT 5;
SELECT code, uses_count FROM public.referral_codes;
