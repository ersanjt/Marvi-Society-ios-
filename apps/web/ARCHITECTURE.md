# Marvi Society — Web Architecture

Next.js 15 App Router application for marketing, brand portal, and admin operations.

## Directory layout

```
apps/web/
├── public/                    # Static assets (favicon, images)
├── src/
│   ├── app/
│   │   ├── (marketing)/       # Public site — Header/Footer layout
│   │   ├── (portal)/portal/   # Brand portal (auth-protected)
│   │   ├── (admin)/admin/     # Operations console (admin role)
│   │   ├── api/               # Route handlers (REST)
│   │   ├── layout.tsx         # Root HTML shell + metadata
│   │   ├── globals.css
│   │   ├── robots.ts
│   │   └── sitemap.ts
│   ├── components/
│   │   ├── marketing/         # Landing pages, legal, forms
│   │   ├── portal/            # Venue dashboard UI
│   │   └── admin/             # Admin console UI
│   ├── config/
│   │   ├── env.ts             # Environment helpers (Supabase, preview mode)
│   │   └── site.ts            # Site metadata, nav constants
│   ├── lib/
│   │   ├── admin/             # Admin RPC wrapper
│   │   ├── auth/              # Session + role checks
│   │   ├── i18n/              # Locale + dictionaries
│   │   ├── legal/             # Policy content
│   │   └── supabase/          # Browser, server, service clients
│   └── middleware.ts          # Portal/admin auth gates
├── .env.example
├── next.config.ts
├── vercel.json
└── package.json
```

Route groups `(marketing)`, `(portal)`, and `(admin)` organize layouts without changing URLs.

## Routes

| URL | Area | Auth |
|-----|------|------|
| `/` | Marketing home | Public |
| `/creators`, `/brands`, `/faq`, `/demo`, `/contact` | Marketing | Public |
| `/privacy`, `/terms`, `/community-guidelines`, `/delete-account` | Legal | Public |
| `/portal/login` | Brand login | Public |
| `/portal/dashboard`, `/portal/campaigns/new`, … | Brand portal | Session |
| `/admin`, `/admin/users`, `/admin/broadcast` | Admin console | Admin role |
| `/api/health` | Health check | Public |
| `/api/admin/*` | Admin API | Admin role |
| `/api/portal/*` | Portal API | Session |

## Environment

See `.env.example`. Production requires all Supabase variables; preview mode (local dev without Supabase) is disabled in production.

## Related packages

- `@marvi/shared` — canonical URLs and domain constants (`packages/shared`)
- Supabase migrations — `infra/supabase/migrations/`
