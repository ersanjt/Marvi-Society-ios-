-- Reliable creator profile writes + restore public profile-media reads.
-- PostgREST PATCH can return success with 0 rows under some RLS/select paths;
-- SECURITY DEFINER RPCs update by auth.uid() and return the saved row.

CREATE OR REPLACE FUNCTION public.upsert_my_creator_profile(
    p_full_name TEXT DEFAULT NULL,
    p_instagram_handle TEXT DEFAULT NULL,
    p_tiktok_handle TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_bio TEXT DEFAULT NULL,
    p_niches TEXT[] DEFAULT NULL,
    p_languages TEXT[] DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL,
    p_cover_url TEXT DEFAULT NULL
)
RETURNS public.creator_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_profile public.creator_profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    PERFORM public.ensure_creator_profile();

    UPDATE public.creator_profiles
    SET
        full_name = COALESCE(NULLIF(trim(p_full_name), ''), full_name),
        instagram_handle = COALESCE(NULLIF(trim(p_instagram_handle), ''), instagram_handle),
        tiktok_handle = COALESCE(NULLIF(trim(p_tiktok_handle), ''), tiktok_handle),
        city = lower(COALESCE(NULLIF(trim(p_city), ''), city, 'istanbul')),
        bio = COALESCE(p_bio, bio),
        niches = COALESCE(p_niches, niches),
        languages = COALESCE(p_languages, languages),
        avatar_url = CASE
            WHEN p_avatar_url IS NULL OR trim(p_avatar_url) = '' THEN avatar_url
            ELSE trim(p_avatar_url)
        END,
        cover_url = CASE
            WHEN p_cover_url IS NULL OR trim(p_cover_url) = '' THEN cover_url
            ELSE trim(p_cover_url)
        END,
        updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_profile;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_my_creator_profile(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT[], TEXT, TEXT
) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_my_profile_image(
    p_kind TEXT,
    p_url TEXT
)
RETURNS public.creator_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_profile public.creator_profiles;
    v_url TEXT := trim(COALESCE(p_url, ''));
    v_kind TEXT := lower(trim(COALESCE(p_kind, '')));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_url = '' THEN
        RAISE EXCEPTION 'Photo URL missing';
    END IF;
    IF v_kind NOT IN ('avatar', 'cover') THEN
        RAISE EXCEPTION 'Invalid image kind';
    END IF;

    PERFORM public.ensure_creator_profile();

    IF v_kind = 'avatar' THEN
        UPDATE public.creator_profiles
        SET avatar_url = v_url, updated_at = now()
        WHERE user_id = v_uid
        RETURNING * INTO v_profile;
    ELSE
        UPDATE public.creator_profiles
        SET cover_url = v_url, updated_at = now()
        WHERE user_id = v_uid
        RETURNING * INTO v_profile;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_my_profile_image(TEXT, TEXT) TO authenticated;

-- App uses /object/public/profile-media/... URLs; public SELECT must allow CDN reads.
DROP POLICY IF EXISTS profile_media_public_read ON storage.objects;
CREATE POLICY profile_media_public_read ON storage.objects
    FOR SELECT
    USING (bucket_id = 'profile-media');
