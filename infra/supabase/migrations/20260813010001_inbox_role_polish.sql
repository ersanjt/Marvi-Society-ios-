-- Inbox polish: own-only RLS (admins no longer see everyone's rows) + chat notification dedupe.

DROP POLICY IF EXISTS notifications_own ON public.notifications;

CREATE POLICY notifications_own ON public.notifications
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- One unread "message" notification per conversation (update preview instead of flooding).
CREATE OR REPLACE FUNCTION public.send_message(p_conversation_id UUID, p_body TEXT)
RETURNS public.messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_message public.messages;
    v_body TEXT := trim(p_body);
    v_recipient UUID;
    v_conversation public.conversations;
    v_updated INTEGER := 0;
BEGIN
    IF v_body = '' THEN
        RAISE EXCEPTION 'Message cannot be empty';
    END IF;

    SELECT * INTO v_conversation FROM public.conversations WHERE id = p_conversation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conversation not found';
    END IF;

    IF auth.uid() NOT IN (v_conversation.creator_user_id, v_conversation.venue_user_id) THEN
        RAISE EXCEPTION 'Not a participant';
    END IF;

    INSERT INTO public.messages (conversation_id, sender_user_id, body)
    VALUES (p_conversation_id, auth.uid(), v_body)
    RETURNING * INTO v_message;

    v_recipient := CASE
        WHEN auth.uid() = v_conversation.creator_user_id THEN v_conversation.venue_user_id
        ELSE v_conversation.creator_user_id
    END;

    UPDATE public.notifications
    SET
        body = left(v_body, 120),
        created_at = now(),
        read_at = NULL,
        title = 'New message',
        icon = 'bubble.left.and.bubble.right.fill',
        tint = 'rose',
        payload = jsonb_build_object(
            'conversation_id', p_conversation_id,
            'booking_id', v_conversation.booking_id
        )
    WHERE user_id = v_recipient
      AND type = 'message'
      AND read_at IS NULL
      AND payload->>'conversation_id' = p_conversation_id::text;

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 0 THEN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            v_recipient,
            'New message',
            left(v_body, 120),
            'message',
            'bubble.left.and.bubble.right.fill',
            'rose',
            jsonb_build_object(
                'conversation_id', p_conversation_id,
                'booking_id', v_conversation.booking_id
            )
        );
    END IF;

    PERFORM public.log_activity_event(
        'message_sent',
        'conversation',
        p_conversation_id,
        jsonb_build_object('length', length(v_body))
    );

    RETURN v_message;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_message(UUID, TEXT) TO authenticated;
