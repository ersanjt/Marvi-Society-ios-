# Marvi — Next actions (2026-08-10)

## Done in this session

- Workspace on `main` @ `8d92500`
- New Android upload keystore generated (gitignored):
  - `apps/android/marvi-release.jks`
  - `apps/android/keystore.properties`
  - `apps/android/KEYSTORE_BACKUP.local.txt`
  - `apps/android/upload_certificate.pem`
- Signed AAB: `release/google-play/app-release-1.9.7-53.aab`
- Play Closed testing Alpha draft prepared; library has bundle **52 / 1.9.6**
- App Signing SHA-256 matches repo `assetlinks.json`
- Live: `/api/health` 200; `/.well-known/assetlinks.json` still 404

## Clicks only you can finish (file picker / human testers)

1. Play → App signing → Request upload key reset → reason **I lost my upload key** → upload `apps/android/upload_certificate.pem` → Request
2. Play → Closed testing → Alpha → Edit release → **Add from library** → select **52 / 1.9.6** → release notes → Next → Send for review
3. Grow Closed testers to **≥12 opted-in for 14 days**
4. Deploy web (WHM SSH or Vercel secrets) so assetlinks returns JSON
5. After reset approval: upload `app-release-1.9.7-53.aab`
