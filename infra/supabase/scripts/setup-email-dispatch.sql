-- Run AFTER migration 20260616000001 and Edge Function deploy.
-- Enables automatic email dispatch when rows are inserted into email_outbox.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Replace YOUR_SERVICE_ROLE_KEY with Project Settings → API → service_role (secret)
ALTER DATABASE postgres SET marvi.edge_function_url = 'https://gaswjuvyzliislqrljof.supabase.co/functions/v1';
ALTER DATABASE postgres SET marvi.service_role_key = 'YOUR_SERVICE_ROLE_KEY';

-- Verify queue
SELECT id, to_email, template, locale, status, created_at
FROM public.email_outbox
ORDER BY created_at DESC
LIMIT 5;
