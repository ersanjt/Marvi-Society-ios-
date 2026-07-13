-- Broaden email flush + tolerate sending claim status; keep dispatch locked down.

-- Stuck "sending" rows (crashed edge workers) can be retried.
UPDATE public.email_outbox
SET status = 'pending',
    error_message = NULL
WHERE status = 'sending'
  AND created_at < now() - interval '10 minutes';

CREATE OR REPLACE FUNCTION public.admin_flush_pending_emails(p_limit INTEGER DEFAULT 40)
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

    -- Recover stuck sends
    UPDATE public.email_outbox
    SET status = 'pending', error_message = NULL
    WHERE status = 'sending'
      AND created_at < now() - interval '5 minutes';

    FOR r IN
        SELECT id
        FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
        ORDER BY created_at ASC
        LIMIT greatest(1, coalesce(p_limit, 40))
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
            timeout_milliseconds := 8000
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('queued_dispatches', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_flush_pending_emails(INTEGER) TO authenticated;

-- Service-role friendly flush via PostgREST (no is_admin gate).
CREATE OR REPLACE FUNCTION public.service_flush_pending_emails(p_limit INTEGER DEFAULT 40)
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
    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';
    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE EXCEPTION 'Dispatch settings missing';
    END IF;

    UPDATE public.email_outbox
    SET status = 'pending', error_message = NULL
    WHERE status = 'sending'
      AND created_at < now() - interval '5 minutes';

    FOR r IN
        SELECT id
        FROM public.email_outbox
        WHERE status IN ('pending', 'failed')
        ORDER BY created_at ASC
        LIMIT greatest(1, coalesce(p_limit, 40))
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
            timeout_milliseconds := 8000
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('queued_dispatches', v_count);
END;
$$;

REVOKE ALL ON FUNCTION public.service_flush_pending_emails(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.service_flush_pending_emails(INTEGER) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.service_flush_pending_emails(INTEGER) TO service_role;
