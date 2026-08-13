-- Notify business owners when admin approves/rejects venue or campaign reviews.
-- Also approve/pause the owner profile status alongside venue_profiles.

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
    v_owner UUID;
    v_venue_name TEXT;
    v_offer_title TEXT;
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

            SELECT p.email, p.preferred_locale, cp.full_name
            INTO v_email, v_locale, v_name
            FROM public.profiles p
            LEFT JOIN public.creator_profiles cp ON cp.user_id = p.id
            WHERE p.id = v_task.subject_id;

            IF v_approve THEN
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
            ELSE
                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Başvuru sonucu' ELSE 'Application update' END,
                    CASE WHEN coalesce(v_locale, 'en') = 'tr'
                        THEN 'Creator başvurunuz şu an onaylanmadı. Profilini güncelleyip destek ile iletişime geçebilirsin.'
                        ELSE 'Your creator application was not approved. Update your profile and contact support if you need help.'
                    END,
                    'membership',
                    'exclamationmark.triangle.fill',
                    'tomato',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );
            END IF;

        WHEN 'venue_application' THEN
            UPDATE public.venue_profiles
            SET status = CASE WHEN v_approve THEN 'approved'::public.membership_status ELSE 'paused'::public.membership_status END,
                updated_at = now()
            WHERE id = v_task.subject_id
            RETURNING owner_user_id, venue_name INTO v_owner, v_venue_name;

            IF v_owner IS NOT NULL THEN
                UPDATE public.profiles
                SET
                    status = CASE
                        WHEN v_approve THEN 'approved'::public.membership_status
                        WHEN role = 'venue'::public.user_role THEN 'paused'::public.membership_status
                        ELSE status
                    END,
                    role = CASE
                        WHEN v_approve AND role IS DISTINCT FROM 'admin'::public.user_role
                            THEN 'venue'::public.user_role
                        ELSE role
                    END,
                    updated_at = now()
                WHERE id = v_owner;

                SELECT p.email, p.preferred_locale
                INTO v_email, v_locale
                FROM public.profiles p
                WHERE p.id = v_owner;

                IF v_approve THEN
                    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                    VALUES (
                        v_owner,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekânın onaylandı' ELSE 'Venue approved' END,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr'
                            THEN coalesce(nullif(v_venue_name, ''), 'Mekânın') || ' onaylandı. Stüdyo’dan ilk kampanyanı oluşturabilirsin.'
                            ELSE coalesce(nullif(v_venue_name, ''), 'Your venue') || ' was approved. Create your first campaign in Studio.'
                        END,
                        'membership',
                        'checkmark.seal.fill',
                        'emerald',
                        jsonb_build_object('deep_link', 'marvisociety://studio', 'venue_id', v_task.subject_id)
                    );
                ELSE
                    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                    VALUES (
                        v_owner,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Mekân başvurusu güncellendi' ELSE 'Venue application updated' END,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr'
                            THEN coalesce(nullif(v_venue_name, ''), 'Mekân başvurun') || ' onaylanmadı. Bilgileri gözden geçirip yeniden gönder veya destek ile iletişime geç.'
                            ELSE coalesce(nullif(v_venue_name, ''), 'Your venue application') || ' was not approved. Review your details and resubmit, or contact support.'
                        END,
                        'membership',
                        'exclamationmark.triangle.fill',
                        'tomato',
                        jsonb_build_object('deep_link', 'marvisociety://studio', 'venue_id', v_task.subject_id)
                    );
                END IF;
            END IF;

        WHEN 'campaign_review' THEN
            UPDATE public.offers
            SET status = CASE WHEN v_approve THEN 'live'::public.offer_status ELSE 'draft'::public.offer_status END,
                updated_at = now()
            WHERE id = v_task.subject_id
            RETURNING title INTO v_offer_title;

            SELECT vp.owner_user_id, vp.venue_name
            INTO v_owner, v_venue_name
            FROM public.offers o
            JOIN public.venue_profiles vp ON vp.id = o.venue_id
            WHERE o.id = v_task.subject_id;

            IF v_owner IS NOT NULL THEN
                SELECT p.email, p.preferred_locale
                INTO v_email, v_locale
                FROM public.profiles p
                WHERE p.id = v_owner;

                IF v_approve THEN
                    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                    VALUES (
                        v_owner,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Kampanya yayında' ELSE 'Campaign is live' END,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr'
                            THEN coalesce(nullif(v_offer_title, ''), 'Kampanyan') || ' onaylandı ve canlıya alındı.'
                            ELSE coalesce(nullif(v_offer_title, ''), 'Your campaign') || ' was approved and is now live.'
                        END,
                        'campaign',
                        'sparkles',
                        'emerald',
                        jsonb_build_object('deep_link', 'marvisociety://studio', 'offer_id', v_task.subject_id)
                    );
                ELSE
                    INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                    VALUES (
                        v_owner,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Kampanya incelemeye alınamadı' ELSE 'Campaign needs changes' END,
                        CASE WHEN coalesce(v_locale, 'en') = 'tr'
                            THEN coalesce(nullif(v_offer_title, ''), 'Kampanyan') || ' reddedildi. Düzenleyip tekrar admin incelemesine gönder.'
                            ELSE coalesce(nullif(v_offer_title, ''), 'Your campaign') || ' was rejected. Edit it and resubmit for admin review.'
                        END,
                        'campaign',
                        'exclamationmark.triangle.fill',
                        'tomato',
                        jsonb_build_object('deep_link', 'marvisociety://studio', 'offer_id', v_task.subject_id)
                    );
                END IF;
            END IF;

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

                INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
                VALUES (
                    v_task.subject_id,
                    CASE WHEN (
                        SELECT preferred_locale FROM public.profiles WHERE id = v_task.subject_id
                    ) = 'tr' THEN 'Sosyal doğrulama reddedildi' ELSE 'Social verification rejected' END,
                    CASE WHEN (
                        SELECT preferred_locale FROM public.profiles WHERE id = v_task.subject_id
                    ) = 'tr'
                        THEN 'DM kodu doğrulanamadı. Yeni kod alıp tekrar gönder.'
                        ELSE 'Your DM code could not be verified. Get a new code and try again.'
                    END,
                    'membership',
                    'exclamationmark.triangle.fill',
                    'tomato',
                    jsonb_build_object('deep_link', 'marvisociety://profile')
                );
            END IF;
    END CASE;
END;
$$;

-- Notify owner when a venue application is submitted for admin review.
CREATE OR REPLACE FUNCTION public.notify_venue_application_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_locale TEXT;
    v_owner UUID;
    v_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.type = 'venue_application' AND NEW.status = 'open' THEN
        SELECT vp.owner_user_id, vp.venue_name, p.preferred_locale
        INTO v_owner, v_name, v_locale
        FROM public.venue_profiles vp
        JOIN public.profiles p ON p.id = vp.owner_user_id
        WHERE vp.id = NEW.subject_id;

        IF v_owner IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
            VALUES (
                v_owner,
                CASE WHEN coalesce(v_locale, 'en') = 'tr' THEN 'Başvuru incelemeye alındı' ELSE 'Application under review' END,
                CASE WHEN coalesce(v_locale, 'en') = 'tr'
                    THEN coalesce(nullif(v_name, ''), 'Mekân başvurun') || ' admin incelemesine gönderildi. Sonuç burada görünecek.'
                    ELSE coalesce(nullif(v_name, ''), 'Your venue application') || ' was sent for admin review. You will see the result here.'
                END,
                'membership',
                'hourglass',
                'gold',
                jsonb_build_object('deep_link', 'marvisociety://studio', 'venue_id', NEW.subject_id)
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_venue_application_submitted ON public.admin_tasks;
CREATE TRIGGER trg_notify_venue_application_submitted
AFTER INSERT ON public.admin_tasks
FOR EACH ROW
EXECUTE FUNCTION public.notify_venue_application_submitted();
