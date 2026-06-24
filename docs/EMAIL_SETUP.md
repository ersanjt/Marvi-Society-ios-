# Email setup — Marvi Society (marvisociety.com)

Transactional emails (signup + membership approved) are sent via **[Resend](https://resend.com)** from your domain.

## Which email addresses to create

| Address | Purpose |
|---------|---------|
| **hello@marvisociety.com** | **From** address (recommended) — welcome & approval emails |
| **support@marvisociety.com** | **Reply-to** + contact form notifications — **must exist in cPanel** |
| **review@marvisociety.com** | Apple App Review login (not for bulk email) |
| **noreply@marvisociety.com** | Optional alternative From if you prefer |

> **cPanel typo fix:** If you created `suppoert@`, create **`support@`** or forward `support@` → your inbox. The app and legal pages use `support@marvisociety.com` everywhere.

You do **not** need separate inboxes for `welcome@`, `deleteotp@`, etc. — all transactional mail sends from **hello@** via Resend.

## Step 1 — Resend account + domain

1. Sign up at [resend.com](https://resend.com)
2. **Domains → Add Domain** → `marvisociety.com`
3. Add the DNS records Resend shows (at your domain registrar / Cloudflare):
   - SPF (TXT)
   - DKIM (CNAME or TXT)
   - Optional: DMARC (TXT) for deliverability
4. Wait until status is **Verified**

## Step 2 — API key

1. Resend → **API Keys** → Create
2. Copy the key (`re_...`)

## Step 3 — Supabase Edge Function secrets

In Supabase Dashboard → **Project Settings → Edge Functions → Secrets**:

| Secret | Value |
|--------|--------|
| `RESEND_API_KEY` | `re_...` from Resend |
| `MARVI_FROM_EMAIL` | `Marvi Society <hello@marvisociety.com>` |
| `MARVI_REPLY_TO` | `support@marvisociety.com` |

Deploy the function:

```bash
cd infra/supabase
supabase functions deploy send-email --project-ref gaswjuvyzliislqrljof
```

## Step 4 — Run database migrations

SQL Editor → run (in order):

1. `infra/supabase/migrations/20260616000001_transactional_email.sql`
2. `infra/supabase/migrations/20260624000001_email_production_hardening.sql`

This adds:
- `profiles.preferred_locale`
- `email_outbox` queue + dispatch diagnostics
- `contact_messages` table
- Welcome email on signup (skipped for `review@marvisociety.com`)
- Approval email when admin approves creator

## Step 5 — Auto-dispatch (choose one)

### Option A — Database Webhook (recommended)

Supabase → **Database → Webhooks → Create**:

- **Table:** `email_outbox`
- **Events:** Insert
- **URL:** `https://gaswjuvyzliislqrljof.supabase.co/functions/v1/send-email`
- **Headers:** `Authorization: Bearer YOUR_SERVICE_ROLE_KEY`
- **Payload:** `{ "outbox_id": "{{ record.id }}" }`

### Option B — pg_net auto-dispatch

Run once in SQL Editor (replace values):

```sql
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

ALTER DATABASE postgres SET marvi.edge_function_url = 'https://gaswjuvyzliislqrljof.supabase.co/functions/v1';
ALTER DATABASE postgres SET marvi.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

## Step 6 — Auth emails (password reset / signup confirm)

**Root cause of `localhost` links on iPhone:** Supabase **Site URL** must be `https://marvisociety.com`, not `http://localhost:3000`.

### Dashboard

1. **Authentication → URL Configuration**
   - Site URL: `https://marvisociety.com`
   - Redirect URLs: see `infra/supabase/auth-email-templates/README.md`

2. **Authentication → Email Templates**
   - Paste branded HTML from `infra/supabase/auth-email-templates/` (TR subjects in README)

3. **Authentication → SMTP Settings** (recommended)
   - Resend SMTP, sender `hello@marvisociety.com`

### Web pages (must be deployed)

- `/auth/reset-password` — user sets new password after email link
- `/auth/callback` — email confirm / magic link

Verify: `npm run verify:auth`

Full guide (FA): `docs/AUTH_EMAIL_FIX_FA.md`

Used for: password reset, email confirm, magic link — **not** `email_outbox` / `send-email`.

## Language rules

| User | Email language |
|------|----------------|
| Istanbul / Turkish city | **Turkish (tr)** |
| `locale: tr` in signup metadata | **Turkish** |
| Languages include Turkish | **Turkish** |
| Everyone else | **English (en)** |

iOS sends `locale` in signup metadata from app language (Settings → Language).

## Email types

| Template | When | TR subject |
|----------|------|------------|
| `welcome_application` | User signs up | Başvurunuz alındı |
| `membership_approved` | Admin approves creator | Kaydınız onaylandı |
| `invite_code` | Admin sends invite | Davet kodunuz |
| `admin_message` | Admin custom email | (custom subject) |
| `contact_form` | Web `/contact` form | [Contact] … |
| `demo_request` | Web `/demo` form | [Demo] … |

**Auth SMTP (Supabase):** delete-account OTP, password reset — not via `email_outbox`.

## Verify (automated)

```bash
npm run verify:emails   # edge function, health, outbox, contact API
npm run verify:e2e      # login, explore, web pages
```

Health check for edge function:

```bash
curl -s https://gaswjuvyzliislqrljof.supabase.co/functions/v1/send-email
# → {"ok":true,"service":"send-email","resendConfigured":true,...}
```

## Verify (SQL)

```sql
SELECT id, to_email, template, locale, status, created_at
FROM public.email_outbox
ORDER BY created_at DESC
LIMIT 10;
```

Manual send for a stuck row:

```bash
curl -X POST 'https://gaswjuvyzliislqrljof.supabase.co/functions/v1/send-email' \
  -H 'Authorization: Bearer SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"outbox_id":"UUID-HERE"}'
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `RESEND_API_KEY is not configured` | Add secret + redeploy function |
| Domain not verified | Complete DNS in Resend |
| Rows stay `pending` | Set up Database Webhook or pg_net; check `error_message` for "Dispatch not configured" |
| `send-email` HTTP 404 | Deploy function: `bash scripts/deploy/setup-production-email.sh` |
| Contact form 503 | Set `SUPABASE_SERVICE_ROLE_KEY` on WHM + run migration `20260624000001` |
| Wrong language | User re-signs with correct locale; update `profiles.preferred_locale` |
