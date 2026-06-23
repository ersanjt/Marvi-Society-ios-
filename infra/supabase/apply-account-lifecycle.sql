-- Self-service account lifecycle — run in Supabase SQL Editor (safe to re-run)

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS paused_by_self BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS status_before_pause public.membership_status;

CREATE OR REPLACE FUNCTION public.pause_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current public.membership_status;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT status INTO v_current FROM public.profiles WHERE id = v_user_id;
    IF v_current IS NULL THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    IF v_current = 'paused' THEN
        RETURN;
    END IF;

    UPDATE public.profiles
    SET status = 'paused',
        paused_by_self = true,
        status_before_pause = v_current,
        updated_at = now()
    WHERE id = v_user_id;

    UPDATE public.creator_profiles
    SET status = 'paused', updated_at = now()
    WHERE user_id = v_user_id;

    UPDATE public.venue_profiles
    SET status = 'paused', updated_at = now()
    WHERE owner_user_id = v_user_id;

    UPDATE public.bookings b
    SET stage = 'cancelled', updated_at = now()
    FROM public.creator_profiles cp
    WHERE cp.user_id = v_user_id
      AND b.creator_id = cp.id
      AND b.stage IN ('invited', 'confirmed');

    DELETE FROM public.device_tokens WHERE user_id = v_user_id;
    DELETE FROM public.user_location_snapshots WHERE user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reactivate_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_restore public.membership_status;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = v_user_id AND status = 'paused' AND paused_by_self = true
    ) THEN
        RAISE EXCEPTION 'Account cannot be reactivated in-app. Contact support@marvisociety.com.';
    END IF;

    SELECT COALESCE(status_before_pause, 'under_review')
    INTO v_restore
    FROM public.profiles
    WHERE id = v_user_id;

    UPDATE public.profiles
    SET status = v_restore,
        paused_by_self = false,
        status_before_pause = NULL,
        updated_at = now()
    WHERE id = v_user_id;

    UPDATE public.creator_profiles
    SET status = v_restore, updated_at = now()
    WHERE user_id = v_user_id;

    UPDATE public.venue_profiles
    SET status = v_restore, updated_at = now()
    WHERE owner_user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_creator_id := public.current_creator_id();

    DELETE FROM public.device_tokens WHERE user_id = v_user_id;
    DELETE FROM public.user_location_snapshots WHERE user_id = v_user_id;
    DELETE FROM public.saved_offers WHERE user_id = v_user_id;
    DELETE FROM public.notifications WHERE user_id = v_user_id;
    DELETE FROM public.push_outbox WHERE user_id = v_user_id;

    IF v_creator_id IS NOT NULL THEN
        DELETE FROM public.creator_shortlists WHERE creator_id = v_creator_id;
        DELETE FROM public.creator_passes WHERE creator_id = v_creator_id;
        DELETE FROM public.proof_submissions WHERE creator_id = v_creator_id;
        DELETE FROM public.bookings WHERE creator_id = v_creator_id;
        DELETE FROM public.strikes WHERE creator_id = v_creator_id;
    END IF;

    DELETE FROM public.creator_profiles WHERE user_id = v_user_id;
    DELETE FROM public.venue_profiles WHERE owner_user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;

    UPDATE public.deletion_requests
    SET completed_at = now()
    WHERE email = (SELECT email FROM auth.users WHERE id = v_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.pause_own_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.reactivate_own_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

SELECT 'account_lifecycle applied' AS status;
