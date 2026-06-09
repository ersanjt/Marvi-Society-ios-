# Supabase Infrastructure

**Status:** Phase 1 (not started)

## Contents (planned)

```text
infra/supabase/
├── migrations/       # SQL schema versions
├── seed/             # Istanbul demo venues + offers
├── policies/         # RLS policy reference
└── functions/        # Edge Functions (notify, proof-deadline)
```

## Schema source of truth

- [docs/BACKEND_SCHEMA.md](../../docs/BACKEND_SCHEMA.md)
- [packages/api-contract/openapi.yaml](../../packages/api-contract/openapi.yaml)

## Local development (Phase 1)

```bash
supabase init
supabase start
supabase db reset
```
