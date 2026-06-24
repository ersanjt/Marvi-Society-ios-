# Production deploy — email & forms (after code pull)

Run these on **Supabase** and **WHM** after pulling latest code.

## 1. Supabase SQL Editor

Run in order:

```
infra/supabase/migrations/20260624000001_email_production_hardening.sql
```

Then (replace service role key):

```
infra/supabase/scripts/setup-email-dispatch.sql
```

## 2. Deploy send-email edge function

On Mac (Supabase CLI logged in):

```bash
bash scripts/deploy/setup-production-email.sh
```

Or manually:

```bash
cd infra/supabase
supabase functions deploy send-email --project-ref gaswjuvyzliislqrljof
```

Secrets (Dashboard → Edge Functions):

| Secret | Value |
|--------|--------|
| `RESEND_API_KEY` | `re_...` |
| `MARVI_FROM_EMAIL` | `Marvi Society <hello@marvisociety.com>` |
| `MARVI_REPLY_TO` | `support@marvisociety.com` |

Verify:

```bash
curl -s https://gaswjuvyzliislqrljof.supabase.co/functions/v1/send-email
```

## 3. Supabase Auth SMTP

Authentication → SMTP → Custom:

- Host: `smtp.resend.com`
- Port: `465`
- User: `resend`
- Password: Resend API key
- Sender: `hello@marvisociety.com`

## 4. cPanel

Create **`support@marvisociety.com`** (fix `suppoert@` typo).

Optional: forward extra addresses (`welcome@`, etc.) → `support@`.

## 5. WHM — pull & restart web

```bash
cd /opt/marvisociety-src && git pull
cd apps/web && npm ci && npm run build
pm2 restart marvisociety-web
```

Ensures `/api/contact` and updated `/api/demo` are live.

## 6. Verify

```bash
npm run verify:e2e
npm run verify:emails
```

Manual: open https://marvisociety.com/contact → send test message.

Manual: https://marvisociety.com/delete-account → OTP to a **test** email (not review@).
