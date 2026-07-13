-- Email dispatch config that does not require ALTER DATABASE privileges.

CREATE TABLE IF NOT EXISTS public.marvi_runtime_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.marvi_runtime_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS marvi_runtime_settings_admin ON public.marvi_runtime_settings;
CREATE POLICY marvi_runtime_settings_admin ON public.marvi_runtime_settings
    FOR ALL
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.marvi_runtime_settings TO authenticated;
GRANT ALL ON public.marvi_runtime_settings TO service_role;

CREATE OR REPLACE FUNCTION public.dispatch_email_outbox()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    SELECT value INTO v_url FROM public.marvi_runtime_settings WHERE key = 'edge_function_url';
    SELECT value INTO v_key FROM public.marvi_runtime_settings WHERE key = 'service_role_key';

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 OR v_key IN ('', 'YOUR_SERVICE_ROLE_KEY') THEN
        BEGIN
            v_url := current_setting('marvi.edge_function_url', true);
            v_key := current_setting('marvi.service_role_key', true);
        EXCEPTION WHEN OTHERS THEN
            v_url := NULL;
            v_key := NULL;
        END;
    END IF;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 OR v_key IN ('', 'YOUR_SERVICE_ROLE_KEY') THEN
        UPDATE public.email_outbox
        SET error_message = 'Dispatch not configured — set marvi_runtime_settings edge_function_url + service_role_key, or Database Webhook'
        WHERE id = NEW.id AND status = 'pending';
        RETURN NEW;
    END IF;

    BEGIN
        PERFORM net.http_post(
            url := rtrim(v_url, '/') || '/send-email',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_key
            ),
            body := jsonb_build_object('outbox_id', NEW.id::TEXT)
        );
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.email_outbox
        SET error_message = left('Dispatch error: ' || SQLERRM, 500)
        WHERE id = NEW.id AND status = 'pending';
    END;

    RETURN NEW;
END;
$$;

-- Seed URL (service role key must be set separately with real secret).
INSERT INTO public.marvi_runtime_settings (key, value)
VALUES ('edge_function_url', 'https://gaswjuvyzliislqrljof.supabase.co/functions/v1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
