-- Venue owners can soft-delete their own campaigns from Studio.

CREATE OR REPLACE FUNCTION public.venue_soft_delete_offer(
    p_offer_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS public.offers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_offer public.offers;
    v_reason TEXT := nullif(trim(coalesce(p_reason, '')), '');
    v_owns BOOLEAN := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF p_offer_id IS NULL THEN
        RAISE EXCEPTION 'Offer required';
    END IF;

    SELECT * INTO v_offer FROM public.offers WHERE id = p_offer_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found';
    END IF;

    IF v_offer.deleted_at IS NOT NULL THEN
        RETURN v_offer;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.venue_profiles vp
        WHERE vp.id = v_offer.venue_id
          AND vp.owner_user_id = v_uid
    ) INTO v_owns;

    IF NOT (v_owns OR public.is_admin()) THEN
        RAISE EXCEPTION 'Not allowed to delete this campaign';
    END IF;

    UPDATE public.offers
    SET
        deleted_at = now(),
        status = 'completed',
        admin_block_reason = coalesce(v_reason, admin_block_reason, 'Deleted by venue'),
        updated_at = now()
    WHERE id = p_offer_id
    RETURNING * INTO v_offer;

    UPDATE public.admin_tasks
    SET status = 'rejected',
        resolved_at = now(),
        assigned_admin_id = coalesce(assigned_admin_id, v_uid)
    WHERE type = 'campaign_review'
      AND subject_id = p_offer_id
      AND status = 'open';

    BEGIN
        PERFORM set_config('marvi.allow_booking_mutation', '1', true);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    UPDATE public.bookings
    SET stage = 'cancelled', updated_at = now()
    WHERE offer_id = p_offer_id
      AND stage IS DISTINCT FROM 'cancelled'
      AND stage IS DISTINCT FROM 'completed';

    PERFORM public.log_activity_event(
        'venue_campaign_deleted',
        'offer',
        p_offer_id,
        jsonb_build_object(
            'reason', v_reason,
            'title', v_offer.title,
            'by', v_uid
        )
    );

    RETURN v_offer;
END;
$$;

REVOKE ALL ON FUNCTION public.venue_soft_delete_offer(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.venue_soft_delete_offer(UUID, TEXT) TO authenticated;
