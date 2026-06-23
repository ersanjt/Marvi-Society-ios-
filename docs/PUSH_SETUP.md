# Push setup — Marvi Society (APNs)

Remote push uses **`push_outbox`** + Edge Function **`send-push`** (same pattern as email).

## Prerequisites

1. Run SQL migrations in order:
   - `infra/supabase/apply-admin-operations.sql`
   - `infra/supabase/migrations/20260619000001_push_outbox.sql`
2. Apple Developer → Keys → create **APNs Auth Key** (`.p8`)
3. Enable **Push Notifications** capability for `com.marvisociety.app`

## Step 1 — Edge Function secrets

Supabase Dashboard → **Edge Functions → Secrets**:

| Secret | Value |
|--------|--------|
| `APNS_KEY_ID` | Key ID from Apple |
| `APNS_TEAM_ID` | Apple Team ID |
| `APNS_KEY_P8` | Full `.p8` file contents |
| `APNS_BUNDLE_ID` | `com.marvisociety.app` |
| `APNS_PRODUCTION` | `false` for dev/TestFlight, `true` for App Store |
| `SUPABASE_ANON_KEY` | Project anon key (for admin-provision-user) |

Deploy functions:

```bash
cd infra/supabase
supabase functions deploy send-push --project-ref gaswjuvyzliislqrljof
supabase functions deploy admin-provision-user --project-ref gaswjuvyzliislqrljof
```

## Step 2 — Auto-dispatch push (optional)

Same as email — Database Webhook on **`push_outbox`** INSERT:

- **URL:** `https://gaswjuvyzliislqrljof.supabase.co/functions/v1/send-push`
- **Headers:** `Authorization: Bearer YOUR_SERVICE_ROLE_KEY`
- **Payload:** `{ "outbox_id": "{{ record.id }}" }`

Or reuse `pg_net` settings from `docs/EMAIL_SETUP.md` (same `marvi.edge_function_url`).

## Step 3 — iOS

- Entitlements include `aps-environment` (development for local device builds)
- User must allow notifications; app registers token via `register_device_token`
- Admin **Broadcast** / **Send notification** queues in-app + push when token exists

## Admin create user

Edge Function **`admin-provision-user`** (admin JWT required):

- Creates Auth user + profile via trigger
- Optional auto-approve
- Returns temporary password if none supplied

Available from:
- iOS Admin → **Users** tab → **Create & approve**
- Web `/admin/users` → **Create & approve user**
- API `POST /api/admin/provision`

## Verify

```sql
SELECT * FROM public.push_outbox ORDER BY created_at DESC LIMIT 5;
SELECT user_id, platform, left(token, 12) FROM public.device_tokens;
```

Send a test from Admin → Users → open user → **Send in-app notification + push**.
