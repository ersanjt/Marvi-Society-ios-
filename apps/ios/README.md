# Marvi Society — iOS

SwiftUI native app for creators (venue and admin flows included in MVP).

## Open in Xcode

```bash
open MarviSociety.xcodeproj
```

## Source layout

```text
MarviSociety/
├── App/           # Entry, AppState, shell navigation
├── Core/          # Models, DesignSystem, Persistence
├── Data/          # SampleData (→ API in Phase 1)
├── Features/      # Discover, Bookings, Profile, Admin, …
└── Resources/     # Assets, app icon
```

## Phase 1 migration

Replace `UserDefaults` persistence with `SupabaseMarviAPI` implementing the protocol defined in Phase 1. See [docs/BACKEND_SCHEMA.md](../../docs/BACKEND_SCHEMA.md).
