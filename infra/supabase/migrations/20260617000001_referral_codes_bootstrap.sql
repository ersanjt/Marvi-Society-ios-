-- Default invite codes + server-side validation (fixes MARVI-IST hyphen filter issues)

INSERT INTO public.referral_codes (code, owner_type, max_uses)
VALUES
    ('MARVI-IST', 'creator', 500),
    ('TURGUT', 'creator', 500),
    ('MARVI2026', 'venue', 100)
ON CONFLICT (code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_code TEXT;
    v_row public.referral_codes%ROWTYPE;
BEGIN
    v_code := upper(trim(p_code));
    IF v_code = '' THEN
        RETURN false;
    END IF;

    SELECT * INTO v_row
    FROM public.referral_codes
    WHERE upper(code) = v_code;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_row.max_uses IS NOT NULL AND v_row.uses_count >= v_row.max_uses THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon, authenticated;
