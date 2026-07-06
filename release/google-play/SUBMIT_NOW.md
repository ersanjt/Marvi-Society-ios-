# Google Play — Submit now (verified developer account)

Package: `com.marvisociety.app`  
Version: **1.4.1** (versionCode **32**)

## Files ready in repo

| Asset | Path |
|-------|------|
| Signed AAB | `apps/android/app/build/outputs/bundle/release/app-release.aab` |
| Release bundle (copy for upload) | `release/google-play/` |
| Store text EN/TR | `docs/google-play/STORE_LISTING.md` |
| Content rating answers | `docs/google-play/CONTENT_RATING.md` |
| Data safety answers | `docs/google-play/DATA_SAFETY.md` |
| Phone screenshots | `release/google-play/screenshots/phone/` |
| Hi-res icon 512 | `release/google-play/icon-512.png` |

## Step 1 — Create app (once)

1. [Play Console](https://play.google.com/console) → **Create app**
2. App name: **Marvi Society**
3. Default language: **English (United States)** — add Turkish in Store listing later
4. App or game: **App**
5. Free or paid: **Free**
6. Declarations: accept policies

## Step 2 — Store listing

**Main store listing** → fill:

- **App name:** Marvi Society
- **Short description:** copy from `STORE_LISTING.md`
- **Full description:** copy EN block
- **App icon:** upload `release/google-play/icon-512.png`
- **Feature graphic:** upload `release/google-play/feature-graphic.png` (if missing, use icon on 1024×500 canvas in Canva)
- **Phone screenshots:** upload all PNGs from `release/google-play/screenshots/phone/`
- **App category:** Social
- **Email:** support@marvisociety.com
- **Privacy policy:** https://marvisociety.com/privacy

**Store listings** → add **Turkish (Türkiye)** → paste TR short/full description.

## Step 3 — App content (required before review)

| Section | Value |
|---------|--------|
| Privacy policy | https://marvisociety.com/privacy |
| Ads | No ads |
| App access | All functionality available without special access (invite is in-app, not restricted demo) |
| Content rating | Start questionnaire → see `CONTENT_RATING.md` |
| Target audience | 18+ |
| News app | No |
| COVID / government | No |
| Data safety | See `DATA_SAFETY.md` |

## Step 4 — Upload AAB

1. **Release** → **Testing** → **Internal testing** → **Create new release**
2. Upload `app-release.aab`
3. Release name: `1.4.1 (32)`
4. Release notes: `Initial Android release. Creator onboarding, social verification, offers, community.`
5. **Save** → **Review release** → **Start rollout to Internal testing**

Add testers (email list) or use **Open testing** later.

## Step 5 — Production review

After internal QA (1–2 days):

1. **Release** → **Production** → **Create new release**
2. Promote the tested bundle or re-upload same AAB
3. Countries: all (or Turkey + key markets first)
4. **Send for review**

Review usually 1–7 days.

## Step 6 — After live

1. Copy Play Store URL → Vercel env `NEXT_PUBLIC_PLAY_STORE_URL`
2. `npm run web:deploy`
3. Share link: https://marvisociety.com/creators

## CLI upload (optional)

If you add service account JSON at `apps/android/play-service-account.json`:

```bash
npm run build:android
MARVI_PLAY_TRACK=internal npm run publish:android
# Production: MARVI_PLAY_TRACK=production npm run publish:android
```

## Keystore backup

Upload keystore is at `apps/android/marvi-release.jks` (gitignored).  
**Back up** `marvi-release.jks` + `keystore.properties` to 1Password — required for all future updates.
