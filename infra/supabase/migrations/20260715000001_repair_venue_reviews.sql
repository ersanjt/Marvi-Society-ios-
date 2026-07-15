-- Repair: recreate public.venue_reviews on environments where the original
-- 20260613000001 migration was recorded as applied but its table DDL never
-- ran (the migration file was edited after being pushed, so `db push` skipped
-- it). fetch_venue_review_queue() and the public-profile functions LEFT JOIN
-- this table, so its absence surfaces as
-- `relation "public.venue_reviews" does not exist` on the Venue Studio screen.
-- Fully idempotent so it is safe on databases that already have the table.

CREATE TABLE IF NOT EXISTS public.venue_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings (id) ON DELETE CASCADE,
    venue_id UUID NOT NULL REFERENCES public.venue_profiles (id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.creator_profiles (id) ON DELETE CASCADE,
    punctuality SMALLINT NOT NULL CHECK (punctuality BETWEEN 1 AND 5),
    presentation SMALLINT NOT NULL CHECK (presentation BETWEEN 1 AND 5),
    comment TEXT NOT NULL DEFAULT '',
    created_by UUID NOT NULL REFERENCES public.profiles (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.venue_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS venue_reviews_select ON public.venue_reviews;
CREATE POLICY venue_reviews_select ON public.venue_reviews
    FOR SELECT USING (
        created_by = auth.uid()
        OR public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = venue_reviews.venue_id AND v.owner_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS venue_reviews_insert ON public.venue_reviews;
CREATE POLICY venue_reviews_insert ON public.venue_reviews
    FOR INSERT WITH CHECK (
        created_by = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.bookings b
            JOIN public.offers o ON o.id = b.offer_id
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE b.id = booking_id AND v.owner_user_id = auth.uid()
        )
    );
