# Marvi Society — Platform Status

Single source of truth for dual-platform readiness. Versions also live in [`release/manifest.json`](../release/manifest.json).

**Last reviewed:** 2026-09-13

| Surface | Version | Status |
|---------|---------|--------|
| **iOS** | 1.5.4 (103) | Repo + Xcode 26.5 ready; last GitHub sync 2026-09-01. TestFlight upload needs a valid ASC session. |
| **Android** | 1.9.13 (59) | Compose client in repo; signed keystore present locally. Last packaged AAB on disk is **1.9.7 (53)** — Play still needs a newer bundle + closed testers. |
| **Web (repo)** | 1.5.4 code on `main` | Marketing, portal, admin, `/pricing`, `/cookies`, Stripe billing. |
| **Web (live)** | older WHM build | [marvisociety.com](https://marvisociety.com) is up (`/api/health` ok) but **not redeployed** after the 2026-08-31 billing commit. `/pricing` and `/cookies` are **404** in production. `/.well-known/assetlinks.json` is 200. |
| **Database** | head `20260831020001_venue_billing_safety_and_trust` (81 migrations) | Combined SQL updated 2026-09-01; Supabase CLI linked. Public anon health check currently returns empty live offers (RLS and/or no live campaigns). Self-hosted PostgreSQL 17 path (`scripts/selfhost/`) verified locally with `npm run selfhost:test` (schema, booking/RLS smoke, dump→restore). Not yet installed on the VPS; apps still point at Supabase until the API cutover. |

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
| 18+ onboarding + legal | Yes | Yes |
| Safety reports | Yes (schema + clients) | Yes |

## What is healthy right now

- `main` is aligned with `origin/main` at `4b35301` (2026-09-01).
- Live site homepage, legal (`/privacy`, `/terms`, `/community-guidelines`), portal login, invite, demo, FAQ, App Links JSON, and `/api/health` (`status: ok`, Supabase configured).
- Local toolchain: Xcode 26.5, Android Studio, JDK 17, Node 22, iOS 26.5 simulators, Android AVD `Marvi_API35`, Apple Development cert, ASC `.p8` at `~/.appstoreconnect/private_keys/`.
- Android upload keystore: `apps/android/marvi-release.jks` + `keystore.properties`.

## Ops blockers (need your login / a deploy)

1. **Production web is stale** — run `npm run web:deploy` (SSH to WHM) so `/pricing`, `/cookies`, billing, and the Pricing nav go live. GitHub Actions deploy targets Vercel and skips when `VERCEL_TOKEN` is unset; live traffic is WHM.
2. **GitHub CLI token expired** — `gh auth refresh -h github.com` (or `gh auth login`). Until then, push/CI/PRs from this Mac will fail.
3. **Local web env** — `apps/web/.env.local` was missing; a placeholder copy of `.env.example` is in place. Replace `your-anon-key` / service role with the real Supabase values (same project as iOS `Secrets.xcconfig`) before local portal/admin work.
4. **Google Play public listing** — still blocked on ≥12 opted-in closed testers for 14 days (last recorded: 0). Newest repo version is 1.9.13 (59); upload a fresh AAB after testers exist.
5. **Health check “empty offers”** — `npm run health` cannot see live `offers` / `offers_public` / `venue_profiles` with the anon key. Confirm in Supabase whether campaigns are live or RLS/grants hide them.
6. **Homebrew** — App Studio doctor still wants a one-time Homebrew install (password).

## Local artifacts

- Android signed AAB (older): `release/google-play/app-release-1.9.7-53.aab`
- Toolchain: `.tools/node`, `.tools/bin/supabase`, `.tools/jdk`, `.tools/android-sdk`
- Local configs (gitignored): `apps/ios/Config/Secrets.xcconfig`, `apps/android/local.properties`, `apps/android/marvi-release.jks`, `apps/web/.env.local`
