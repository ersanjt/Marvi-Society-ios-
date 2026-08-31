-- Social events (follow, direct message, profile comment) write in-app
-- notifications so the existing push-outbox trigger can deliver APNs.

CREATE OR REPLACE FUNCTION public.actor_display_name(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name TEXT;
BEGIN
    SELECT coalesce(
        nullif(trim(cp.full_name), ''),
        nullif(trim(vp.venue_name), ''),
        'Someone'
    )
    INTO v_name
    FROM public.profiles p
    LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
    LEFT JOIN LATERAL (
        SELECT vp2.venue_name
        FROM public.venue_profiles vp2
        WHERE vp2.owner_user_id = p.id
          AND vp2.deleted_at IS NULL
        ORDER BY CASE vp2.status WHEN 'approved' THEN 0 ELSE 1 END,
                 vp2.updated_at DESC NULLS LAST
        LIMIT 1
    ) vp ON true
    WHERE p.id = p_user_id;

    RETURN coalesce(nullif(trim(v_name), ''), 'Someone');
END;
$$;

REVOKE ALL ON FUNCTION public.actor_display_name(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.actor_display_name(UUID) TO authenticated, service_role;

-- Insert or refresh an unread row, and queue push even when we only update.
CREATE OR REPLACE FUNCTION public.upsert_unread_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT,
    p_icon TEXT,
    p_tint TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB,
    p_match_key TEXT DEFAULT NULL,
    p_match_value TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
    v_title TEXT := nullif(trim(coalesce(p_title, '')), '');
    v_body TEXT := left(coalesce(p_body, ''), 180);
    v_type TEXT := nullif(trim(coalesce(p_type, '')), '');
    v_updated INTEGER := 0;
BEGIN
    IF p_user_id IS NULL OR v_title IS NULL OR v_type IS NULL THEN
        RETURN NULL;
    END IF;

    IF p_match_key IS NOT NULL AND p_match_value IS NOT NULL THEN
        UPDATE public.notifications
        SET
            title = v_title,
            body = v_body,
            icon = coalesce(nullif(trim(p_icon), ''), icon),
            tint = coalesce(nullif(trim(p_tint), ''), tint),
            payload = coalesce(p_payload, '{}'::JSONB),
            created_at = now(),
            read_at = NULL
        WHERE user_id = p_user_id
          AND type = v_type
          AND read_at IS NULL
          AND payload ->> p_match_key = p_match_value
        RETURNING id INTO v_id;

        GET DIAGNOSTICS v_updated = ROW_COUNT;
    END IF;

    IF v_updated > 0 AND v_id IS NOT NULL THEN
        BEGIN
            PERFORM public.queue_push_notification(
                p_user_id,
                v_title,
                v_body,
                coalesce(p_payload, '{}'::JSONB)
                    || jsonb_build_object(
                        'notification_id', v_id,
                        'type', v_type,
                        'icon', coalesce(p_icon, ''),
                        'tint', coalesce(p_tint, '')
                    )
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
        RETURN v_id;
    END IF;

    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
    VALUES (
        p_user_id,
        v_title,
        v_body,
        v_type,
        coalesce(nullif(trim(p_icon), ''), 'bell.fill'),
        coalesce(nullif(trim(p_tint), ''), 'rose'),
        coalesce(p_payload, '{}'::JSONB)
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_unread_notification(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_unread_notification(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT
) TO service_role;

-- Booking chat: reuse unread row, still fire a push on later messages.
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

    PERFORM public.upsert_unread_notification(
        v_recipient,
        'New message',
        left(v_body, 120),
        'message',
        'bubble.left.and.bubble.right.fill',
        'rose',
        jsonb_build_object(
            'conversation_id', p_conversation_id,
            'booking_id', v_conversation.booking_id
        ),
        'conversation_id',
        p_conversation_id::TEXT
    );

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

-- Follow → inbox + push for the person being followed.
CREATE OR REPLACE FUNCTION public.follows_queue_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    BEGIN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            NEW.followee_id,
            'New follower',
            public.actor_display_name(NEW.follower_id) || ' started following you.',
            'follow',
            'person.badge.plus',
            'rose',
            jsonb_build_object('follower_id', NEW.follower_id)
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_follows_queue_notification ON public.follows;
CREATE TRIGGER trg_follows_queue_notification
AFTER INSERT ON public.follows
FOR EACH ROW
EXECUTE FUNCTION public.follows_queue_notification();

-- Community DMs → inbox + push (one unread row per thread).
CREATE OR REPLACE FUNCTION public.direct_messages_queue_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recipient UUID;
BEGIN
    SELECT CASE
        WHEN t.user_low = NEW.sender_user_id THEN t.user_high
        ELSE t.user_low
    END
    INTO v_recipient
    FROM public.direct_threads t
    WHERE t.id = NEW.thread_id;

    IF v_recipient IS NULL OR v_recipient = NEW.sender_user_id THEN
        RETURN NEW;
    END IF;

    BEGIN
        PERFORM public.upsert_unread_notification(
            v_recipient,
            'New message',
            left(NEW.body, 120),
            'message',
            'bubble.left.and.bubble.right.fill',
            'rose',
            jsonb_build_object(
                'thread_id', NEW.thread_id,
                'conversation_id', NEW.thread_id,
                'sender_id', NEW.sender_user_id
            ),
            'thread_id',
            NEW.thread_id::TEXT
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_direct_messages_queue_notification ON public.direct_messages;
CREATE TRIGGER trg_direct_messages_queue_notification
AFTER INSERT ON public.direct_messages
FOR EACH ROW
EXECUTE FUNCTION public.direct_messages_queue_notification();

-- Profile comments → inbox + push.
CREATE OR REPLACE FUNCTION public.profile_comments_queue_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.target_user_id = NEW.author_user_id THEN
        RETURN NEW;
    END IF;

    BEGIN
        INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
        VALUES (
            NEW.target_user_id,
            'New comment',
            public.actor_display_name(NEW.author_user_id) || ' commented on your profile.',
            'comment',
            'text.bubble.fill',
            'gold',
            jsonb_build_object(
                'author_id', NEW.author_user_id,
                'comment_id', NEW.id,
                'showcase_id', NEW.showcase_id
            )
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profile_comments_queue_notification ON public.profile_comments;
CREATE TRIGGER trg_profile_comments_queue_notification
AFTER INSERT ON public.profile_comments
FOR EACH ROW
EXECUTE FUNCTION public.profile_comments_queue_notification();
