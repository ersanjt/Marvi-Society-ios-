# App Review Rejection Fix — 24 June 2026

**Submission ID:** `4e7dbf2a-e85f-42df-95e9-ee6b8551e2ce`  
**Device:** iPad Air 11-inch (M3), iPadOS 26.5

## Why Apple rejected

| Issue | Guideline | Cause |
|-------|-----------|--------|
| Sign in with Apple error | 2.1(a) Performance | Supabase Apple provider not configured; reviewer tapped Apple on iPad |
| Cannot access all features | 2.1(a) Information Needed | Demo credentials missing or incomplete in App Review Information |

## Code fixes (this repo)

1. **Sign in with Apple hidden by default** — `MARVI_APPLE_SIGN_IN_ENABLED = NO` until Supabase Apple is configured
2. **Email login first** on sign-in screen
3. **iPad presentation anchor** fixed for Apple sheet (if re-enabled later)
4. **Review account SQL** — admin role + creator + venue + referral `MARVI-IST`

## Step 1 — Supabase (5 min)

SQL Editor → run entire file:

```
infra/supabase/provision-review-account.sql
```

Expected: `role = admin`, `status = approved`, venue row, `offers_live` ≥ 1

## Step 2 — Build 1.0 (6) — email-only for App Review

1. Confirm `apps/ios/Config/Secrets.xcconfig` has `MARVI_APPLE_SIGN_IN_ENABLED = NO` and `MARVI_GOOGLE_SIGN_IN_ENABLED = NO`
2. Or: `bash scripts/app-store/build-ios-release.sh`
3. Archive → Distribute → App Store Connect
4. Wait for processing in TestFlight

## Step 3 — App Review Information

**App Store Connect → Distribution → 1.0 → App Review Information**

| Field | Value |
|-------|--------|
| Sign-in required | **Yes** |
| User name | `review@marvisociety.com` |
| Password | `MarviReview2026!` |

**Notes (paste from `docs/app-store/CONNECT_PASTE.txt`):**

See CONNECT_PASTE.txt for the full Notes and Reply text (build 1.0 (6), email-only).

## Step 4 — Reply to App Review

Paste the **Reply** section from `docs/app-store/CONNECT_PASTE.txt`.

## Step 5 — Resubmit

1. Attach **build 1.0 (6)** (not 1 or 5)
2. **Save**
3. **Resubmit to App Review**

## Optional later — enable Apple + Google sign-in

1. Apple Developer → Services ID + Sign in with Apple key
2. Supabase → Authentication → Apple provider
3. Set `MARVI_APPLE_SIGN_IN_ENABLED = YES` in `Secrets.xcconfig`
4. Rebuild and submit

Until then, keep Apple sign-in **disabled**.
