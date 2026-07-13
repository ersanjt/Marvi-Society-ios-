-- Auto-apply invite_code from auth user metadata on signup (Auth invite / magic-link path).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_locale TEXT;
    v_city TEXT;
    v_name TEXT;
    v_handle TEXT;
    v_tiktok TEXT;
    v_invite TEXT;
    v_is_review BOOLEAN := lower(coalesce(NEW.email, '')) = 'review@marvisociety.com';
BEGIN
    v_city := lower(coalesce(NEW.raw_user_meta_data ->> 'city', 'istanbul'));
    v_name := coalesce(NEW.raw_user_meta_data ->> 'full_name', split_part(NEW.email, '@', 1));
    v_handle := coalesce(NEW.raw_user_meta_data ->> 'instagram_handle', '');
    v_tiktok := coalesce(NEW.raw_user_meta_data ->> 'tiktok_handle', '');
    v_invite := public.normalize_invite_code(coalesce(NEW.raw_user_meta_data ->> 'invite_code', ''));
    v_locale := public.infer_user_locale(
        NEW.raw_user_meta_data ->> 'locale',
        v_city,
        NULL
    );

    INSERT INTO public.profiles (id, email, role, status, preferred_locale)
    VALUES (
        NEW.id,
        NEW.email,
        'creator',
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END,
        v_locale
    );

    INSERT INTO public.creator_profiles (user_id, full_name, instagram_handle, tiktok_handle, city, languages, status)
    VALUES (
        NEW.id,
        v_name,
        v_handle,
        v_tiktok,
        v_city,
        CASE WHEN v_locale = 'tr' THEN ARRAY['Turkish', 'English'] ELSE ARRAY['English'] END,
        CASE WHEN v_is_review THEN 'approved'::public.membership_status ELSE 'under_review'::public.membership_status END
    );

    IF NOT v_is_review THEN
        INSERT INTO public.admin_tasks (type, subject_id, title, subtitle, priority)
        VALUES (
            'creator_application',
            NEW.id,
            'New creator application',
            coalesce(nullif(v_handle, ''), NEW.email, 'Unknown'),
            'High'
        );

        PERFORM public.queue_transactional_email(
            NEW.id,
            NEW.email,
            'welcome_application',
            v_locale,
            jsonb_build_object(
                'name', v_name,
                'city', v_city,
                'site_url', 'https://marvisociety.com'
            )
        );
    END IF;

    -- If Auth invite/magic-link carried an invite code, redeem it immediately.
    IF v_invite <> '' THEN
        BEGIN
            UPDATE public.referral_codes
            SET uses_count = uses_count + 1
            WHERE upper(code) = v_invite
              AND (max_uses IS NULL OR uses_count < max_uses)
              AND (
                  invite_email IS NULL
                  OR trim(invite_email) = ''
                  OR lower(trim(invite_email)) = lower(trim(NEW.email))
              );

            IF FOUND THEN
                UPDATE public.profiles
                SET referral_code = v_invite
                WHERE id = NEW.id;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL; -- never block signup on invite auto-apply
        END;
    END IF;

    RETURN NEW;
END;
$$;
