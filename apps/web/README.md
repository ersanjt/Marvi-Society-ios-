# Marvi Society — Web

Next.js 15 app: marketing site, brand portal, and admin console.

## Quick start

```bash
# From monorepo root
npm install
npm run web:dev
```

Copy `apps/web/.env.example` → `apps/web/.env.local` and fill Supabase keys for full auth.

## Routes

| Route | Description |
|-------|-------------|
| `/` | Homepage |
| `/creators`, `/brands` | Landing pages |
| `/faq`, `/demo`, `/contact` | Support & lead capture |
| `/privacy`, `/terms`, `/community-guidelines`, `/delete-account` | Legal |
| `/portal/login` | Brand portal sign-in |
| `/portal/dashboard` | Venue metrics |
| `/portal/campaigns/new` | Campaign builder |
| `/portal/creators`, `/portal/reviews` | Creator tools |
| `/admin` | Admin task queue |
| `/admin/users` | User directory + provisioning |
| `/admin/broadcast` | Geo broadcast |
| `/api/health` | Deployment health check |

## Structure

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full folder layout.

```
src/app/(marketing)/   — public site
src/app/(portal)/portal/ — brand portal
src/app/(admin)/admin/   — operations console
src/config/              — env + site constants
src/components/          — UI by domain
```

## Production deploy

Deploy via [Vercel](https://vercel.com) with root directory `apps/web`.

Full guide: [`docs/WEB_SETUP.md`](../docs/WEB_SETUP.md)

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_SITE_URL=https://marvisociety.com
SUPABASE_SERVICE_ROLE_KEY=
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Dev server (:3000) |
| `npm run build` | Production build |
| `npm run start` | Serve production build |
| `npm run lint` | ESLint |

Design tokens match `docs/DESIGN_SYSTEM.md` (Tailwind: `emerald`, `ink`, `surface`, …).
