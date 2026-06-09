# Marvi Society — Web

**Status:** Phase 3 (not started)

## Planned stack

- Next.js 15 (App Router)
- TypeScript
- Tailwind CSS + shared design tokens
- Supabase Auth (SSR)
- i18n: next-intl (EN, TR, AR)

## Surfaces

| Route group | Audience |
|-------------|----------|
| `(marketing)` | Public — home, creators, brands, FAQ, demo |
| `(portal)` | Venue partners — campaigns, bookings, metrics |
| `(admin)` | Operators — review queue, moderation |

## Setup (when Phase 3 starts)

```bash
cd apps/web
pnpm install
pnpm dev
```

See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) and [docs/ROADMAP.md](../../docs/ROADMAP.md).
