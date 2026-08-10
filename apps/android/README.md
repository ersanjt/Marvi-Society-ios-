# Marvi Society — Android

Kotlin + Jetpack Compose app aligned with the iOS Marvi Society client.

**Current:** 1.9.7 (versionCode 53)

## Stack

- Kotlin 2.1 + Jetpack Compose + Material 3
- Ktor HTTP client (mirrors iOS lightweight Supabase REST client)
- DataStore session persistence
- Coil (images / avatars)
- Navigation Compose with role-based tabs (Creator / Venue / Admin)
- Default UI language: Turkish (EN available)

## Setup

1. Install [Android Studio](https://developer.android.com/studio) Ladybug or newer (includes JDK + Android SDK).
2. Copy credentials:

```bash
cp local.properties.example local.properties
# Edit MARVI_SUPABASE_URL and MARVI_SUPABASE_ANON_KEY (same as iOS Secrets.xcconfig)
# Set sdk.dir to your Android SDK path
```

3. Open `apps/android` in Android Studio, sync Gradle, run on emulator (API 26+).

```bash
cd apps/android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :app:assembleDebug
```

Without Supabase keys the app runs in **demo mode** with local sample data.

## Features (parity with iOS)

| Area | Android |
|------|---------|
| Multi-step onboarding (welcome → auth → profile/venue → agreement) | ✅ |
| Email + Google Sign-In (PKCE persisted across process death) | ✅ |
| Creator tabs: Explore, Community, Bookings, Profile | ✅ |
| Venue tabs: Studio, Community, Inbox, Account | ✅ |
| Admin tabs: Dashboard, Inbox, Account | ✅ |
| Discover offers + saved filter | ✅ |
| Accept offer, check-in, submit proof | ✅ |
| Community feed, member search, DMs | ✅ |
| Public profiles, follow, IG/TikTok links | ✅ |
| Venue location registration | ✅ |
| Booking status (active / completed / cancelled) | ✅ |
| Deep links (`marvisociety://`, HTTPS auth callback) | ✅ |
| TR / EN strings (~288 keys) | ✅ |
| Dark Marvi theme (Inter / Newsreader) | ✅ |

## Release

```bash
npm run build:android
npm run package:android
# Manual upload: release/google-play/app-release.aab
# Or CLI: npm run publish:android  (needs play-service-account.json)
```

See `docs/google-play/SUBMIT_NOW.md`.

## Structure

```
app/src/main/java/com/marvisociety/app/
├── MainActivity.kt
├── data/              Models, SessionStore, SampleData
├── network/           SupabaseClient, MarviRepository, GoogleOAuth
├── l10n/              MarviL10n TR/EN
├── ui/
│   ├── MarviApp.kt    Role-based tab shell + navigation
│   ├── components/    Shared UI
│   ├── screens/       Onboarding, Discover, Community, Bookings, Profile, Admin, Venue, Chat
│   ├── theme/         Marvi design tokens
│   └── viewmodel/     AppViewModel (mirrors iOS AppState)
```

See iOS reference: `apps/ios/MarviSociety/` and `docs/DEPLOYMENT.md`.
