# Google Play — Marvi Society Android

Package: `com.marvisociety.app`  
Current version: **1.9.6** (versionCode **52**)

## One-time setup

1. **Google Play Console** — create app “Marvi Society”, category Social.
2. **Store listing** — short/long description (TR default + EN), icon 512×512, feature graphic 1024×500, phone screenshots. See `STORE_LISTING.md`.
3. **Privacy policy** — https://marvisociety.com/privacy
4. **Content rating** — complete questionnaire (`CONTENT_RATING.md`).
5. **Signing** — upload keystore already at `apps/android/marvi-release.jks` + `keystore.properties` (gitignored secrets).
6. **API access** (optional, for CLI upload) — service account JSON → `apps/android/play-service-account.json`

## Build release AAB

```bash
npm run build:android
npm run package:android
# Output: release/google-play/app-release.aab
```

Requires Android Studio (JDK + SDK) or `brew install openjdk@17` + Android SDK.

## Publish

### Option A — Manual (recommended until service account exists)

1. Play Console → **Testing** → **Internal testing** → Create release
2. Upload `release/google-play/app-release.aab`
3. Release name: `1.9.6 (52)` — notes in `STORE_LISTING.md`
4. Add testers → share opt-in link
5. After QA → **Production** → staged rollout

Full checklist: `SUBMIT_NOW.md`

### Option B — CLI

```bash
npm run build:android
npm run publish:android
# Default track: internal (MARVI_PLAY_TRACK=production for prod)
```

## Member onboarding (production)

1. Install from Play (or sideload internal track)
2. Sign up with email or Google
3. Complete creator or venue onboarding (profile / venue location)
4. Connect social accounts; team reviews membership
5. Accept offers, check in, submit proof; use community and DMs

## App Links

HTTPS links to `https://marvisociety.com/auth/callback` open the app when `assetlinks.json` is deployed with Play App Signing SHA-256. Custom scheme `marvisociety://` works without that file.

## Links

- Website: https://marvisociety.com
- iOS App Store: https://apps.apple.com/app/id6783450762
- Privacy: https://marvisociety.com/privacy
