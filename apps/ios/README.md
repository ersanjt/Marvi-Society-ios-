# Marvi Society — iOS

SwiftUI app for creators, venues, and operators. Supabase is the only production backend.

## Open in Xcode

```bash
cd apps/ios
open MarviSociety.xcodeproj
```

## Source layout

```text
MarviSociety/
├── App/                    # Entry, AppState, ContentView, MainAppShell, Views/
├── Core/
│   ├── DesignSystem/       # Theme/, Components/, shared UI
│   ├── Models/             # Domain types
│   ├── Networking/         # MarviAPI, Supabase client, DTOs
│   ├── Persistence/        # Keychain session, settings
│   ├── Services/           # Location, push
│   └── AppLinks.swift
├── Features/               # Discover, Bookings, Profile, VenueStudio, Admin, …
└── Resources/              # Assets, PrivacyInfo
```

Full map: [docs/PROJECT_STRUCTURE.md](../../docs/PROJECT_STRUCTURE.md)

## Configuration

1. Copy `Config/Secrets.xcconfig.example` → `Config/Secrets.xcconfig`
2. Set `MARVI_SUPABASE_URL` and `MARVI_SUPABASE_ANON_KEY`
3. Build — the **Inject Supabase Secrets** phase writes `Resources/Secrets.plist`

Without valid secrets the app shows **Configuration required** (no offline demo data).

## Build

```bash
xcodebuild -scheme MarviSociety -destination 'generic/platform=iOS' build
```
