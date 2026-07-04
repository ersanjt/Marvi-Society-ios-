-- Full social layer: direct messages, profile comments, venue discovery.

-- ---------------------------------------------------------------------------
-- 1. Direct messaging (any approved member ↔ member)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.direct_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_low UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    user_high UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT direct_threads_ordered CHECK (user_low < user_high),
    CONSTRAINT direct_threads_unique UNIQUE (user_low, user_high)
);

CREATE INDEX IF NOT EXISTS idx_direct_threads_user_low ON public.direct_threads (user_low);
CREATE INDEX IF NOT EXISTS idx_direct_threads_user_high ON public.direct_threads (user_high);

CREATE TABLE IF NOT EXISTS public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES public.direct_threads (id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT direct_messages_body_not_empty CHECK (length(trim(body)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_direct_messages_thread
    ON public.direct_messages (thread_id, created_at ASC);

ALTER TABLE public.direct_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS direct_threads_select ON public.direct_threads;
CREATE POLICY direct_threads_select ON public.direct_threads
    FOR SELECT USING (user_low = auth.uid() OR user_high = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS direct_messages_select ON public.direct_messages;
CREATE POLICY direct_messages_select ON public.direct_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.direct_threads t
            WHERE t.id = direct_messages.thread_id
              AND (t.user_low = auth.uid() OR t.user_high = auth.uid() OR public.is_admin())
        )
    );

DROP POLICY IF EXISTS direct_messages_insert ON public.direct_messages;
CREATE POLICY direct_messages_insert ON public.direct_messages
    FOR INSERT WITH CHECK (
        sender_user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.direct_threads t
            WHERE t.id = thread_id
              AND (t.user_low = auth.uid() OR t.user_high = auth.uid())
        )
    );

GRANT SELECT ON public.direct_threads TO authenticated;
GRANT SELECT, INSERT ON public.direct_messages TO authenticated;

CREATE OR REPLACE FUNCTION public.ensure_direct_thread(p_target UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := auth.uid();
    v_low UUID;
    v_high UUID;
    v_thread_id UUID;
BEGIN
    IF v_me IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF p_target IS NULL OR p_target = v_me THEN
        RAISE EXCEPTION 'Invalid recipient';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = p_target AND p.status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Recipient not available';
    END IF;

    v_low := LEAST(v_me, p_target);
    v_high := GREATEST(v_me, p_target);

    SELECT id INTO v_thread_id
    FROM public.direct_threads
    WHERE user_low = v_low AND user_high = v_high;

    IF FOUND THEN
        RETURN v_thread_id;
    END IF;

    INSERT INTO public.direct_threads (user_low, user_high)
    VALUES (v_low, v_high)
    RETURNING id INTO v_thread_id;

    RETURN v_thread_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_direct_thread(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_direct_threads()
RETURNS TABLE (
    id UUID,
    peer_user_id UUID,
    peer_name TEXT,
    peer_handle TEXT,
    last_message TEXT,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := auth.uid();
BEGIN
    IF v_me IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        t.id,
        CASE WHEN t.user_low = v_me THEN t.user_high ELSE t.user_low END AS peer_user_id,
        coalesce(cp.full_name, vp.venue_name, 'Member') AS peer_name,
        coalesce(cp.instagram_handle, vp.venue_name, '') AS peer_handle,
        (
            SELECT m.body FROM public.direct_messages m
            WHERE m.thread_id = t.id
            ORDER BY m.created_at DESC
            LIMIT 1
        ),
        (
            SELECT m.created_at FROM public.direct_messages m
            WHERE m.thread_id = t.id
            ORDER BY m.created_at DESC
            LIMIT 1
        ),
        t.created_at
    FROM public.direct_threads t
    LEFT JOIN public.creator_profiles cp ON cp.user_id = CASE WHEN t.user_low = v_me THEN t.user_high ELSE t.user_low END
    LEFT JOIN public.venue_profiles vp ON vp.owner_user_id = CASE WHEN t.user_low = v_me THEN t.user_high ELSE t.user_low END
        AND cp.id IS NULL
    WHERE t.user_low = v_me OR t.user_high = v_me
    ORDER BY coalesce(
        (SELECT max(m.created_at) FROM public.direct_messages m WHERE m.thread_id = t.id),
        t.created_at
    ) DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_direct_threads() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_direct_messages(p_thread_id UUID)
RETURNS SETOF public.direct_messages
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT m.*
    FROM public.direct_messages m
    JOIN public.direct_threads t ON t.id = m.thread_id
    WHERE m.thread_id = p_thread_id
      AND (t.user_low = auth.uid() OR t.user_high = auth.uid() OR public.is_admin())
    ORDER BY m.created_at ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_direct_messages(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.send_direct_message(p_thread_id UUID, p_body TEXT)
RETURNS public.direct_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_body TEXT := trim(p_body);
    v_row public.direct_messages;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_body = '' THEN
        RAISE EXCEPTION 'Message required';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.direct_threads t
        WHERE t.id = p_thread_id
          AND (t.user_low = auth.uid() OR t.user_high = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Thread not found';
    END IF;

    INSERT INTO public.direct_messages (thread_id, sender_user_id, body)
    VALUES (p_thread_id, auth.uid(), v_body)
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_direct_message(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Profile comments (public notes on a member profile)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    showcase_id UUID REFERENCES public.creator_showcase (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT profile_comments_body_not_empty CHECK (length(trim(body)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_profile_comments_target
    ON public.profile_comments (target_user_id, created_at DESC);

ALTER TABLE public.profile_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_comments_select ON public.profile_comments;
CREATE POLICY profile_comments_select ON public.profile_comments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS profile_comments_insert ON public.profile_comments;
CREATE POLICY profile_comments_insert ON public.profile_comments
    FOR INSERT WITH CHECK (
        author_user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = target_user_id AND p.status = 'approved'
        )
    );

GRANT SELECT, INSERT ON public.profile_comments TO authenticated;

CREATE OR REPLACE FUNCTION public.list_profile_comments(
    p_target_user_id UUID,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    id UUID,
    author_user_id UUID,
    author_name TEXT,
    body TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.author_user_id,
        coalesce(cp.full_name, cp.instagram_handle, 'Member') AS author_name,
        c.body,
        c.created_at
    FROM public.profile_comments c
    LEFT JOIN public.creator_profiles cp ON cp.user_id = c.author_user_id
    WHERE c.target_user_id = p_target_user_id
    ORDER BY c.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 30), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_profile_comments(UUID, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.add_profile_comment(
    p_target_user_id UUID,
    p_body TEXT,
    p_showcase_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_body TEXT := trim(p_body);
    v_row public.profile_comments;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_body = '' THEN
        RAISE EXCEPTION 'Comment required';
    END IF;
    IF p_target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot comment on your own profile';
    END IF;

    INSERT INTO public.profile_comments (target_user_id, author_user_id, body, showcase_id)
    VALUES (p_target_user_id, auth.uid(), v_body, p_showcase_id)
    RETURNING * INTO v_row;

    RETURN jsonb_build_object('id', v_row.id, 'created_at', v_row.created_at);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_profile_comment(UUID, TEXT, UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Venue public profile
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_venue_public_profile(p_venue_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_venue public.venue_profiles;
    v_followers INT;
    v_following INT;
    v_is_following BOOLEAN;
    v_offers JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_venue FROM public.venue_profiles WHERE id = p_venue_id;
    IF NOT FOUND OR v_venue.status <> 'approved' THEN
        RETURN NULL;
    END IF;

    SELECT count(*) INTO v_followers FROM public.follows WHERE followee_id = v_venue.owner_user_id;
    SELECT count(*) INTO v_following FROM public.follows WHERE follower_id = v_venue.owner_user_id;
    SELECT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = auth.uid() AND followee_id = v_venue.owner_user_id
    ) INTO v_is_following;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', o.id,
        'title', o.title,
        'area', v_venue.area,
        'category', o.category::TEXT,
        'remaining_slots', o.remaining_slots
    ) ORDER BY o.created_at DESC), '[]'::JSONB)
    INTO v_offers
    FROM public.offers o
    WHERE o.venue_id = v_venue.id
      AND o.status = 'live'
    LIMIT 12;

    RETURN jsonb_build_object(
        'venue_id', v_venue.id,
        'owner_user_id', v_venue.owner_user_id,
        'venue_name', v_venue.venue_name,
        'area', v_venue.area,
        'category', v_venue.category::TEXT,
        'address', v_venue.address,
        'followers', v_followers,
        'following', v_following,
        'is_following', v_is_following,
        'live_offers', v_offers
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_venue_public_profile(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Expand member search (creators + venues) and following activity
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.search_members(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.search_members(
    p_query TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    profile_ref_id UUID,
    user_id UUID,
    member_type TEXT,
    full_name TEXT,
    instagram_handle TEXT,
    tiktok_handle TEXT,
    city TEXT,
    score NUMERIC,
    followers BIGINT,
    is_following BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_query TEXT;
    v_limit INTEGER;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_query := lower(trim(coalesce(p_query, '')));
    v_limit := greatest(1, least(coalesce(p_limit, 30), 50));

    RETURN QUERY
    (
        SELECT
            cp.id,
            cp.user_id,
            'creator'::TEXT,
            cp.full_name,
            cp.instagram_handle,
            cp.tiktok_handle,
            cp.city,
            cp.score,
            (SELECT count(*) FROM public.follows f WHERE f.followee_id = cp.user_id),
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = cp.user_id
            )
        FROM public.creator_profiles cp
        JOIN public.profiles p ON p.id = cp.user_id
        WHERE cp.status = 'approved'
          AND p.status = 'approved'
          AND cp.user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(coalesce(cp.full_name, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.instagram_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.tiktok_handle, '')) LIKE '%' || v_query || '%'
              OR lower(coalesce(cp.city, '')) LIKE '%' || v_query || '%'
              OR EXISTS (
                  SELECT 1 FROM unnest(coalesce(cp.niches, ARRAY[]::TEXT[])) n
                  WHERE lower(n) LIKE '%' || v_query || '%'
              )
          )
    )
    UNION ALL
    (
        SELECT
            vp.id,
            vp.owner_user_id,
            'venue'::TEXT,
            vp.venue_name,
            vp.venue_name,
            ''::TEXT,
            vp.area,
            0::NUMERIC,
            (SELECT count(*) FROM public.follows f WHERE f.followee_id = vp.owner_user_id),
            EXISTS (
                SELECT 1 FROM public.follows f
                WHERE f.follower_id = auth.uid() AND f.followee_id = vp.owner_user_id
            )
        FROM public.venue_profiles vp
        JOIN public.profiles p ON p.id = vp.owner_user_id
        WHERE vp.status = 'approved'
          AND p.status = 'approved'
          AND vp.owner_user_id <> auth.uid()
          AND (
              v_query = ''
              OR lower(vp.venue_name) LIKE '%' || v_query || '%'
              OR lower(vp.area) LIKE '%' || v_query || '%'
              OR lower(vp.category::TEXT) LIKE '%' || v_query || '%'
          )
    )
    ORDER BY score DESC NULLS LAST, followers DESC
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_members(TEXT, INTEGER) TO authenticated;

DROP FUNCTION IF EXISTS public.get_following_activity(INTEGER);

CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit INTEGER DEFAULT 40)
RETURNS TABLE (
    activity_id UUID,
    actor_user_id UUID,
    actor_creator_id UUID,
    actor_venue_id UUID,
    actor_name TEXT,
    action_type TEXT,
    title TEXT,
    subtitle TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT *
    FROM (
        SELECT
            b.id,
            cp.user_id,
            cp.id,
            NULL::UUID,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator'),
            'checked_in'::TEXT,
            coalesce(o.title, v.venue_name, 'Collaboration'),
            coalesce(v.area, ''),
            coalesce(b.updated_at, b.created_at)
        FROM public.bookings b
        JOIN public.creator_profiles cp ON cp.id = b.creator_id
        JOIN public.offers o ON o.id = b.offer_id
        JOIN public.venue_profiles v ON v.id = o.venue_id
        JOIN public.follows f ON f.followee_id = cp.user_id AND f.follower_id = auth.uid()
        WHERE b.stage IN ('checked_in', 'proof_due', 'completed')

        UNION ALL

        SELECT
            cs.id,
            cs.user_id,
            cp.id,
            NULL::UUID,
            coalesce(cp.full_name, cp.instagram_handle, 'Creator'),
            'showcase_added'::TEXT,
            CASE WHEN cs.caption <> '' THEN cs.caption WHEN cs.external_url <> '' THEN 'New showcase post' ELSE 'New showcase photo' END,
            coalesce(cs.external_url, cs.media_url, ''),
            cs.created_at
        FROM public.creator_showcase cs
        JOIN public.creator_profiles cp ON cp.user_id = cs.user_id
        JOIN public.follows f ON f.followee_id = cs.user_id AND f.follower_id = auth.uid()

        UNION ALL

        SELECT
            o.id,
            vp.owner_user_id,
            NULL::UUID,
            vp.id,
            vp.venue_name,
            'venue_offer'::TEXT,
            o.title,
            coalesce(vp.area, o.category::TEXT),
            o.created_at
        FROM public.offers o
        JOIN public.venue_profiles vp ON vp.id = o.venue_id
        JOIN public.follows f ON f.followee_id = vp.owner_user_id AND f.follower_id = auth.uid()
        WHERE o.status = 'live'
          AND o.created_at > now() - interval '30 days'
    ) activity
    ORDER BY activity.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 40), 100));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_following_activity(INTEGER) TO authenticated;
