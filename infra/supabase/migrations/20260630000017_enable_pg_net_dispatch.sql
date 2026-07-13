-- Enable pg_net for outbox dispatch + lock down runtime settings (no client-readable secrets).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Ensure search_path can resolve net.* helpers used by pg_net.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'net') THEN
        -- Older/newer pg_net variants may install functions under extensions only.
        NULL;
    END IF;
END $$;

REVOKE ALL ON public.marvi_runtime_settings FROM authenticated;
REVOKE ALL ON public.marvi_runtime_settings FROM PUBLIC;
DROP POLICY IF EXISTS marvi_runtime_settings_admin ON public.marvi_runtime_settings;
-- No policies for authenticated: only service_role / SECURITY DEFINER can read.

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
        SET error_message = 'Dispatch not configured — set marvi_runtime_settings or Database Webhook to send-email'
        WHERE id = NEW.id AND status = 'pending';
        RETURN NEW;
    END IF;

    v_endpoint := rtrim(v_url, '/') || '/send-email';

    BEGIN
        -- Prefer net.http_post when schema exists; otherwise extensions.http_post.
        IF to_regprocedure('net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer)') IS NOT NULL THEN
            PERFORM net.http_post(
                url := v_endpoint,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_key
                ),
                body := jsonb_build_object('outbox_id', NEW.id::TEXT)
            );
        ELSIF to_regprocedure('extensions.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer)') IS NOT NULL THEN
            PERFORM extensions.http_post(
                url := v_endpoint,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_key
                ),
                body := jsonb_build_object('outbox_id', NEW.id::TEXT)
            );
        ELSE
            UPDATE public.email_outbox
            SET error_message = 'pg_net http_post unavailable — create Database Webhook on email_outbox INSERT'
            WHERE id = NEW.id AND status = 'pending';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.email_outbox
        SET error_message = left('Dispatch error: ' || SQLERRM, 500)
        WHERE id = NEW.id AND status = 'pending';
    END;

    RETURN NEW;
END;
$$;
