# Marvi Society — Project Structure

Production monorepo for iOS, web, Android scaffold, and Supabase backend.

## Repository layout

```text
marvi-society/
├── apps/
│   ├── ios/                 # SwiftUI iOS app (primary product)
│   ├── web/                 # Next.js — marketing, legal, portal, admin API
│   └── android/             # Kotlin Compose scaffold (future)
├── packages/
│   ├── shared/              # Cross-platform URLs + domain constants
│   └── api-contract/        # OpenAPI spec
├── infra/
│   └── supabase/            # Migrations, seed, SQL fixes, config
├── docs/                    # Product, architecture, App Store
├── scripts/                 # Health check, deploy helpers
└── package.json             # npm workspaces root
```

## iOS (`apps/ios/`)

```text
MarviSociety/
├── App/
│   ├── MarviSocietyApp.swift      # @main entry
│   ├── AppState.swift             # Global state + server sync
│   ├── ContentView.swift          # Auth / onboarding router
│   ├── MainAppShell.swift         # Tab bar (Explore, Events, Profile, …)
│   └── Views/                     # App-level shells (config, reauth)
├── Core/
│   ├── DesignSystem/
│   │   ├── DesignSystem.swift     # Cards, headers, shared UI primitives
│   │   ├── Theme/                 # Colors, gradients, Color+Hex
│   │   └── Components/          # OfferImagery, WorkspaceRolePicker
│   ├── Models/                    # Domain types (Offer, Booking, …)
│   ├── Networking/
│   │   ├── MarviAPI.swift         # Protocol
│   │   ├── APIConfig.swift        # Secrets + factory
│   │   ├── Supabase/              # SupabaseMarviAPI, client
│   │   └── DTOs/                  # API row mappers
│   ├── Persistence/               # UserDefaults + Keychain session
│   ├── Services/                  # Location, push notifications
│   └── AppLinks.swift             # Legal URLs (mirror packages/shared)
├── Features/                      # One folder per screen / flow
│   ├── Discover/                  # Explore list + map
│   ├── Bookings/                  # My Events
│   ├── Profile/
│   ├── Onboarding/
│   ├── OfferDetail/
│   ├── VenueStudio/               # Venue workspace + swipe + review queue
│   ├── Admin/
│   └── Inbox/
└── Resources/                     # Assets, PrivacyInfo, Preview Content

Config/                            # Secrets.xcconfig (gitignored)
```

**Conventions**

| What | Where |
|------|--------|
| Reusable UI | `Core/DesignSystem/` |
| Theme tokens | `Core/DesignSystem/Theme/` |
| Feature screens | `Features/<FeatureName>/` |
| API / DTOs | `Core/Networking/` |
| Domain models | `Core/Models/` |

**Config:** copy `Config/Secrets.xcconfig.example` → `Config/Secrets.xcconfig` with Supabase URL + anon key.

## Web (`apps/web/src/`)

```text
app/
├── layout.tsx                     # Root HTML shell (no marketing chrome)
├── globals.css
├── (marketing)/                   # Public site with Header + Footer
│   ├── layout.tsx
│   ├── page.tsx                   # /
│   ├── creators/, brands/, faq/, demo/
│   ├── privacy/, terms/, community-guidelines/
│   ├── delete-account/, contact/
├── portal/                        # Venue partner login + campaigns
├── admin/                         # Ops console (admin role required)
└── api/                           # Route handlers (delete-account, admin RPC)

components/
├── marketing/                     # Header, Footer, LegalDocument, …
└── portal/                        # LoginForm, CampaignForm, …

lib/
├── constants.ts                   # SITE metadata (uses @marvi/shared)
├── legal/content.ts               # EN/TR legal copy
├── supabase/                      # Browser, server, admin clients
└── i18n/
```

**Route groups:** `(marketing)` wraps public pages; `/portal` and `/admin` use minimal chrome from root layout.

## Shared package (`packages/shared/`)

Single source of truth for:

- `MARVI_URLS` — legal + support links (sync with iOS `AppLinks.swift`)
- `USER_ROLES`, `MEMBERSHIP_STATUSES`, `REFERRAL_CODES`, etc.

Import in web: `import { MARVI_URLS } from "@marvi/shared"`

## Backend (`infra/supabase/`)

```text
migrations/           # Ordered SQL (run in filename order)
scripts/
  combine-migrations.sh   # → ALL_MIGRATIONS_COMBINED.sql
  legacy/             # Archived one-off scripts
fix-user-account.sql  # Production account bootstrap (SQL Editor)
seed-after-deploy.sql
config.toml
```

**Migrations (in order):**

1. `20260609000001_initial_schema.sql`
2. `20260609000002_rls_policies.sql`
3. `20260609000003_rpc_functions.sql`
4. `20260609000004_demo_leads_storage.sql`
5. `20260609000005_seed_function.sql`
6. `20260610000001_production_hardening.sql`
7. `20260610000002_delete_own_account.sql`
8. `20260611000001_secret_society_parity.sql`

Regenerate combined file: `npm run db:combine`

## Contributor rules

1. **No demo data in production paths** — Supabase is the only backend for iOS.
2. **Legal URL changes** → `packages/shared/src/urls.ts` + iOS `AppLinks.swift`.
3. **Legal copy** → `apps/web/src/lib/legal/content.ts`.
4. **Schema changes** → new timestamped file in `infra/supabase/migrations/`, then `npm run db:combine`.
5. **App Store copy** → `docs/app-store/LISTING.md`.
6. **New iOS screen** → `Features/<Name>/` + register in `MarviSociety.xcodeproj`.
