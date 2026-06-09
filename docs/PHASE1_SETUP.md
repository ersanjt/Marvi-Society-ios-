# Phase 1 Setup — Supabase + iOS

## 1. Create Supabase project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) → New project
2. Region: `eu-central-1` (Frankfurt — closest to Istanbul)
3. Copy **Project URL** and **anon public key**

## 2. Run migrations

```bash
cd infra/supabase
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

Or paste SQL files manually in **SQL Editor** (in order):

1. `migrations/20260609000001_initial_schema.sql`
2. `migrations/20260609000002_rls_policies.sql`
3. `migrations/20260609000003_rpc_functions.sql`
4. `migrations/20260609000004_demo_leads_storage.sql`
5. `migrations/20260609000005_seed_function.sql`

## 3. Enable Auth providers

In **Authentication → Providers**:

- **Email** — enable (magic link or OTP)
- **Apple** — enable (requires Apple Developer Service ID)

### Apple Sign-In setup

1. Apple Developer → Identifiers → App ID `com.marvisociety.app` → Sign in with Apple
2. Create Services ID for Supabase redirect
3. Add redirect URL from Supabase Apple provider settings
4. Upload `.p8` key to Supabase

## 4. Configure iOS app

```bash
cp apps/ios/Config/Secrets.xcconfig.example apps/ios/Config/Secrets.xcconfig
```

Edit `Secrets.xcconfig`:

```xcconfig
MARVI_SUPABASE_URL = https://YOUR_REF.supabase.co
MARVI_SUPABASE_ANON_KEY = your-anon-key
MARVI_API_MODE = supabase
```

In Xcode: Project → Info → Configurations → set Debug/Release to use `Secrets.xcconfig`.

**Without Secrets.xcconfig** the app runs in **local demo mode** (UserDefaults).

## 5. Seed demo venues (staging)

1. Create a venue owner user in **Authentication → Users**
2. Copy their UUID from `auth.users`
3. Run in SQL Editor:

```sql
SELECT seed_istanbul_demo('YOUR_AUTH_USER_UUID');

-- Promote your account to admin:
UPDATE public.profiles
SET role = 'admin', status = 'approved'
WHERE id = 'YOUR_AUTH_USER_UUID';
```

Referral codes `MARVI-IST` and `MARVI2026` are inserted by the seed function.

## 5b. Configure web app

```bash
cp apps/web/.env.example apps/web/.env.local
```

Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` for demo form + admin APIs.

## 6. Verify API from iOS

1. Open app → complete onboarding
2. Profile → Settings → **Sync from server** (when remote mode on)
3. Accept an offer → booking should persist after app restart

## 7. Storage buckets

Included in migration `20260609000004_demo_leads_storage.sql`:

- `proof-uploads` — private creator proof screenshots
- `venue-media` — public venue images

iOS uploads to `proof-uploads/{user_id}/{booking_id}/proof-*.jpg` when `MARVI_API_MODE = supabase`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| RLS blocks reads | Ensure creator `status = approved` for restricted flows |
| `accept_offer` fails | Offer must be `live`, slots > 0 |
| Apple Sign-In fails | Check bundle ID matches Apple Services ID |
| App stays local | `MARVI_API_MODE` must be `supabase` and URL/key set |
