# Marvi Society — Web

Next.js 15 marketing site + brand portal (Phase 3).

## Pages

| Route | Description |
|-------|-------------|
| `/` | Homepage |
| `/creators` | Creator landing |
| `/brands` | Brand / venue landing |
| `/faq` | FAQ accordion |
| `/demo` | Demo request form |
| `/contact` | Support |
| `/privacy` | Privacy policy |
| `/terms` | Terms of use |
| `/delete-account` | Account deletion |
| `/portal/login` | Brand portal login |
| `/portal/dashboard` | Venue metrics (preview) |
| `/portal/campaigns/new` | Campaign builder (preview) |

## Setup

```bash
cd apps/web
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Production deploy

Recommended: [Vercel](https://vercel.com) with root directory `apps/web`.

Environment variables (Phase 1b):

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

## Design tokens

Colors match `docs/DESIGN_SYSTEM.md` via Tailwind (`emerald`, `ink`, `surface`, etc.).
