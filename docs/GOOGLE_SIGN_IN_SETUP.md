# Google (Gmail) Sign-In — iOS + Supabase

The iOS app uses **Supabase OAuth** with `ASWebAuthenticationSession` (no Google SDK).

**Flow:** Google → Supabase → `https://marvisociety.com/auth/callback?client=ios` → `marvisociety://auth/callback` → app.

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
- **Redirect URLs** (add all):
  ```
  https://marvisociety.com/auth/callback
  https://marvisociety.com/auth/callback?client=ios
  marvisociety://auth/callback
  ```

**Important:** `/auth/callback` must be deployed on production (`npm run web:deploy`). Without it, Google sign-in opens the marketing homepage instead of returning to the app.

## 3. iOS build flag

In `apps/ios/Config/Secrets.xcconfig`:

```
MARVI_GOOGLE_SIGN_IN_ENABLED = YES
```

Set to `NO` to hide the Google button (e.g. before provider is configured).

Apple Sign-In stays separate: `MARVI_APPLE_SIGN_IN_ENABLED = NO` until Apple provider is configured in Supabase.

## 4. Test on device

1. Build and run on a physical iPhone (Simulator may work; OAuth is more reliable on device).
2. Onboarding → Sign in → **Continue with Google**.
3. Complete Google login in the browser sheet; app should return and continue onboarding.

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| Browser opens but app never returns | Deploy web (`/auth/callback`); add redirect URLs above; rebuild iOS after fix. |
| Lands on marvisociety.com homepage | Same — `/auth/callback` missing on production or redirect URL not allowlisted in Supabase. |
| "Google sign-in did not return a session" | Enable Google provider in Supabase; verify Google Cloud redirect URI matches Supabase callback URL. |
| Provider error in browser | Check Client ID/Secret in Supabase; ensure Google OAuth consent screen is configured. |
