# Google (Gmail) Sign-In — iOS + Supabase

The iOS app uses **Supabase OAuth** with `ASWebAuthenticationSession` (no Google SDK).

**Flow (preferred):** Google → Supabase → `marvisociety://auth/callback?code=…` → app (direct, no website).

**Fallback (if deep link blocked):** Supabase → `https://marvisociety.com/auth/ios-callback` → 302 → app.

## 1. Google Cloud Console

1. Open [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.
2. Create **OAuth 2.0 Client ID** → type **Web application** (used by Supabase).
3. Authorized redirect URIs — add your Supabase callback:
   ```
   https://gaswjuvyzliislqrljof.supabase.co/auth/v1/callback
   ```
4. Copy **Client ID** and **Client Secret**.

## 2. Supabase Dashboard

**Authentication → Providers → Google**

- Enable Google.
- Paste Client ID and Client Secret from step 1.

**Authentication → URL Configuration**

- **Site URL:** `https://marvisociety.com`
- **Redirect URLs** (add all — required):
  ```
  marvisociety://auth/callback
  https://marvisociety.com/auth/ios-callback
  https://marvisociety.com/auth/callback
  ```

The first line (`marvisociety://…`) is what the iOS app uses. Without it, users land on the website.

Deploy web so `/auth/ios-callback` exists as fallback: `bash /root/whm-install-from-git.sh`

## 3. iOS build flag

In `apps/ios/Config/Secrets.xcconfig`:

```
MARVI_GOOGLE_SIGN_IN_ENABLED = YES
```

## 4. Test on device

1. Build and run on a physical iPhone.
2. Onboarding → **Google ile devam et**.
3. After Google login, the sheet should close and the app continues (not the website).

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| Lands on marvisociety.com / portal | Add `marvisociety://auth/callback` to Supabase Redirect URLs; redeploy web for `/auth/ios-callback`. |
| Browser opens but app never returns | Confirm `Marvi-URLTypes.plist` scheme `marvisociety` is in the target. |
| "Google sign-in did not return a session" | Enable Google provider; verify Google Cloud redirect URI = Supabase callback URL. |
