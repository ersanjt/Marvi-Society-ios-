-- Close legacy function-execution defaults and remove current advisor warnings.
-- Every SECURITY DEFINER function is private by default; authenticated RPCs are
-- explicitly restored below, while service_role keeps operational access.

BEGIN;

DO $$
DECLARE
    fn RECORD;
BEGIN
    FOR fn IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS identity_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef
    LOOP
        EXECUTE format(
            'REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC, anon, authenticated',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO service_role',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
    END LOOP;
END;
$$;

-- Restore the signed-in client RPC surface. Trigger functions and privileged
-- queue/cron helpers remain service-role only.
DO $$
DECLARE
    fn RECORD;
    internal_names CONSTANT TEXT[] := ARRAY[
        'dispatch_email_outbox',
        'dispatch_push_outbox',
        'ensure_conversation_for_booking',
        'guard_booking_proof_approval',
        'guard_offer_publish',
        'handle_new_user',
        'log_activity_event',
        'queue_push_notification',
        'queue_transactional_email',
        'resolve_active_venue_id',
        'seed_istanbul_demo'
    ];
BEGIN
    FOR fn IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS identity_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef
          AND p.prorettype <> 'trigger'::regtype
          AND NOT (p.proname = ANY(internal_names))
    LOOP
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
    END LOOP;
END;
$$;

-- Anonymous callers only need the non-mutating referral check and the policy
-- helper used by public RLS reads.
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon;

-- Pin search_path on project-owned functions to prevent object-shadowing.
DO $$
DECLARE
    fn RECORD;
BEGIN
    FOR fn IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS identity_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND pg_get_userbyid(p.proowner) = current_user
    LOOP
        EXECUTE format(
            'ALTER FUNCTION %I.%I(%s) SET search_path = public, extensions, pg_temp',
            fn.nspname,
            fn.proname,
            fn.identity_args
        );
    END LOOP;
END;
$$;

-- Public buckets do not need broad SELECT policies for object downloads.
-- Keep SELECT only for owner-scoped upsert/list operations.
DROP POLICY IF EXISTS profile_media_public_read ON storage.objects;
DROP POLICY IF EXISTS profile_media_select_own ON storage.objects;
CREATE POLICY profile_media_select_own ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'profile-media'
        AND (storage.foldername(name))[1] = (select auth.uid())::TEXT
    );

-- Account-deletion rows are written only by the server-side service role.
DROP POLICY IF EXISTS deletion_insert ON public.deletion_requests;

-- Demo submissions remain public, but validate shape and size at the database
-- boundary instead of accepting arbitrary rows.
DROP POLICY IF EXISTS demo_requests_insert_public ON public.demo_requests;
CREATE POLICY demo_requests_insert_public ON public.demo_requests
    FOR INSERT TO anon, authenticated
    WITH CHECK (
        length(trim(first_name)) BETWEEN 1 AND 120
        AND length(trim(last_name)) BETWEEN 1 AND 120
        AND length(trim(company)) BETWEEN 1 AND 180
        AND length(trim(email)) BETWEEN 3 AND 320
        AND position('@' IN email) > 1
        AND length(coalesce(website, '')) <= 500
        AND length(coalesce(message, '')) <= 5000
        AND source = 'web'
        AND status = 'new'
    );

INSERT INTO supabase_migrations.schema_migrations (version, name, statements)
VALUES (
    '20260809164025',
    'harden_function_execution_and_search_path',
    ARRAY[]::TEXT[]
)
ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;

COMMIT;
