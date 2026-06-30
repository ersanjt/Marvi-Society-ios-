-- Creator showcase: a portfolio gallery on the profile.
-- Creators add their best content — uploaded photos or links to their
-- Instagram / TikTok posts — to display on their (public) profile.

CREATE TABLE IF NOT EXISTS public.creator_showcase (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES public.profiles (id) ON DELETE CASCADE,
    media_type TEXT NOT NULL DEFAULT 'image' CHECK (media_type IN ('image', 'video', 'link')),
    media_url TEXT NOT NULL DEFAULT '',
    external_url TEXT NOT NULL DEFAULT '',
    caption TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_creator_showcase_user
    ON public.creator_showcase (user_id, created_at DESC);

ALTER TABLE public.creator_showcase ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS creator_showcase_select ON public.creator_showcase;
CREATE POLICY creator_showcase_select ON public.creator_showcase
    FOR SELECT USING (true);

DROP POLICY IF EXISTS creator_showcase_insert ON public.creator_showcase;
CREATE POLICY creator_showcase_insert ON public.creator_showcase
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS creator_showcase_update ON public.creator_showcase;
CREATE POLICY creator_showcase_update ON public.creator_showcase
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS creator_showcase_delete ON public.creator_showcase;
CREATE POLICY creator_showcase_delete ON public.creator_showcase
    FOR DELETE USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.creator_showcase TO authenticated;
GRANT SELECT ON public.creator_showcase TO anon;

-- Delete helper (the iOS client has no generic table-delete method).
CREATE OR REPLACE FUNCTION public.delete_showcase_item(p_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    DELETE FROM public.creator_showcase
    WHERE id = p_id AND user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_showcase_item(UUID) TO authenticated;

-- Public fetch of a user's showcase (used on public creator profiles).
CREATE OR REPLACE FUNCTION public.get_user_showcase(p_user_id UUID)
RETURNS SETOF public.creator_showcase
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT *
    FROM public.creator_showcase
    WHERE user_id = p_user_id
    ORDER BY created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_showcase(UUID) TO authenticated, anon;

-- Showcase for the signed-in user.
CREATE OR REPLACE FUNCTION public.get_my_showcase()
RETURNS SETOF public.creator_showcase
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT *
    FROM public.creator_showcase
    WHERE user_id = auth.uid()
    ORDER BY created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_showcase() TO authenticated;
