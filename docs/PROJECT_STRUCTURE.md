# Marvi Society Project Structure

The project is organized to look and behave like a production iOS codebase, not a prototype folder.

## Top-level layout

```text
apps/ios/MarviSociety/
  App/
  Core/
  Data/
  Features/
  Resources/
```

Xcode project: `apps/ios/MarviSociety.xcodeproj`

## App

Application entry and composition layer.

- `MarviSocietyApp.swift`: SwiftUI app entry point.
- `AppState.swift`: shared observable app state while the app is still local-first.
- `ContentView.swift`: root screen that chooses onboarding or authenticated app shell.
- `MainAppShell.swift`: role-based tab routing for creator, venue, and admin workspaces.

## Core

Shared code that is feature-agnostic.

- `Core/DesignSystem`: shared colors, gradients, reusable cards, buttons, metrics, brand mark, and layout wrappers.
- `Core/Models`: domain models and enums used across the app.
- `Core/Persistence`: local persistence abstraction and saved app snapshot.

## Data

Temporary local data providers.

- `SampleData.swift`: Istanbul sample venues, offers, campaigns, bookings, admin tasks, and notifications.

When the backend is connected, this folder should become the local mock implementation for previews and tests.

## Features

Each feature owns its screen and private subviews.

- `Admin`: review queue and operations dashboard.
- `Bookings`: creator invitations, check-in, proof workflow, and timelines.
- `Discover`: marketplace feed, filters, saved offers, and featured campaign.
- `Inbox`: notifications and operational messages.
- `OfferDetail`: campaign brief and acceptance flow.
- `Onboarding`: first-run setup and role selection.
- `Profile`: creator account, role switching, settings, and reset controls.
- `VenueStudio`: partner campaign management and builder.

## Resources

All app assets and preview assets.

- `Assets.xcassets`: app icon, brand mark, accent color, and future media assets.
- `Preview Content`: Xcode preview-only assets.

## Rules for future work

- New reusable UI belongs in `Core/DesignSystem`.
- New app-wide domain types belong in `Core/Models`.
- Feature-only helper views should stay private inside the feature file until reused.
- Backend protocols should go under `Core/Networking` when introduced.
- Production API implementations should go under `Data/Remote`.
- Preview/mock implementations should stay under `Data`.
- Avoid adding new files directly under `MarviSociety/`.
