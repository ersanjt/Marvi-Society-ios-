# Apple Sign-In — iOS + Supabase

Native Sign in with Apple via `ASAuthorizationAppleIDProvider` → Supabase `id_token` grant.

## Apple Developer (one-time)

### Already done in your account
| Item | Value |
|------|--------|
| App ID | `com.marvisociety.app` |
| Key name | `marvi` |
| Key ID | `J79M28T33W` |
| Team ID | `GG773SAZP9` |
| `.p8` file | `AuthKey_J79M28T33W.p8` (keep private) |

### Services ID (required — finish if not registered)

1. **Identifiers** → **+** → **Services IDs** → Continue  
2. **Description:** `Marvi Society Auth`  
3. **Identifier:** `com.marvisociety.app.auth`  
4. Register → open it → enable **Sign In with Apple** → Configure  
5. **Primary App ID:** `com.marvisociety.app`  
6. **Return URL:**
   ```
   https://gaswjuvyzliislqrljof.supabase.co/auth/v1/callback
   ```

## Supabase Dashboard

Open paste file (gitignored, generated locally):

`apps/ios/Config/APPLE_SUPABASE_PASTE.txt`

Or regenerate Secret Key (JWT):

```bash
./scripts/apple/generate-client-secret.sh \
  --p8 ~/Downloads/AuthKey_J79M28T33W.p8 \
  --key-id J79M28T33W \
  --team-id GG773SAZP9 \
  --client-id com.marvisociety.app.auth
```

**Important:** Paste the **JWT string** into Secret Key — not the `.p8` file contents.

| Field | Value |
|-------|--------|
| Enable | ON |
| Client IDs | `com.marvisociety.app,com.marvisociety.app.auth` |
| Secret Key | output of script above |
| Allow users without email | OFF |

**URL Configuration** → add `marvisociety://auth/callback` to Redirect URLs.

## iOS build

`MARVI_APPLE_SIGN_IN_ENABLED = YES` in `Secrets.xcconfig`.

Current build after Apple + Google: **1.0 (5)**.

## Regenerate secret (~every 6 months)

Apple OAuth secrets expire. Re-run `generate-client-secret.sh` and update Supabase.
