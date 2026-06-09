# Contributing to Marvi Society

## Repository structure

```text
apps/ios/       → SwiftUI creator app (active)
apps/android/   → Kotlin Compose (Phase 4)
apps/web/       → Next.js marketing + portal (Phase 3)
packages/       → Shared API contract
infra/          → Supabase migrations and workers
docs/           → Architecture, roadmap, design
```

## Branch strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready releases |
| `develop` | Integration branch |
| `feature/*` | New features |
| `fix/*` | Bug fixes |

## Commit messages

Use conventional commits:

```text
feat(ios): add map discover screen
fix(api): booking check-in validation
docs: update architecture diagram
chore(ci): add Android lint job
```

## Pull requests

1. Branch from `develop`
2. Keep PRs focused (< 400 lines when possible)
3. Update docs if architecture or API changes
4. OpenAPI changes require review from backend owner

## Code standards

- **iOS:** SwiftUI, feature folders, design system in `Core/DesignSystem`
- **API:** Update `packages/api-contract/openapi.yaml` before implementation
- **No secrets** in git — use environment variables

## Local iOS setup

See [README.md](./README.md#ios-development).
