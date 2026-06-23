# App Store — Final submit guide (Marvi Society v1.0)

> **مهم:** فایل‌های `.sh` فقط در **WHM Terminal** اجرا شوند.  
> فایل‌های `.sql` فقط در **Supabase SQL Editor** اجرا شوند.

## ✅ Already done (production)

- WHM deploy live — `https://marvisociety.com` health **ok**
- Supabase DB + RPCs verified
- iOS TestFlight build **1.0 (1)** uploaded
- Legal pages: privacy, terms, delete-account, contact
- `review@marvisociety.com` cPanel mailbox created

---

## Step 1 — Review account (5 min)

### Supabase SQL Editor only

1. Open **SQL → New query**
2. Paste **entire** file: `infra/supabase/provision-review-account.sql`
3. Click **Run**
4. Results should show: `auth_user`, `profiles` (approved), `creator` (approved), `offers_live` ≥ 1

Credentials for Apple Review Notes:

| Field | Value |
|-------|--------|
| Email | `review@marvisociety.com` |
| Password | `MarviReview2026!` |
| Invite code | `MARVI-IST` (only if app asks on first launch) |

### Optional: WHM Terminal (not SQL Editor)

```bash
export SUPABASE_SERVICE_ROLE_KEY='YOUR_sb_secret_KEY'
bash scripts/app-store/provision-review-account.sh
```

Then run `setup-review-account.sql` if profile row missing.

### Test on iPhone

1. Sign out → Sign in with **review@marvisociety.com** / password
2. If new user: invite code **MARVI-IST** (creator code, not MARVI2026)
3. Explore → open an offer → Accept
4. Profile → Delete account link opens web page

---

## Step 2 — SMTP for delete-account OTP (10 min)

Supabase → **Authentication → SMTP Settings → Enable custom SMTP**

### Option A — cPanel mail (you already have review@)

| Field | Value |
|-------|--------|
| Host | `mail.marvisociety.com` |
| Port | `465` |
| Username | `review@marvisociety.com` |
| Password | cPanel email password |
| Sender email | `review@marvisociety.com` |
| Sender name | `Marvi Society` |

### Option B — Resend (better deliverability)

See `docs/EMAIL_SETUP.md` — host `smtp.resend.com`, port `465`

**Test:** https://marvisociety.com/delete-account → enter review email → OTP arrives

---

## Step 3 — App Store Connect (30–45 min)

Open [App Store Connect](https://appstoreconnect.apple.com) → **Marvi Society** → **1.0 Prepare for Submission**

### Metadata (copy from `docs/app-store/LISTING.md`)

| Field | Value |
|-------|--------|
| Name | Marvi Society |
| Subtitle | Private creator × venue club |
| Category | Lifestyle (+ Social Networking) |
| Privacy URL | https://marvisociety.com/privacy |
| Support URL | https://marvisociety.com/contact |
| Age rating | 17+ |

### Build

- **Build** section → select **1.0 (1)**
- Export compliance: **No** non-exempt encryption

### Screenshots (required — 6.7" iPhone)

Capture on iPhone 15 Pro Max simulator (1290×2796):

1. Explore list
2. Offer detail
3. My Events
4. Check-in / Proof sheet
5. Profile + legal links

Xcode → Simulator → **Cmd+S** to save screenshot

### App Privacy

Match `apps/ios/MarviSociety/PrivacyInfo.xcprivacy`:

- Email, Name, User ID, Photos, Precise Location
- **Not used for tracking**

### Review Notes (paste exactly)

```
Marvi Society is an invite-only creator × venue marketplace for Istanbul.

Test account:
Email: review@marvisociety.com
Password: MarviReview2026!
Invite code (if prompted on first launch): MARVI-IST

Flow: Sign in → Explore tab shows live venue offers → tap offer → Accept → appears in My Events.

Sign in with Apple is also supported.

Account deletion: Profile → Delete Account (opens https://marvisociety.com/delete-account with email OTP).

No in-app purchases. No ads. 18+ confirmed at onboarding.
Export: app uses HTTPS only (no custom encryption).
```

### Availability

**Pricing and Availability** → select **all countries** for global release.

---

## Step 4 — Submit

Click **Add for Review** → **Submit to App Review**

Typical review: 24–48 hours.

---

## After approval

1. Copy App Store URL from Connect
2. Update `apps/web/src/lib/constants.ts` → `appStoreUrl`
3. Redeploy web: `bash scripts/deploy/whm-fix-all.sh` on server

---

## Rejection prevention checklist

| Risk | Status |
|------|--------|
| Demo account works | Run Step 1 + test |
| Delete account OTP | Configure SMTP Step 2 |
| Screenshots | Step 3 |
| Privacy labels match app | Step 3 |
| Legal URLs load | ✅ live |
