-- Production hardening: public offers view grants + self-healing creator profile

-- Mobile clients read live offers through this view.
GRANT SELECT ON public.offers_public TO anon, authenticated;

-- Heal missing creator_profiles row (e.g. users created before trigger).
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

    SELECT * INTO v_profile
    FROM public.creator_profiles
    WHERE user_id = auth.uid();

    IF FOUND THEN
        RETURN v_profile;
    END IF;

    SELECT * INTO v_user FROM auth.users WHERE id = auth.uid();

    INSERT INTO public.creator_profiles (
        user_id,
        full_name,
        instagram_handle,
        city,
        status
    ) VALUES (
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
