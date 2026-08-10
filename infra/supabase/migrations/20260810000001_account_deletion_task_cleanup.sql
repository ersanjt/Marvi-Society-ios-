-- Keep the admin review queue consistent when an account is deleted.

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_creator_id UUID;
    v_user_id UUID := auth.uid();
    v_email TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
    v_creator_id := public.current_creator_id();

    -- admin_tasks.subject_id is intentionally polymorphic and has no foreign key,
    -- so delete every review task owned by this account before its subjects cascade.
    DELETE FROM public.admin_tasks t
    WHERE (t.type IN ('creator_application', 'social_verification') AND t.subject_id = v_user_id)
       OR (t.type = 'venue_application' AND EXISTS (
            SELECT 1 FROM public.venue_profiles v
            WHERE v.id = t.subject_id AND v.owner_user_id = v_user_id
       ))
       OR (t.type = 'campaign_review' AND EXISTS (
            SELECT 1
            FROM public.offers o
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE o.id = t.subject_id AND v.owner_user_id = v_user_id
       ))
       OR (t.type = 'proof_review' AND EXISTS (
            SELECT 1
            FROM public.bookings b
            JOIN public.offers o ON o.id = b.offer_id
            JOIN public.venue_profiles v ON v.id = o.venue_id
            WHERE b.id = t.subject_id
              AND (b.creator_id = v_creator_id OR v.owner_user_id = v_user_id)
       ));

    DELETE FROM public.device_tokens WHERE user_id = v_user_id;
    DELETE FROM public.user_location_snapshots WHERE user_id = v_user_id;
    DELETE FROM public.saved_offers WHERE user_id = v_user_id;
    DELETE FROM public.notifications WHERE user_id = v_user_id;
    DELETE FROM public.push_outbox WHERE user_id = v_user_id;

    IF v_creator_id IS NOT NULL THEN
        DELETE FROM public.creator_shortlists WHERE creator_id = v_creator_id;
        DELETE FROM public.creator_passes WHERE creator_id = v_creator_id;
        DELETE FROM public.proof_submissions WHERE creator_id = v_creator_id;
        DELETE FROM public.bookings WHERE creator_id = v_creator_id;
        DELETE FROM public.strikes WHERE creator_id = v_creator_id;
    END IF;

    DELETE FROM public.creator_profiles WHERE user_id = v_user_id;
    DELETE FROM public.venue_profiles WHERE owner_user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;

    UPDATE public.deletion_requests
    SET completed_at = now()
    WHERE email = v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- Remove historical review tasks whose polymorphic subject was already deleted.
DELETE FROM public.admin_tasks t
WHERE (t.type IN ('creator_application', 'social_verification')
       AND NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = t.subject_id))
   OR (t.type = 'venue_application'
       AND NOT EXISTS (SELECT 1 FROM public.venue_profiles v WHERE v.id = t.subject_id))
   OR (t.type = 'campaign_review'
       AND NOT EXISTS (SELECT 1 FROM public.offers o WHERE o.id = t.subject_id))
   OR (t.type = 'proof_review'
       AND NOT EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = t.subject_id));
