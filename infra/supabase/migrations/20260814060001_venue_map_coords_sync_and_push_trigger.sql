-- Propagate venue coords to live offers + auto-queue push for every in-app notification.

CREATE OR REPLACE FUNCTION public.upsert_establishment_address(
    p_venue_id UUID,
    p_is_physical BOOLEAN,
    p_country TEXT,
    p_city TEXT,
    p_location_label TEXT,
    p_address_line1 TEXT,
    p_address_line2 TEXT DEFAULT '',
    p_postal_code TEXT DEFAULT '',
    p_lat DOUBLE PRECISION DEFAULT NULL,
    p_lng DOUBLE PRECISION DEFAULT NULL
)
RETURNS public.venue_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_row public.venue_profiles;
    v_city TEXT := trim(coalesce(p_city, ''));
    v_country TEXT := trim(coalesce(p_country, ''));
    v_line1 TEXT := trim(coalesce(p_address_line1, ''));
    v_area TEXT := trim(coalesce(p_location_label, v_city));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_row FROM public.venue_profiles
    WHERE id = p_venue_id AND owner_user_id = v_uid
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Establishment not found';
    END IF;

    IF coalesce(p_is_physical, true) THEN
        IF v_country = '' OR v_city = '' OR v_line1 = '' THEN
            RAISE EXCEPTION 'Country, city, and address are required for physical venues';
        END IF;
        IF p_lat IS NULL OR p_lng IS NULL THEN
            RAISE EXCEPTION 'Locate the venue on the map';
        END IF;
        IF p_lat < -90 OR p_lat > 90 OR p_lng < -180 OR p_lng > 180 THEN
            RAISE EXCEPTION 'Invalid map coordinates';
        END IF;
    ELSE
        IF v_country = '' OR v_city = '' THEN
            RAISE EXCEPTION 'Country and city are required';
        END IF;
    END IF;

    UPDATE public.venue_profiles
    SET
        is_physical = coalesce(p_is_physical, true),
        country = v_country,
        city = v_city,
        area = CASE WHEN v_area = '' THEN v_city ELSE v_area END,
        address_line1 = v_line1,
        address_line2 = trim(coalesce(p_address_line2, '')),
        postal_code = trim(coalesce(p_postal_code, '')),
        address = trim(concat_ws(', ', nullif(v_line1, ''), nullif(trim(coalesce(p_address_line2, '')), ''), nullif(v_city, ''), nullif(v_country, ''))),
        lat = p_lat,
        lng = p_lng,
        address_complete = true,
        updated_at = now()
    WHERE id = p_venue_id
    RETURNING * INTO v_row;

    -- Keep Explore / Discover map pins in sync with the venue location.
    IF p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
        UPDATE public.offers
        SET lat = p_lat,
            lng = p_lng
        WHERE venue_id = p_venue_id
          AND deleted_at IS NULL
          AND status IN ('live', 'review', 'draft');
    END IF;

    RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_establishment_address(
    UUID, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.upsert_establishment_address(
    UUID, BOOLEAN, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION
) TO authenticated, service_role;

-- Every in-app notification also attempts a push (device token + dispatch must be configured).
CREATE OR REPLACE FUNCTION public.notifications_queue_push()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    BEGIN
        PERFORM public.queue_push_notification(
            NEW.user_id,
            NEW.title,
            left(coalesce(NEW.body, ''), 180),
            coalesce(NEW.payload, '{}'::jsonb)
                || jsonb_build_object(
                    'notification_id', NEW.id,
                    'type', NEW.type,
                    'icon', NEW.icon,
                    'tint', NEW.tint
                )
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_queue_push ON public.notifications;
CREATE TRIGGER trg_notifications_queue_push
AFTER INSERT ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.notifications_queue_push();
