# TestFlight upload (API key)

Automated upload uses an **App Store Connect API** key (not your Apple ID password).

## One-time setup (Mac)

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys**
2. Create a key (e.g. **Marvi TestFlight Upload**) with **Admin** access
3. Download `AuthKey_<KEY_ID>.p8` once (cannot re-download)
4. Install the key:

```bash
mkdir -p ~/.appstoreconnect/private_keys
cp ~/Downloads/AuthKey_JT328F7C3Z.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_JT328F7C3Z.p8
```

| Setting | Value |
|---------|-------|
| Key ID | `JT328F7C3Z` |
| Issuer ID | `8b84fa76-827a-48b1-bbce-71bdce84ac52` |
| Key file | `~/.appstoreconnect/private_keys/AuthKey_JT328F7C3Z.p8` |

Never commit `.p8` files to git.

## Build + upload

```bash
npm run build:ios
npm run upload:ios
```

Or one command:

```bash
npm run testflight
```

Custom IPA path:

```bash
bash scripts/ios/upload-testflight.sh /path/to/MarviSociety.ipa
```

Override credentials via env:

```bash
export APP_STORE_CONNECT_API_KEY_ID=JT328F7C3Z
export APP_STORE_CONNECT_ISSUER_ID=8b84fa76-827a-48b1-bbce-71bdce84ac52
export APP_STORE_CONNECT_API_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_JT328F7C3Z.p8
npm run upload:ios
```

## After upload

1. Wait for **Processing** in TestFlight (build number appears, e.g. **1.0 (11)**)
2. App Store Connect → **App Review Information**:
   - `review@marvisociety.com` / `MarviReview2026!`
3. Paste notes from `docs/app-store/CONNECT_PASTE.txt`
4. Select the new build → **Resubmit to App Review**

## GitHub Actions (optional)

For CI upload you would add secrets:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8` (full `.p8` file contents)

iOS archive still requires a **macOS** runner with signing certificates. Local `npm run testflight` is the supported path for now.
