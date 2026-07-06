# Google Play — Marvi Society Android

Package: `com.marvisociety.app`  
Current version: **1.4.1** (versionCode **32**)

## One-time setup

1. **Google Play Console** — create app “Marvi Society”, category Social.
2. **Store listing** — short/long description (TR + EN), icon 512×512, feature graphic 1024×500, phone screenshots.
3. **Privacy policy** — https://marvisociety.com/privacy
4. **Content rating** — complete questionnaire in Play Console.
5. **Signing** — generate upload keystore:

```bash
bash scripts/google-play/generate-keystore.sh
cp apps/android/keystore.properties.example apps/android/keystore.properties
# Edit passwords
```

6. **API access** (optional, for CLI upload) — service account JSON → `apps/android/play-service-account.json`

## Build release AAB

```bash
npm run build:android
# Output: apps/android/app/build/outputs/bundle/release/app-release.aab
```

Requires Android Studio (JDK + SDK) or `brew install openjdk@17` + Android SDK.

## Publish

### Option A — Manual (no API)

1. Play Console → **Testing** → **Internal testing** → Create release
2. Upload `app-release.aab`
3. Add testers → share opt-in link
4. After QA → **Production** → staged rollout

### Option B — CLI

```bash
npm run build:android
npm run publish:android
# Default track: internal (MARVI_PLAY_TRACK=production for prod)
```

## Member onboarding flow (production)

1. User installs from Play Store
2. Opens app → email sign-up / sign-in (Supabase)
3. Completes profile in **Profile** tab: invite code, IG + TikTok, DM verification code to @marvisociety
4. Admin approves membership → user accepts offers

Backend gates are enforced in `accept_offer` (migration 014).

## Links

- Website download: https://marvisociety.com/creators
- iOS App Store: https://apps.apple.com/app/id6783450762
- Play Store: set `NEXT_PUBLIC_PLAY_STORE_URL` on Vercel after first publish
