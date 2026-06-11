# Supabase Infrastructure

Database migrations, RLS, RPC functions, storage buckets, and Istanbul seed.

## Quick deploy

```powershell
# From repo root (replace YOUR_REF)
.\scripts\deploy\setup-supabase.ps1 -ProjectRef YOUR_REF
```

Or paste `ALL_MIGRATIONS_COMBINED.sql` into the Supabase SQL Editor (regenerate with `npm run db:combine`).

Then run `seed-after-deploy.sql` after creating an Auth user.

Full guide: [docs/DEPLOY_WALKTHROUGH_FA.md](../../docs/DEPLOY_WALKTHROUGH_FA.md)

## Migrations (in order)

1. `20260609000001_initial_schema.sql`
2. `20260609000002_rls_policies.sql`
3. `20260609000003_rpc_functions.sql`
4. `20260609000004_demo_leads_storage.sql`
5. `20260609000005_seed_function.sql`
6. `20260610000001_production_hardening.sql`
7. `20260610000002_delete_own_account.sql`
8. `20260611000001_secret_society_parity.sql` — admin RPC, swipe, venue review queue
9. `20260612000001_account_context_rpc.sql` — reliable role sync for iOS Profile
10. `20260613000001_venue_reviews_strikes.sql` — venue ratings + admin strikes

## One-shot scripts

| File | Purpose |
|------|---------|
| `fix-user-account.sql` | Grant admin, approve profile, dedupe seed data |
| `seed-after-deploy.sql` | Istanbul venues/offers after first deploy |
| `scripts/combine-migrations.sh` | Build `ALL_MIGRATIONS_COMBINED.sql` |

## Local development

```bash
cd infra/supabase
npx supabase start
npx supabase db reset
```

## Schema docs

- [docs/BACKEND_SCHEMA.md](../../docs/BACKEND_SCHEMA.md)
- [docs/PHASE1_SETUP.md](../../docs/PHASE1_SETUP.md)
- [docs/PROJECT_STRUCTURE.md](../../docs/PROJECT_STRUCTURE.md)
