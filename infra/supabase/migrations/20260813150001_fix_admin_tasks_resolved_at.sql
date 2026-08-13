-- admin_tasks has resolved_at (not updated_at). Fix campaign admin RPCs that
-- failed to publish live offers (Explore empty).

CREATE OR REPLACE FUNCTION public.admin_set_offer_status(
    p_offer_id UUID,
    p_status public.offer_status,
    p_reason TEXT DEFAULT NULL
)
RETURNS public.offers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_offer public.offers;
    v_from public.offer_status;
    v_reason TEXT := nullif(trim(coalesce(p_reason, '')), '');
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;
    IF p_offer_id IS NULL THEN
        RAISE EXCEPTION 'Offer required';
    END IF;
    IF p_status IS NULL THEN
        RAISE EXCEPTION 'Status required';
    END IF;

    SELECT * INTO v_offer FROM public.offers WHERE id = p_offer_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found';
    END IF;
    IF v_offer.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Offer is deleted. Restore it first.';
    END IF;

    v_from := v_offer.status;

    UPDATE public.offers
    SET
        status = p_status,
        admin_block_reason = CASE
            WHEN p_status = 'draft' AND v_from IN ('live', 'review') THEN coalesce(v_reason, admin_block_reason)
            WHEN p_status = 'live' THEN NULL
            ELSE admin_block_reason
        END,
        updated_at = now()
    WHERE id = p_offer_id
    RETURNING * INTO v_offer;

    IF p_status = 'live' THEN
        UPDATE public.admin_tasks
        SET status = 'approved',
            resolved_at = now(),
            assigned_admin_id = auth.uid()
        WHERE type = 'campaign_review'
          AND subject_id = p_offer_id
          AND status = 'open';
    ELSIF p_status = 'draft' AND v_from = 'review' THEN
        UPDATE public.admin_tasks
        SET status = 'rejected',
            resolved_at = now(),
            assigned_admin_id = auth.uid()
        WHERE type = 'campaign_review'
          AND subject_id = p_offer_id
          AND status = 'open';
    END IF;

    PERFORM public.log_activity_event(
        'admin_campaign_status',
        'offer',
        p_offer_id,
        jsonb_build_object(
            'from', v_from,
            'to', p_status,
            'reason', v_reason,
            'title', v_offer.title
        )
    );

    RETURN v_offer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_offer_status(UUID, public.offer_status, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_soft_delete_offer(
    p_offer_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS public.offers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_offer public.offers;
    v_reason TEXT := nullif(trim(coalesce(p_reason, '')), '');
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
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

    UPDATE public.offers
    SET
        deleted_at = now(),
        status = 'completed',
        admin_block_reason = coalesce(v_reason, admin_block_reason, 'Deleted by admin'),
        updated_at = now()
    WHERE id = p_offer_id
    RETURNING * INTO v_offer;

    UPDATE public.admin_tasks
    SET status = 'rejected',
        resolved_at = now(),
        assigned_admin_id = auth.uid()
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
        'admin_campaign_deleted',
        'offer',
        p_offer_id,
        jsonb_build_object(
            'reason', v_reason,
            'title', v_offer.title
        )
    );

    RETURN v_offer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_soft_delete_offer(UUID, TEXT) TO authenticated;
