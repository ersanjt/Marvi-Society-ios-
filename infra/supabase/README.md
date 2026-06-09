# Supabase Infrastructure

Database migrations, RLS, RPC functions, storage buckets, and Istanbul seed.

## Quick deploy

```powershell
# From repo root (replace YOUR_REF)
.\scripts\deploy\setup-supabase.ps1 -ProjectRef YOUR_REF
```

Then run `seed-after-deploy.sql` in SQL Editor after creating an Auth user.

Full guide: [docs/DEPLOY_WALKTHROUGH_FA.md](../../docs/DEPLOY_WALKTHROUGH_FA.md)

## Migrations (in order)

1. `20260609000001_initial_schema.sql`
2. `20260609000002_rls_policies.sql`
3. `20260609000003_rpc_functions.sql`
4. `20260609000004_demo_leads_storage.sql`
5. `20260609000005_seed_function.sql`

## Local development

```bash
cd infra/supabase
npx supabase start
npx supabase db reset
```

## Schema docs

- [docs/BACKEND_SCHEMA.md](../../docs/BACKEND_SCHEMA.md)
- [docs/PHASE1_SETUP.md](../../docs/PHASE1_SETUP.md)
