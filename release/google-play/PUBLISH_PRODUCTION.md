# Google Play — Publish Marvi Society (what can be automated vs Console)

Package: `com.marvisociety.app`  
Current binary: **1.9.6** (versionCode **52**) — already on **Internal testing**

## Hard limits (cannot be skipped)

### 1) This agent cannot log into your Google account
Play Console requires **your** Google login. There is no browser session or `play-service-account.json` on this machine, so upload/publish via API and clicking Console UI as you is not possible from here.

**To give API access (optional):** Play Console → Setup → API access → create service account with **Release Manager** → download JSON → save as:

`apps/android/play-service-account.json` (gitignored)

Then: `npm run publish:android` (internal) or `MARVI_PLAY_TRACK=production npm run publish:android` (only after production access is unlocked).

### 2) Production is blocked until Closed testing (personal accounts)
Per [Google Play policy](https://support.google.com/googleplay/android-developer/answer/14151465): personal developer accounts must run **Closed testing** with **≥ 12 opted-in testers for 14 consecutive days**, then **apply for production access**.  
**Internal testing does not count.**

You currently have ~6 emails — need **at least 12** people who:
1. Are on the Closed testing email list  
2. Open the **Closed** opt-in link and Accept  
3. Install and open the app  
4. Stay opted-in for 14 days  

## What is already ready in the repo

| Asset | Path |
|-------|------|
| Signed AAB | `release/google-play/app-release.aab` |
| Store text TR/EN | `docs/google-play/STORE_LISTING.md` |
| Content rating answers | `docs/google-play/CONTENT_RATING.md` |
| Data safety answers | `docs/google-play/DATA_SAFETY.md` |
| Icon / feature graphic / screenshots | `release/google-play/` |
| Tester emails (current) | `release/google-play/testers-internal.csv` |

Privacy: https://marvisociety.com/privacy  
Terms: https://marvisociety.com/terms  

## Exact Console path to public release

### A — Finish app setup (fixes Item not found + unreviewed name)
Dashboard / App content — complete all red tasks:
1. Main store listing (TR default + EN) — paste from `STORE_LISTING.md`
2. Upload icon-512, feature-graphic, phone screenshots
3. Privacy policy URL
4. Ads = No
5. Content rating questionnaire
6. Target audience 18+
7. Data safety form
8. **Publishing overview → Send changes for review** if prompted

### B — Closed testing (required for production)
1. Test and release → **Closed testing** → Create track (e.g. Closed) if needed  
2. Create release → upload same `app-release.aab` (52)  
3. Testers → email list with **≥ 12** Google accounts  
4. Copy **Closed** opt-in link (different from Internal)  
5. Each tester: Accept → Download → open app once  
6. Wait until Console shows 12+ opted-in for **14 days**  
7. Dashboard → **Apply for production access** → answer questionnaire  

### C — Production
1. Production → Create release → promote Closed / upload AAB  
2. Countries: Turkey + markets you want  
3. Roll out (staged 20% recommended first)  

## Why Internal testers saw Item not found
Opt-in worked; Play Store still 404’d the listing because the app is **Draft / unreviewed** and/or the Play app used a different Google account than the browser. Completing section A usually fixes installability for testers.

## Agent checklist (run when SA JSON is present)

```bash
npm run build:android
npm run package:android
npm run publish:android   # needs play-service-account.json
npm run status
```
