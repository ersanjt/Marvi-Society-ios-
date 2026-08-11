-- Ops diagnostic used by APPLY_20260811_DB_INTEGRITY.sql / verify scripts.
CREATE OR REPLACE FUNCTION public.marvi_db_integrity_check()
RETURNS TABLE (
    check_name TEXT,
    ok BOOLEAN,
    detail TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 'rpc_upsert_my_creator_profile'::TEXT,
           EXISTS (
               SELECT 1 FROM pg_proc p
               JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'upsert_my_creator_profile'
           ),
           'Creator profile save RPC'::TEXT;

    RETURN QUERY
    SELECT 'rpc_set_my_profile_image'::TEXT,
           EXISTS (
               SELECT 1 FROM pg_proc p
               JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'set_my_profile_image'
           ),
           'Creator photo save RPC'::TEXT;

    RETURN QUERY
    SELECT 'col_business_categories_sort_order'::TEXT,
           EXISTS (
               SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'business_categories'
                 AND column_name = 'sort_order'
           ),
           'Hotel/Restaurant sort column'::TEXT;

    RETURN QUERY
    SELECT 'seed_business_categories_count'::TEXT,
           (SELECT COUNT(*) FROM public.business_categories WHERE is_active) >= 50,
           format('active categories=%s', (SELECT COUNT(*) FROM public.business_categories WHERE is_active));

    RETURN QUERY
    SELECT 'hotel_sort_first'::TEXT,
           COALESCE((
               SELECT slug FROM public.business_categories
               WHERE is_active
               ORDER BY sort_order ASC, name_tr ASC
               LIMIT 1
           ), '') = 'hotel',
           format('first=%s', (
               SELECT slug FROM public.business_categories
               WHERE is_active
               ORDER BY sort_order ASC, name_tr ASC
               LIMIT 1
           ));

    RETURN QUERY
    SELECT 'live_offers'::TEXT,
           (SELECT COUNT(*) FROM public.offers WHERE status = 'live') > 0,
           format('live=%s', (SELECT COUNT(*) FROM public.offers WHERE status = 'live'));
END;
$$;

REVOKE ALL ON FUNCTION public.marvi_db_integrity_check() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.marvi_db_integrity_check() TO service_role;
