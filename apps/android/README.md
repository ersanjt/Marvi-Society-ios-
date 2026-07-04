# Marvi Society — Android

Kotlin + Jetpack Compose app aligned with the iOS Marvi Society client (v1.3 / build 30).

## Stack

- Kotlin 2.1 + Jetpack Compose + Material 3
- Ktor HTTP client (mirrors iOS lightweight Supabase REST client)
- DataStore session persistence
- Coil (images, ready for avatars/showcase)
- Navigation Compose with role-based tabs (Creator / Venue / Admin)

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
./gradlew :app:assembleDebug
```

Without Supabase keys the app runs in **demo mode** with local sample data (onboarding skip available).

## Features (parity with iOS)

| Area | Android |
|------|---------|
| Email auth + onboarding gates | ✅ |
| Invite code via RPC (no hardcoded codes) | ✅ |
| Creator tabs: Explore, Community, Bookings, Profile | ✅ |
| Venue tabs: Studio, Community, Inbox, Account | ✅ |
| Admin tabs: Dashboard, Inbox, Account | ✅ |
| Discover offers + saved filter | ✅ |
| Accept offer, check-in, submit proof | ✅ |
| Community feed, member search, DMs | ✅ |
| Public profiles, follow, IG/TikTok links | ✅ |
| Admin tasks + invite code list | ✅ |
| TR / EN strings | ✅ (core set) |
| Dark Marvi theme | ✅ |

Planned polish: map view, photo upload, push notifications, full admin user provisioning UI.

## Structure

```
app/src/main/java/com/marvisociety/app/
├── MainActivity.kt
├── data/              Models, SessionStore, SampleData
├── network/           SupabaseClient, MarviRepository
├── l10n/              MarviL10n TR/EN
├── ui/
│   ├── MarviApp.kt    Role-based tab shell + navigation
│   ├── components/    MarviCard, MarviScreen, banners
│   ├── screens/       Onboarding, Discover, Community, Bookings, Profile, Admin, Venue, Chat
│   ├── theme/         MarviColor dark tokens
│   └── viewmodel/     AppViewModel (mirrors iOS AppState)
```

See iOS reference: `apps/ios/MarviSociety/` and `docs/DEPLOYMENT.md`.
