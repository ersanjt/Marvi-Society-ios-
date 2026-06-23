-- Push outbox + hook admin notifications to remote push delivery

CREATE TABLE IF NOT EXISTS public.push_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_outbox_pending
    ON public.push_outbox (status, created_at)
    WHERE status = 'pending';

ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY push_outbox_admin ON public.push_outbox
    FOR SELECT USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.queue_push_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF p_user_id IS NULL OR coalesce(trim(p_title), '') = '' OR coalesce(trim(p_body), '') = '' THEN
        RETURN NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.device_tokens WHERE user_id = p_user_id) THEN
        RETURN NULL;
    END IF;

    INSERT INTO public.push_outbox (user_id, title, body, payload, status)
    VALUES (p_user_id, trim(p_title), trim(p_body), coalesce(p_payload, '{}'::JSONB), 'pending')
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.queue_push_notification(UUID, TEXT, TEXT, JSONB) TO authenticated;

CREATE OR REPLACE FUNCTION public.dispatch_push_outbox()
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

    BEGIN
        v_url := current_setting('marvi.edge_function_url', true);
        v_key := current_setting('marvi.service_role_key', true);
    EXCEPTION WHEN OTHERS THEN
        RETURN NEW;
    END;

    IF v_url IS NULL OR v_key IS NULL OR length(v_url) < 10 THEN
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object('outbox_id', NEW.id::TEXT)
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_outbox_dispatch ON public.push_outbox;
CREATE TRIGGER push_outbox_dispatch
    AFTER INSERT ON public.push_outbox
    FOR EACH ROW
    EXECUTE FUNCTION public.dispatch_push_outbox();

-- Admin in-app notification also queues APNs when device token exists
CREATE OR REPLACE FUNCTION public.admin_send_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT DEFAULT 'admin'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
    v_type TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only';
    END IF;

    IF coalesce(trim(p_title), '') = '' OR coalesce(trim(p_body), '') = '' THEN
        RAISE EXCEPTION 'Title and body required';
    END IF;

    v_type := coalesce(nullif(trim(p_type), ''), 'admin');

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        p_user_id,
        trim(p_title),
        trim(p_body),
        v_type,
        'bell.fill',
        'rose',
        jsonb_build_object('source', 'admin_console')
    )
    RETURNING id INTO v_id;

    PERFORM public.queue_push_notification(
        p_user_id,
        trim(p_title),
        trim(p_body),
        jsonb_build_object('type', v_type, 'notification_id', v_id::TEXT)
    );

    RETURN v_id;
END;
$$;

-- Allow admins to read device tokens for delivery diagnostics
CREATE POLICY device_tokens_admin_read ON public.device_tokens
    FOR SELECT USING (public.is_admin());
