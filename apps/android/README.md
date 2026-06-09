# Marvi Society — Android

Kotlin Compose creator app scaffold (Phase 4). Feature parity target: Discover, Nearby, Bookings, Profile, Onboarding.

## Stack

- Kotlin 2.1 + Jetpack Compose + Material 3
- Navigation Compose
- Local demo data (`SampleData.kt`) — Supabase/Retrofit in Phase 4b

## Setup

1. Install [Android Studio](https://developer.android.com/studio) Ladybug or newer.
2. Open `apps/android` as project root.
3. Sync Gradle, run on emulator (API 26+).

```bash
# From apps/android (with Android SDK installed)
./gradlew :app:assembleDebug
```

## Structure

```
app/src/main/java/com/marvisociety/app/
├── MainActivity.kt
├── data/          SampleData, models
├── ui/
│   ├── MarviApp.kt       Tab shell
│   ├── screens/          Discover, Map, Bookings, Profile, Onboarding
│   ├── theme/
│   └── viewmodel/
```

## Supabase (planned)

Copy credentials pattern from iOS `Secrets.xcconfig.example` into `local.properties`:

```properties
MARVI_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
MARVI_SUPABASE_ANON_KEY=your-anon-key
```

## Parity checklist

| Feature | Status |
|---------|--------|
| Onboarding + invite code | ✅ |
| Discover + model filters | ✅ |
| Nearby instant list | ✅ (map SDK pending) |
| Bookings list | ✅ |
| Profile | ✅ |
| Proof upload | ⏳ |
| Supabase sync | ⏳ |

See [docs/ROADMAP.md](../../docs/ROADMAP.md) and [docs/DEPLOYMENT.md](../../docs/DEPLOYMENT.md).
