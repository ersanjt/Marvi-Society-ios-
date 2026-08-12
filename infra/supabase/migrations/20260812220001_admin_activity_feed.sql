-- Richer admin activity feed: actor display name + kind for ops monitoring.

DROP FUNCTION IF EXISTS public.admin_list_activity(INTEGER);

CREATE OR REPLACE FUNCTION public.admin_list_activity(p_limit INTEGER DEFAULT 50)
RETURNS TABLE (
    id UUID,
    actor_user_id UUID,
    action TEXT,
    subject_type TEXT,
    subject_id UUID,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    actor_name TEXT,
    actor_kind TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    RETURN QUERY
    SELECT
        e.id,
        e.actor_user_id,
        e.action,
        e.subject_type,
        e.subject_id,
        e.metadata,
        e.created_at,
        COALESCE(
            NULLIF(trim(c.full_name), ''),
            NULLIF(trim(v.venue_name), ''),
            NULLIF(split_part(COALESCE(p.email, ''), '@', 1), ''),
            CASE WHEN e.actor_user_id IS NULL THEN 'System' ELSE 'Member' END
        ) AS actor_name,
        CASE
            WHEN e.actor_user_id IS NULL THEN 'system'
            WHEN p.role::text = 'admin' THEN 'admin'
            WHEN v.id IS NOT NULL THEN 'venue'
            WHEN c.id IS NOT NULL THEN 'creator'
            ELSE COALESCE(p.role::text, 'member')
        END AS actor_kind
    FROM public.activity_events e
    LEFT JOIN public.profiles p ON p.id = e.actor_user_id
    LEFT JOIN public.creator_profiles c ON c.user_id = e.actor_user_id
    LEFT JOIN LATERAL (
        SELECT vp.id, vp.venue_name
        FROM public.venue_profiles vp
        WHERE vp.owner_user_id = e.actor_user_id
        ORDER BY vp.updated_at DESC NULLS LAST
        LIMIT 1
    ) v ON true
    ORDER BY e.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_activity(INTEGER) TO authenticated;
