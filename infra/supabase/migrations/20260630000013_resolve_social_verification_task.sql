-- Wire social_verification admin tasks into resolve_admin_task approve/reject flow.

CREATE OR REPLACE FUNCTION public.resolve_admin_task(p_task_id UUID, p_action TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task public.admin_tasks%ROWTYPE;
    v_approve BOOLEAN := lower(trim(p_action)) IN ('approve', 'approved');
    v_email TEXT;
    v_locale TEXT;
    v_name TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    SELECT * INTO v_task FROM public.admin_tasks WHERE id = p_task_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    IF v_task.status <> 'open' THEN
        RETURN;
    END IF;

    UPDATE public.admin_tasks
    SET
        status = CASE WHEN v_approve THEN 'approved'::public.admin_task_status ELSE 'rejected'::public.admin_task_status END,
        resolved_at = now(),
        assigned_admin_id = auth.uid()
    WHERE id = p_task_id;

    CASE v_task.type
        WHEN 'creator_application' THEN
            UPDATE public.profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

            UPDATE public.creator_profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE user_id = v_task.subject_id;

            IF v_approve THEN
                SELECT p.email, p.preferred_locale, cp.full_name
                INTO v_email, v_locale, v_name
                FROM public.profiles p
                LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
                WHERE p.id = v_task.subject_id;

                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Üyeliğiniz onaylandı' ELSE 'Membership approved' END,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr'
                        THEN 'Marvi Society başvurunuz onaylandı. Keşfet sekmesinden canlı etkinliklere göz atın.'
                        ELSE 'Your Marvi Society creator application was approved. Explore live events now.'
                    END,
                    'membership',
                    'checkmark.seal.fill',
                    'emerald',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );

                PERFORM public.queue_transactional_email(
                    v_task.subject_id,
                    v_email,
                    'membership_approved',
                    coalesce(v_locale, 'en'),
                    jsonb_build_object(
                        'name', coalesce(nullif(v_name, ''), 'Creator'),
                        'site_url', 'https://marvisociety.com',
                        'app_url', 'https://marvisociety.com/creators'
                    )
                );
            END IF;

        WHEN 'venue_application' THEN
            UPDATE public.venue_profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

        WHEN 'campaign_review' THEN
            UPDATE public.offers
            SET status = CASE WHEN v_approve THEN 'live'::public.offer_status ELSE 'draft'::public.offer_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

        WHEN 'proof_review' THEN
            UPDATE public.proof_submissions
            SET
                status = CASE WHEN v_approve THEN 'approved'::public.proof_status ELSE 'flagged'::public.proof_status END,
                reviewed_at = now()
            WHERE booking_id = v_task.subject_id
              AND status = 'pending';

            UPDATE public.bookings
            SET proof_status = CASE WHEN v_approve THEN 'approved'::public.proof_status ELSE 'flagged'::public.proof_status END,
                updated_at = now()
            WHERE id = v_task.subject_id;

        WHEN 'social_verification' THEN
            IF v_approve THEN
                UPDATE public.creator_profiles
                SET social_verification_verified_at = now(),
                    social_verification_instagram_handle = public.normalize_social_handle(instagram_handle),
                    social_verification_tiktok_handle = public.normalize_social_handle(tiktok_handle),
                    updated_at = now()
                WHERE user_id = v_task.subject_id;

                SELECT p.email, p.preferred_locale, cp.full_name
                INTO v_email, v_locale, v_name
                FROM public.profiles p
                LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
                WHERE p.id = v_task.subject_id;

                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Sosyal hesap doğrulandı' ELSE 'Social accounts verified' END,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr'
                        THEN 'Instagram DM kodunuz onaylandı. Artık etkinlik tekliflerini kabul edebilirsiniz.'
                        ELSE 'Your Instagram DM code was confirmed. You can now accept event offers.'
                    END,
                    'membership',
                    'checkmark.seal.fill',
                    'emerald',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );
            ELSE
                UPDATE public.creator_profiles
                SET social_verification_submitted_at = NULL,
                    updated_at = now()
                WHERE user_id = v_task.subject_id;
            END IF;
    END CASE;
END;
$$;
