# راه‌اندازی وب Marvi Society / Web Setup

## پیش‌نیاز

- Node.js 20+
- پروژه Supabase: `gaswjuvyzliislqrljof`
- دامنه پیشنهادی: `https://marvisociety.com`

## نصب محلی

```bash
# از ریشه monorepo
npm install
npm run web:dev
```

یا:

```bash
cd apps/web
cp .env.example .env.local
# مقادیر Supabase را پر کنید
npm run dev
```

باز کردن: [http://localhost:3000](http://localhost:3000)

## متغیرهای محیطی

| Variable | Scope | Required |
|----------|-------|----------|
| `NEXT_PUBLIC_SUPABASE_URL` | Client | Production |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Client | Production |
| `NEXT_PUBLIC_SITE_URL` | Client | Production (e.g. `https://marvisociety.com`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Server only | Production (admin API) |

**هرگز** `SUPABASE_SERVICE_ROLE_KEY` را در client یا Git commit نگذارید.

## Deploy روی Vercel

1. Import repository — **Root Directory:** `apps/web`
2. Framework: Next.js (auto-detected)
3. Region: `fra1` (Istanbul proximity — already in `vercel.json`)
4. Environment variables را برای Production و Preview تنظیم کنید
5. Deploy

### GitHub Actions

Workflow `.github/workflows/deploy-web.yml` on push to `main` when `apps/web/**` changes.

Secrets needed:

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`

## SQL و Edge Functions (قبل از admin کامل)

در Supabase SQL Editor اجرا کنید:

1. `infra/supabase/apply-referral-fix.sql`
2. `infra/supabase/apply-admin-operations.sql`
3. `infra/supabase/apply-push-outbox.sql`

Edge functions:

```bash
supabase functions deploy send-email
supabase functions deploy send-push
supabase functions deploy admin-provision-user
```

Database webhooks روی `email_outbox` و `push_outbox` — جزئیات در `docs/EMAIL_SETUP.md` و `docs/PUSH_SETUP.md`.

## دسترسی Admin

1. SQL: `infra/supabase/grant-admin-ersanjt.sql` (یا `grant-admin.sql` با UUID کاربر)
2. Login: `/portal/login`
3. Console: `/admin`

## Health check

```
GET /api/health
```

در production اگر Supabase تنظیم نشده باشد، `status: degraded` برمی‌گردد.

## ساختار فایل‌ها

جزئیات کامل: [`apps/web/ARCHITECTURE.md`](../apps/web/ARCHITECTURE.md)
