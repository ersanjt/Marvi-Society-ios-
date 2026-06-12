# Email setup — Marvi Society (marvisociety.com)

Transactional emails (signup + membership approved) are sent via **[Resend](https://resend.com)** from your domain.

## Which email addresses to create

| Address | Purpose |
|---------|---------|
| **hello@marvisociety.com** | **From** address (recommended) — welcome & approval emails |
| **support@marvisociety.com** | **Reply-to** — user questions (already in legal pages) |
| **noreply@marvisociety.com** | Optional alternative From if you prefer |

You do **not** need a full Google Workspace inbox for sending — Resend sends on your behalf after DNS verification.

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

## Step 4 — Run database migration

SQL Editor → run:

`infra/supabase/migrations/20260616000001_transactional_email.sql`

This adds:
- `profiles.preferred_locale`
- `email_outbox` queue
- Welcome email on signup
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

## Step 6 — Auth emails (OTP / password reset)

Supabase → **Authentication → SMTP Settings**:

- Enable custom SMTP (Resend SMTP: `smtp.resend.com`, port 465, user `resend`, password = API key)
- Sender: `hello@marvisociety.com`

Used for delete-account OTP on the website.

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

## Verify

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
| Rows stay `pending` | Set up Database Webhook or pg_net |
| Wrong language | User re-signs with correct locale; update `profiles.preferred_locale` |
