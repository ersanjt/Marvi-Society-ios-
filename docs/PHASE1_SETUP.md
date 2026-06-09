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

1. Create a venue owner user in Auth
2. Insert venue profile linked to that `auth.users.id`
3. Run offer inserts from `infra/supabase/seed.sql` (update `owner_user_id`)

Or use SQL Editor:

```sql
-- After first signup, promote to admin:
UPDATE public.profiles
SET role = 'admin', status = 'approved'
WHERE email = 'you@example.com';
```

## 6. Verify API from iOS

1. Open app → complete onboarding
2. Profile → Settings → **Sync from server** (when remote mode on)
3. Accept an offer → booking should persist after app restart

## 7. Storage bucket (proof uploads — Phase 1b)

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('proof-uploads', 'proof-uploads', false);

CREATE POLICY proof_upload_own ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| RLS blocks reads | Ensure creator `status = approved` for restricted flows |
| `accept_offer` fails | Offer must be `live`, slots > 0 |
| Apple Sign-In fails | Check bundle ID matches Apple Services ID |
| App stays local | `MARVI_API_MODE` must be `supabase` and URL/key set |
