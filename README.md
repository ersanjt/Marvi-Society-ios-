# Marvi Society

Global private collaboration marketplace for creators and venues — benchmarked against [Collabb](https://collabb.me/) and [The Secret Society](https://www.the-secret-society.com/).

**Creators** discover curated venue experiences. **Venues** receive structured social content. **Admins** curate quality and trust.

[![CI](https://github.com/ersanjt/Marvi-Society-ios-/actions/workflows/ci.yml/badge.svg)](https://github.com/ersanjt/Marvi-Society-ios-/actions/workflows/ci.yml)

---

## Monorepo structure

```text
marvi-society/
├── apps/
│   ├── ios/              # SwiftUI creator app (map, proof, admin)
│   ├── android/          # Kotlin Compose scaffold
│   └── web/              # Next.js marketing + portal + admin
├── packages/
│   └── api-contract/     # OpenAPI 3.1
├── infra/
│   └── supabase/         # Migrations, RLS, RPC, seed
└── docs/                 # Architecture, roadmap, deployment
```

---

## Current status

| Platform | Status |
|----------|--------|
| **iOS** | MVP + Supabase sync, map, 4 models, proof upload, strikes |
| **Web** | Marketing site, portal auth, admin queue, EN/TR, API routes |
| **Android** | Compose scaffold (Discover, Nearby, Bookings, Profile) |
| **Backend** | Supabase schema ready — deploy project manually |

Deploy guide: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) · **راهنمای فارسی:** [docs/DEPLOY_WALKTHROUGH_FA.md](docs/DEPLOY_WALKTHROUGH_FA.md)

---

## Quick start

### Web

```bash
cd apps/web
npm install
npm run dev
```

Open http://localhost:3000 — portal at `/portal/login`, admin at `/admin`.

Copy `apps/web/.env.example` → `.env.local` for Supabase.

### iOS (Mac + Xcode)

```bash
cd apps/ios
open MarviSociety.xcodeproj
```

Optional: `cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig` for Supabase mode.

### Android (Android Studio)

Open `apps/android` → Sync Gradle → Run on emulator.

### Supabase

```bash
cd infra/supabase
npx supabase link --project-ref YOUR_REF
npx supabase db push
```

See [docs/PHASE1_SETUP.md](docs/PHASE1_SETUP.md).

---

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, stack, security |
| [ROADMAP.md](docs/ROADMAP.md) | Phased delivery plan |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Vercel, Supabase, TestFlight, Play |
| [PHASE1_SETUP.md](docs/PHASE1_SETUP.md) | Backend + iOS Supabase setup |
| [BACKEND_SCHEMA.md](docs/BACKEND_SCHEMA.md) | Database schema |
| [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | UI tokens |

---

## API contract

OpenAPI: [packages/api-contract/openapi.yaml](packages/api-contract/openapi.yaml)

---

## License

Proprietary — All rights reserved © Marvi Society.
