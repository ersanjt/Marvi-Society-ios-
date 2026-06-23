-- Run in Supabase SQL Editor if invite codes (e.g. marvi-ist) are rejected.
-- Safe to re-run. Only inserts codes — no extra functions required.

INSERT INTO public.referral_codes (code, owner_type, max_uses)
VALUES
    ('MARVI-IST', 'creator', 500),
    ('TURGUT', 'creator', 500),
    ('MARVI2026', 'venue', 100)
ON CONFLICT (code) DO NOTHING;

SELECT code, uses_count, max_uses FROM public.referral_codes ORDER BY code;
