# Marvi Society — Platform Status

Single source of truth for dual-platform readiness. Versions also live in [`release/manifest.json`](../release/manifest.json).

| Surface | Version | Status |
|---------|---------|--------|
| **iOS** | 1.5.1 (51) | Live on App Store; establishment wizard + booking integrity |
| **Android** | 1.9.7 (53) | First-class Compose client; Play public listing pending; internal/closed track ready after AAB |
| **Web** | 0.2.0 | Marketing + portal + admin on marvisociety.com |
| **Database** | head `20260809164025_harden_function_execution_and_search_path` (50 migrations) | Applied and verified on Production; Security Advisor: 0 errors |

## Parity checklist (creator + venue)

| Flow | iOS | Android |
|------|-----|---------|
| Email / Google auth | Yes | Yes |
| Apple Sign-In | Yes (required when Google on) | N/A |
| Discover / bookings / check-in / proof | Yes | Yes |
| Community / DMs | Yes | Yes |
| Admin queue | Yes | Yes |
| Venue establishment wizard (org → brand → establishment) | Yes | Yes |
| In-app account delete | Yes | Yes |
| Session refresh on 401 | Yes | Yes |

## Ops blockers (need your login)

1. **Xcode.app** — not installed on this Mac (only Command Line Tools); iOS archive/TestFlight needs full Xcode or macOS CI.
2. **Google Play upload key** — the existing release keystore is not present locally; version 1.9.7 (53) cannot be uploaded until the key is restored or an official upload-key reset is completed.
3. **Google Play production access** — requires at least 12 opted-in closed-test users for 14 days; the console currently shows 0 testers.
4. **GitHub publish** — local branch is ready, but GitHub CLI is not installed/authenticated, so push + CI + draft PR are pending.
5. **Web deployment** — deploy the updated `assetlinks.json`; the live URL remains 404 until the web release reaches production.
6. Set `SUPABASE_SERVICE_ROLE_KEY` in the production web environment for admin/delete server paths.

### Local artifacts produced this session

- Android debug APK: `release/android-debug/app-debug-1.9.7.apk` (BUILD SUCCESSFUL)
- Toolchain: `.tools/node`, `.tools/bin/supabase`, `.tools/jdk`, `.tools/android-sdk`
- Local configs (gitignored): `apps/ios/Config/Secrets.xcconfig`, `apps/android/local.properties`, `apps/web/.env.local`
