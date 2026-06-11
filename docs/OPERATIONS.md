# Marvi Society — Operations Guide

**راهنمای عملیات و مدیریت سیستم** — develop, deploy, sync, rollback.

---

## Quick commands (همیشه بعد از هر کار)

```bash
# وضعیت کامل: گیت، دیتابیس، iOS، وب
npm run status

# همگام‌سازی کامل: verify → DB → GitHub
npm run sync

# فقط GitHub
npm run sync:github

# فقط دیتابیس (combine + push)
npm run db:push

# برگشت به نسخه قبل (راهنما)
npm run rollback
```

**Fast sync** (بدون build — سریع‌تر):

```bash
MARVI_FAST_SYNC=1 npm run sync
```

---

## Architecture of ops

```text
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  iOS App    │────▶│   Supabase   │◀────│  Web (Vercel)│
│  Xcode      │     │  PostgreSQL  │     │  Next.js     │
└─────────────┘     └──────────────┘     └─────────────┘
       │                    │                    │
       └────────────────────┴────────────────────┘
                            │
                    ┌───────▼────────┐
                    │ GitHub (main)  │
                    │ CI + releases  │
                    └────────────────┘
```

| Layer | Source of truth | Sync command |
|-------|-----------------|--------------|
| **Code** | `main` on GitHub | `npm run sync:github` |
| **Database** | `infra/supabase/migrations/` | `npm run db:push` |
| **iOS config** | `apps/ios/Config/Secrets.xcconfig` | `apps/ios/configure-supabase.sh` |
| **Web env** | `apps/web/.env.local` | copy from `.env.example` |
| **Versions** | `release/manifest.json` | auto-updated on sync |

---

## First-time setup (یک‌بار)

### 1. GitHub

```bash
brew install gh    # if needed
gh auth login
npm run setup:hooks
```

### 2. Supabase (database)

```bash
# Option A — CLI (recommended)
npx supabase login
npm run db:push

# Option B — SQL Editor
# Paste: infra/supabase/ALL_MIGRATIONS_COMBINED.sql
```

Project ref: `gaswjuvyzliislqrljof` (see `.marvi/config.json`)

Post-migration (if needed):

- `infra/supabase/fix-user-account.sql`
- `infra/supabase/grant-admin-ersanjt.sql`

### 3. iOS

```bash
apps/ios/configure-supabase.sh
# Open Xcode → build on device
```

### 4. Web (Vercel)

```bash
cd apps/web
cp .env.example .env.local
# Fill: NEXT_PUBLIC_SUPABASE_URL, ANON_KEY, SERVICE_ROLE_KEY, NEXT_PUBLIC_SITE_URL
vercel link && vercel --prod
```

---

## Daily workflow (بعد از هر تغییر)

1. **Develop** — code / SQL migration
2. **Verify** — `npm run verify` (build iOS + web + health)
3. **Sync** — `npm run sync` (commits + pushes + DB combine)
4. **Check** — `npm run status` + Supabase Dashboard + app on device

Cursor agent rule (`.cursor/rules/ops-always-sync.mdc`) enforces this automatically.

---

## Releases (نسخه‌گذاری)

```bash
npm run release -- 0.3.0 "Venue media upload"
```

This will:

- Update `release/manifest.json`
- Prepend `CHANGELOG.md`
- Create git tag `v0.3.0`
- Trigger GitHub Release workflow

---

## Rollback (برگشت عقب)

| Component | Action |
|-----------|--------|
| **Git** | `git log --oneline` → `npm run rollback -- git <sha>` |
| **Tag** | `git checkout v0.2.0` |
| **Web** | Vercel → Deployments → Promote previous |
| **Database** | Supabase backup / forward-fix migration (no auto down) |
| **iOS** | Rebuild from older tag; TestFlight previous build |

Full playbook: `npm run rollback`

---

## CI/CD (GitHub Actions)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | push/PR to main | Web + iOS + Android scaffold build |
| `ops-verify.yml` | push to main | Migration manifest, combined SQL artifact |
| `release.yml` | tag `v*` | GitHub Release + verify build |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Push fails: no GitHub auth | `gh auth login` |
| Health check fails | Configure `Secrets.xcconfig`, run seed SQL |
| Admin not visible in app | Run `grant-admin-ersanjt.sql`, Profile → Sync |
| db push fails | Paste `ALL_MIGRATIONS_COMBINED.sql` in SQL Editor |
| Migration count drift in CI | Run `npm run db:combine` and commit manifest |

---

## File reference

```text
.marvi/config.json          Project IDs and paths
release/manifest.json       Version + migration head + sync log
scripts/marvi                 Ops CLI entry point
scripts/release/full-sync.sh  End-to-end sync
CHANGELOG.md                  Human-readable history
```

See also: [DEPLOYMENT.md](DEPLOYMENT.md) · [DEPLOY_WALKTHROUGH_FA.md](DEPLOY_WALKTHROUGH_FA.md)
