# Android App Links

Verified HTTPS links (`https://marvisociety.com/auth/callback`) need Digital Asset Links.

## Enable

1. After the first Play Console upload, open **Setup → App integrity → App signing**.
2. Copy the **App signing key certificate** SHA-256 (colon-separated hex).
3. Copy `apps/web/public/.well-known/assetlinks.json.example` → `assetlinks.json`.
4. Replace `PLAY_APP_SIGNING_SHA256` with that fingerprint.
5. Deploy the website so this URL returns JSON:

   `https://marvisociety.com/.well-known/assetlinks.json`

6. On a device: Settings → Apps → Marvi Society → Open by default → verify links, or wait for OS verification.

Custom scheme `marvisociety://` works without this file.

Do **not** commit a fake fingerprint — verification will fail until the real Play App Signing SHA-256 is used.
