-- Fix email_outbox auto-dispatch (pg_net http_post) after invite Auth fallback.

CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    v_endpoint TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';

    IF v_url IS NULL OR v_key IS NULL OR length(coalesce(v_url, '')) < 10 OR coalesce(v_key, '') IN ('', 'YOUR_SERVICE_ROLE_KEY') THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured — set marvi_runtime_settings or call send-email manually'
        WHERE id = NEW.id AND status = 'pending';
        RETURN NEW;
    END IF;

    v_endpoint := rtrim(v_url, '/') || '/send-email';

    BEGIN
        PERFORM net.http_post(
            url := v_endpoint,
            body := jsonb_build_object('outbox_id', NEW.id::TEXT),
            params := '{}'::jsonb,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            timeout_milliseconds := 5000
        );
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.email_outbox
        SET error_message = left('Dispatch error: ' || SQLERRM, 500)
        WHERE id = NEW.id AND status = 'pending';
    END;

    RETURN NEW;
END;
$$;

-- Helper: flush pending/failed invite emails by invoking send-email for each row.
CREATE OR REPLACE FUNCTION public.admin_flush_pending_emails(p_limit INTEGER DEFAULT 20)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, net
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
    r RECORD;
    v_count INTEGER := 0;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';
    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE EXCEPTION 'Dispatch settings missing';
    END IF;

    FOR r IN
        SELECT id
        FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
          AND template = 'invite_code'
        ORDER BY created_at ASC
        LIMIT greatest(1, coalesce(p_limit, 20))
    LOOP
        UPDATE public.email_outbox
        SET status = 'pending', error_message = NULL
        WHERE id = r.id;

        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            body := jsonb_build_object('outbox_id', r.id::TEXT),
            params := '{}'::jsonb,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            timeout_milliseconds := 5000
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('queued_dispatches', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_flush_pending_emails(INTEGER) TO authenticated;
