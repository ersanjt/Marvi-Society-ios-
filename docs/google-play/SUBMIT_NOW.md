# Google Play — Submit now (verified developer account)

Package: `com.marvisociety.app`  
Version: **1.9.6** (versionCode **52**)

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
| Feature graphic | `release/google-play/feature-graphic.png` |

## Step 1 — Create app (once)

1. [Play Console](https://play.google.com/console) → **Create app**
2. App name: **Marvi Society**
3. Default language: **Turkish (Türkiye)** — add English in Store listing
4. App or game: **App**
5. Free or paid: **Free**
6. Declarations: accept policies

## Step 2 — Store listing

**Main store listing** → fill from `STORE_LISTING.md`:

- **App name:** Marvi Society
- **Short / full description:** Turkish first, then English locale
- **App icon:** `release/google-play/icon-512.png`
- **Feature graphic:** `release/google-play/feature-graphic.png`
- **Phone screenshots:** `release/google-play/screenshots/phone/`
- **App category:** Social
- **Email:** support@marvisociety.com
- **Privacy policy:** https://marvisociety.com/privacy

## Step 3 — App content (required before review)

| Section | Value |
|---------|--------|
| Privacy policy | https://marvisociety.com/privacy |
| Ads | No ads |
| App access | All functionality available without special access |
| Content rating | See `CONTENT_RATING.md` |
| Target audience | 18+ |
| News app | No |
| Data safety | See `DATA_SAFETY.md` |

## Step 4 — Upload AAB

1. **Release** → **Testing** → **Internal testing** → **Create new release**
2. Upload `release/google-play/app-release.aab` (or rebuild with `npm run build:android && npm run package:android`)
3. Release name: `1.9.6 (52)`
4. Release notes: copy from `STORE_LISTING.md`
5. **Save** → **Review release** → **Start rollout to Internal testing**

Optional CLI (needs `apps/android/play-service-account.json`):

```bash
npm run build:android
npm run publish:android
```

## Step 5 — App Links (after first Play upload)

1. Play Console → **Setup** → **App integrity** → **App signing** → copy **SHA-256 certificate fingerprint**
2. Put it in `apps/web/public/.well-known/assetlinks.json` (replace `PLAY_APP_SIGNING_SHA256`)
3. Deploy web so `https://marvisociety.com/.well-known/assetlinks.json` returns 200

## Step 6 — Production review

After internal QA:

1. **Release** → **Production** → create release / promote tested bundle
2. Countries: Turkey + key markets (or all)
3. **Send for review**

## Step 7 — After live

1. Set Vercel env `NEXT_PUBLIC_PLAY_STORE_URL` to the Play Store URL
2. `npm run web:deploy`
