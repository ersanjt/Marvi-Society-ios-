-- Fix production RPC errors seen in TestFlight:
-- 1) accept_offer(uuid) vs accept_offer(uuid,text,integer) ambiguity
-- 2) resolve_active_venue_id marked STABLE but performs UPDATE

-- Drop legacy single-argument overload (superseded by 3-arg version with defaults).
DROP FUNCTION IF EXISTS public.accept_offer(UUID);

GRANT EXECUTE ON FUNCTION public.accept_offer(UUID, TEXT, INTEGER) TO authenticated;

-- resolve_active_venue_id may UPDATE profiles.active_venue_id — must be VOLATILE.
CREATE OR REPLACE FUNCTION public.resolve_active_venue_id(p_venue_id UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_active UUID;
    v_resolved UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_venue_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = p_venue_id AND v.owner_user_id = v_uid
        ) THEN
            RAISE EXCEPTION 'Venue not found on your account';
        END IF;
        RETURN p_venue_id;
    END IF;

    SELECT p.active_venue_id INTO v_active
    FROM public.profiles p
    WHERE p.id = v_uid;

    IF v_active IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.venue_profiles v
        WHERE v.id = v_active AND v.owner_user_id = v_uid
    ) THEN
        RETURN v_active;
    END IF;

    SELECT v.id INTO v_resolved
    FROM public.venue_profiles v
    WHERE v.owner_user_id = v_uid
    ORDER BY
        CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END,
        v.created_at
    LIMIT 1;

    IF v_resolved IS NULL THEN
        RAISE EXCEPTION 'No venue profile';
    END IF;

    UPDATE public.profiles
    SET active_venue_id = v_resolved, updated_at = now()
    WHERE id = v_uid AND active_venue_id IS DISTINCT FROM v_resolved;

    RETURN v_resolved;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_active_venue_id(UUID) TO authenticated;
