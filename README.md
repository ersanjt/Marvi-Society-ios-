# Marvi Society

Global private collaboration marketplace for creators and venues — benchmarked against [Collabb](https://collabb.me/) and [The Secret Society](https://www.the-secret-society.com/).

**Creators** discover curated venue experiences. **Venues** receive structured social content. **Admins** curate quality and trust.

[![CI](https://github.com/ersanjt/Marvi-Society-ios-/actions/workflows/ci.yml/badge.svg)](https://github.com/ersanjt/Marvi-Society-ios-/actions/workflows/ci.yml)

---

## Monorepo structure

```text
marvi-society/
├── apps/
│   ├── ios/              # SwiftUI — active MVP
│   ├── android/          # Kotlin Compose — Phase 4
│   └── web/              # Next.js — Phase 3
├── packages/
│   └── api-contract/     # OpenAPI 3.1
├── infra/
│   └── supabase/         # Database & Edge Functions — Phase 1
└── docs/                 # Architecture, roadmap, design
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, stack, security |
| [ROADMAP.md](docs/ROADMAP.md) | Phased delivery plan (28 weeks) |
| [COMPETITIVE_BENCHMARK.md](docs/COMPETITIVE_BENCHMARK.md) | Collabb vs TSS analysis |
| [INSTAGRAM_STRATEGY.md](docs/INSTAGRAM_STRATEGY.md) | Social growth playbook |
| [BACKEND_SCHEMA.md](docs/BACKEND_SCHEMA.md) | Database schema |
| [MVP_SCOPE.md](docs/MVP_SCOPE.md) | Current MVP scope |
| [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | UI tokens and components |
| [PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) | iOS code layout |

---

## Current status — Phase 0

| Platform | Status |
|----------|--------|
| **iOS** | Local MVP with UserDefaults (discover, bookings, proof, admin) |
| **Android** | Planned Phase 4 |
| **Web** | Planned Phase 3 |
| **Backend** | Planned Phase 1 (Supabase) |

---

## iOS development

Requires **Mac + Xcode**.

```bash
git clone https://github.com/ersanjt/Marvi-Society-ios-.git
cd Marvi-Society-ios-/apps/ios
open MarviSociety.xcodeproj
```

1. Select simulator (e.g. iPhone 16 Pro)
2. Run `⌘R`

Bundle ID: `com.marvisociety.app` (change for your Apple Developer team if needed).

---

## Product roadmap (summary)

| Phase | Weeks | Goal |
|-------|-------|------|
| **0** Foundation | 1–2 | Monorepo, docs, GitHub CI |
| **1** Backend | 3–6 | Supabase, real API, Istanbul beta |
| **2** Creator parity | 7–10 | Map, push, IG/TikTok, 4 models |
| **3** Web | 11–14 | Marketing site + brand portal |
| **4** Android | 15–20 | Play Store, scale |
| **5** Global | 21–28 | Compliance, i18n, multi-city |

Full details: [docs/ROADMAP.md](docs/ROADMAP.md)

---

## API contract

OpenAPI spec: [packages/api-contract/openapi.yaml](packages/api-contract/openapi.yaml)

All clients (iOS, Android, web) implement against this contract.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

Proprietary — All rights reserved © Marvi Society.
