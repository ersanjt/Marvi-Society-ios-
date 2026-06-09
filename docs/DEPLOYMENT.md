# Marvi Society — Deployment Guide

## Prerequisites

- GitHub repo: [Marvi-Society-ios-](https://github.com/ersanjt/Marvi-Society-ios-)
- Supabase account (free tier OK for beta)
- Vercel account (web)
- Apple Developer account (iOS TestFlight)
- Google Play Console (Android, Phase 4)

---

## 1. Supabase backend

1. Create a project at [supabase.com](https://supabase.com).
2. Install CLI: `npm i -g supabase`
3. Link and push migrations:

```bash
cd infra/supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

4. Seed Istanbul demo data (replace with a real auth user UUID after first signup):

```sql
SELECT seed_istanbul_demo('00000000-0000-0000-0000-000000000001');
```

5. Enable **Apple** provider under Authentication → Providers.
6. Copy **Project URL** and **anon key** from Settings → API.

See [PHASE1_SETUP.md](./PHASE1_SETUP.md) for RLS and RPC details.

---

## 2. Web (Vercel)

1. Import the GitHub repo in Vercel.
2. Set root directory to `apps/web`.
3. Add environment variables from `apps/web/.env.example`:

| Variable | Scope |
|----------|-------|
| `NEXT_PUBLIC_SUPABASE_URL` | Production + Preview |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Production + Preview |
| `SUPABASE_SERVICE_ROLE_KEY` | Production only |
| `NEXT_PUBLIC_SITE_URL` | `https://marvisociety.com` |

4. Deploy. Custom domain: `marvisociety.com` → Vercel DNS.

**Routes:**
- Marketing: `/`, `/creators`, `/brands`, `/faq`, `/demo`
- Portal: `/portal/login`, `/portal/dashboard`
- Admin: `/admin` (requires Supabase auth)

---

## 3. iOS (TestFlight)

1. Open `apps/ios/MarviSociety.xcodeproj` on macOS.
2. Copy `apps/ios/Config/Secrets.xcconfig.example` → `Secrets.xcconfig`.
3. Set:

```
MARVI_SUPABASE_URL = https://YOUR_PROJECT.supabase.co
MARVI_SUPABASE_ANON_KEY = your-anon-key
MARVI_API_MODE = supabase
```

4. Configure Sign in with Apple capability + bundle ID `com.marvisociety.app`.
5. Archive → Upload to App Store Connect → TestFlight.

---

## 4. Android (Phase 4)

1. Open `apps/android` in Android Studio Ladybug+.
2. Sync Gradle, set `local.properties` SDK path.
3. Add `secrets.properties` with Supabase URL/key (see `apps/android/README.md`).
4. Build release AAB → Play Console internal testing.

---

## 5. CI

GitHub Actions (`.github/workflows/ci.yml`) runs on `main` / `develop`:

- Docs + OpenAPI validation
- Next.js production build
- iOS simulator build (macOS runner)

Add Supabase env vars to GitHub Secrets only if you need integration tests later.

---

## 6. Post-deploy checklist

- [ ] Migrations applied, `seed_istanbul_demo` run
- [ ] Web demo form writes to `demo_requests`
- [ ] Portal login works for venue accounts
- [ ] Admin queue shows open tasks
- [ ] iOS syncs offers/bookings in Supabase mode
- [ ] Privacy, terms, delete-account pages live
- [ ] EN/TR locale switcher on marketing site

---

## Environment matrix

| Surface | Local dev | Production |
|---------|-----------|------------|
| Web | `npm run dev` in `apps/web` | Vercel |
| iOS | Local demo (default) or Secrets.xcconfig | TestFlight |
| Android | Emulator + local demo | Play internal |
| DB | `supabase start` or cloud | Supabase cloud |
