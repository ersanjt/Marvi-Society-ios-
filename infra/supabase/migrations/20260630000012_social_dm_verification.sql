-- Per-user social verification code: user DMs code to @marvisociety from their Instagram account.

ALTER TYPE public.admin_task_type ADD VALUE IF NOT EXISTS 'social_verification';

ALTER TABLE public.creator_profiles
    ADD COLUMN IF NOT EXISTS social_verification_code TEXT,
    ADD COLUMN IF NOT EXISTS social_verification_issued_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS social_verification_instagram_handle TEXT,
    ADD COLUMN IF NOT EXISTS social_verification_tiktok_handle TEXT,
    ADD COLUMN IF NOT EXISTS social_verification_submitted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS social_verification_verified_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS idx_creator_profiles_social_verification_code
    ON public.creator_profiles (social_verification_code)
    WHERE social_verification_code IS NOT NULL;

CREATE OR REPLACE FUNCTION public.normalize_social_handle(p_handle TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT lower(trim(regexp_replace(coalesce(p_handle, ''), '^@+', '')));
$$;

CREATE OR REPLACE FUNCTION public._new_social_verification_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_code TEXT;
BEGIN
    LOOP
        v_code := 'MARVI-' || upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 6));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.creator_profiles WHERE social_verification_code = v_code
        );
    END LOOP;
    RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_social_verification_code()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.creator_profiles%ROWTYPE;
    v_ig TEXT;
    v_tt TEXT;
    v_status TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row
    FROM public.creator_profiles
    WHERE user_id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    v_ig := public.normalize_social_handle(v_row.instagram_handle);
    v_tt := public.normalize_social_handle(v_row.tiktok_handle);

    IF v_ig = '' OR v_tt = '' THEN
        RETURN jsonb_build_object(
            'status', 'needs_handles',
            'instagram_handle', v_row.instagram_handle,
            'tiktok_handle', coalesce(v_row.tiktok_handle, ''),
            'tiktok_handle_required', true,
            'marvi_instagram', 'marvisociety'
        );
    END IF;

    IF v_row.social_verification_verified_at IS NOT NULL
        AND public.normalize_social_handle(v_row.social_verification_instagram_handle) = v_ig
        AND public.normalize_social_handle(v_row.social_verification_tiktok_handle) = v_tt THEN
        v_status := 'verified';
    ELSIF v_row.social_verification_code IS NULL
        OR public.normalize_social_handle(v_row.social_verification_instagram_handle) IS DISTINCT FROM v_ig
        OR public.normalize_social_handle(v_row.social_verification_tiktok_handle) IS DISTINCT FROM v_tt THEN
        UPDATE public.creator_profiles
        SET social_verification_code = public._new_social_verification_code(),
            social_verification_issued_at = now(),
            social_verification_instagram_handle = v_ig,
            social_verification_tiktok_handle = v_tt,
            social_verification_submitted_at = NULL,
            social_verification_verified_at = NULL,
            updated_at = now()
        WHERE user_id = v_uid
        RETURNING * INTO v_row;
        v_status := 'pending';
    ELSIF v_row.social_verification_submitted_at IS NOT NULL THEN
        v_status := 'submitted';
    ELSE
        v_status := 'pending';
    END IF;

    RETURN jsonb_build_object(
        'status', v_status,
        'code', v_row.social_verification_code,
        'instagram_handle', v_row.instagram_handle,
        'tiktok_handle', coalesce(v_row.tiktok_handle, ''),
        'marvi_instagram', 'marvisociety',
        'issued_at', v_row.social_verification_issued_at,
        'submitted_at', v_row.social_verification_submitted_at,
        'verified_at', v_row.social_verification_verified_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_social_verification_code() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_social_verification_dm()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.creator_profiles%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row
    FROM public.creator_profiles
    WHERE user_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    IF v_row.social_verification_code IS NULL
        OR public.normalize_social_handle(v_row.instagram_handle) = ''
        OR public.normalize_social_handle(v_row.tiktok_handle) = '' THEN
        RAISE EXCEPTION 'Save Instagram and TikTok handles first';
    END IF;

    IF v_row.social_verification_verified_at IS NOT NULL THEN
        RETURN public.ensure_social_verification_code();
    END IF;

    UPDATE public.creator_profiles
    SET social_verification_submitted_at = now(),
        updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

    IF NOT EXISTS (
        SELECT 1 FROM public.admin_tasks
        WHERE type = 'social_verification'
          AND subject_id = v_uid
          AND status = 'open'
    ) THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
        VALUES (
            'social_verification',
            v_uid,
            'Instagram DM verification',
            '@' || v_row.social_verification_instagram_handle
                || ' · TikTok @' || v_row.social_verification_tiktok_handle
                || ' · code ' || v_row.social_verification_code,
            'High'
        );
    END IF;

    RETURN public.ensure_social_verification_code();
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_social_verification_dm() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_verify_social_dm(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.creator_profiles%ROWTYPE;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    UPDATE public.creator_profiles
    SET social_verification_verified_at = now(),
        social_verification_instagram_handle = public.normalize_social_handle(instagram_handle),
        social_verification_tiktok_handle = public.normalize_social_handle(tiktok_handle),
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator profile not found';
    END IF;

    UPDATE public.admin_tasks
    SET status = 'approved',
        resolved_at = now()
    WHERE subject_id = p_user_id
      AND type = 'social_verification'
      AND status = 'open';

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'verified_at', v_row.social_verification_verified_at,
        'instagram_handle', v_row.instagram_handle,
        'tiktok_handle', v_row.tiktok_handle
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_verify_social_dm(UUID) TO authenticated;
