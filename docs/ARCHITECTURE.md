# Marvi Society — System Architecture

Global private collaboration marketplace connecting approved creators with venues (restaurants, nightlife, wellness, beauty, fitness, retail) in exchange for structured social content.

Benchmark products: [Collabb](https://collabb.me/), [The Secret Society](https://www.the-secret-society.com/).

---

## 1. Product surfaces

| Surface | Users | Stack | Primary jobs |
|---------|-------|-------|--------------|
| **Creator mobile** | Approved influencers | iOS (SwiftUI), Android (Kotlin Compose) | Discover, map, accept offers, check-in, submit proof |
| **Marketing web** | Public, creators (apply CTA) | Next.js 15 | Brand story, FAQ, App Store links, SEO |
| **Brand portal** | Venue partners | Next.js 15 | Campaign builder, bookings, analytics, billing |
| **Admin console** | Operators | Next.js 15 (restricted) | Review queue, strikes, moderation, support |
| **API layer** | All clients | Supabase + Edge Functions | Auth, CRUD, workflows, webhooks |
| **Workers** | System | Edge Functions + cron | Notifications, proof deadlines, analytics sync |

---

## 2. High-level architecture

```text
                         ┌─────────────────────────────────────┐
                         │           CDN (Cloudflare)           │
                         │   marketing · portal · admin · API   │
                         └──────────────────┬──────────────────┘
                                            │
        ┌───────────────┬───────────────────┼───────────────────┬───────────────┐
        ▼               ▼                   ▼                   ▼               ▼
   ┌─────────┐    ┌───────────┐      ┌─────────────┐      ┌───────────┐    ┌──────────┐
   │ iOS App │    │Android App│      │  Web Apps   │      │ Instagram │    │ TikTok   │
   │ SwiftUI │    │  Compose  │      │  Next.js    │      │  OAuth    │    │  OAuth   │
   └────┬────┘    └─────┬─────┘      └──────┬──────┘      └─────┬─────┘    └────┬─────┘
        │               │                   │                   │              │
        └───────────────┴───────────────────┼───────────────────┴──────────────┘
                                            ▼
                              ┌─────────────────────────┐
                              │   API Gateway / Supabase │
                              │   Auth · RLS · Realtime  │
                              └────────────┬────────────┘
                                           │
              ┌────────────────────────────┼────────────────────────────┐
              ▼                            ▼                            ▼
       ┌─────────────┐            ┌─────────────────┐           ┌──────────────┐
       │  PostgreSQL │            │     Storage     │           │ Edge Workers │
       │  (primary)  │            │ proof · media   │           │ notify · ETL │
       └─────────────┘            └─────────────────┘           └──────────────┘
              │                            │                            │
              └────────────────────────────┼────────────────────────────┘
                                           ▼
                              ┌─────────────────────────┐
                              │  External integrations   │
                              │ Maps · APNs · FCM · Email│
                              └─────────────────────────┘
```

---

## 3. Collaboration models (parity with Collabb + TSS)

| Model | Code | Creator flow | Venue use case |
|-------|------|--------------|----------------|
| **Invitation** | `invitation` | Apply → approved → visit at slot | Restaurants, salons, scheduled visits |
| **Event** | `event` | RSVP → attend group experience | Launches, private screenings, club nights |
| **Gift** | `gift` | Receive product → create content | Retail, beauty boxes, product seeding |
| **Instant** | `instant` | Map → accept → visit now | Cafés, grab-and-go, walk-in |

Each offer type shares the same booking lifecycle but differs in scheduling, capacity rules, and proof windows.

---

## 4. Core domain entities

```text
users ──┬── creator_profiles
        ├── venue_profiles
        └── admin_profiles

venue_profiles ── offers ── bookings ── proof_submissions
                      │
                      └── deliverables · requirements

admin_tasks (polymorphic: application, campaign, proof)
strikes · notifications · referral_codes · analytics_events
cities · venues_locations (PostGIS)
```

Full schema: [BACKEND_SCHEMA.md](./BACKEND_SCHEMA.md).

---

## 5. Booking state machine

```text
invited → confirmed → checked_in → proof_due → completed
    │         │            │            │
    └─────────┴────────────┴────────────┴──→ cancelled
```

Transitions enforced server-side:

- `confirmed`: creator accepts or admin matches
- `checked_in`: valid check-in code + optional geo fence
- `proof_due`: auto after visit window; push reminder
- `completed`: proof approved or auto-complete policy
- `cancelled`: creator, venue, or admin; may trigger strike

---

## 6. Authentication and authorization

| Method | Creators | Venues | Admin |
|--------|----------|--------|-------|
| Sign in with Apple | ✅ | — | — |
| Google Sign-In | ✅ | ✅ | — |
| Email + OTP | ✅ | ✅ | ✅ |
| Phone + OTP | ✅ | ✅ | — |
| Email + password | — | ✅ | ✅ |

**Row Level Security (RLS)** on every table:

- Creators: own profile, live offers in city, own bookings
- Venues: own venue, own offers/bookings, own metrics
- Admins: full read; write via role claim `admin`

**Social verification** (Phase 2):

- Instagram Basic Display / Graph API for follower count + handle verification
- TikTok Login Kit for handle binding
- Manual admin override for edge cases

---

## 7. Client architecture patterns

### iOS / Android (shared principles)

```text
Presentation (Views / Composables)
        ↓
ViewModel / Presenter (UI state, navigation)
        ↓
Use Cases (accept offer, submit proof, …)
        ↓
Repository interface
        ↓
RemoteDataSource (API)  +  LocalDataSource (cache)
```

- **Contract-first**: OpenAPI spec in `packages/api-contract/`
- **Offline**: cache discover feed + booking list; queue proof upload
- **Feature modules**: `discover`, `bookings`, `profile`, `onboarding`, `map`

### Web (Next.js)

```text
app/
  (marketing)/     → public pages, i18n
  (portal)/        → venue dashboard (auth required)
  (admin)/         → ops console (admin role)
  api/             → BFF routes, webhooks
```

---

## 8. Infrastructure

| Concern | Choice | Rationale |
|---------|--------|-----------|
| Database | Supabase Postgres + PostGIS | Relational bookings, RLS, geo queries |
| Auth | Supabase Auth | Apple, Google, email, phone |
| Files | Supabase Storage | Proof screenshots, venue media |
| API | PostgREST + Edge Functions | Fast CRUD + custom workflows |
| Maps | Mapbox | Global, style control, offline tiles |
| Push | APNs + FCM via worker | Cross-platform |
| Email | Resend | Transactional + support |
| Analytics | PostHog | Product analytics, funnels |
| Errors | Sentry | iOS, Android, web |
| CI/CD | GitHub Actions | Lint, test, build, deploy |
| Hosting | Vercel (web) + EAS (mobile) | Standard for Next + React Native path |
| DNS/CDN | Cloudflare | `marvisociety.com` |

---

## 9. Security and compliance (global launch)

- GDPR + KVKK (Turkey) privacy policies
- App Store / Play Store data safety forms
- Age gate: 18+ for nightlife categories (configurable per city)
- Signed URLs for proof assets (expire 1h)
- Rate limiting on auth and check-in endpoints
- Audit log for admin actions
- Account deletion flow (email OTP) — required by Apple

---

## 10. Observability

| Signal | Tool |
|--------|------|
| API latency / errors | Supabase dashboard + Sentry |
| Product funnels | PostHog |
| Campaign ROI for venues | Internal analytics tables |
| Uptime | Better Stack or Pingdom |

---

## 11. Repository layout (monorepo)

```text
marvi-society/
├── apps/
│   ├── ios/              # SwiftUI (existing MVP)
│   ├── android/          # Kotlin Compose
│   └── web/              # Next.js (marketing + portal + admin)
├── packages/
│   └── api-contract/     # OpenAPI 3.1 — source of truth
├── infra/
│   └── supabase/         # migrations, seed, RLS policies
├── docs/                 # architecture, roadmap, design
└── .github/workflows/    # CI/CD
```

---

## 12. API versioning

- Base path: `/v1/`
- Breaking changes → `/v2/` with 6-month deprecation
- Mobile apps send `X-App-Version` + `X-Platform` headers

---

## 13. Internationalization

Launch languages (Phase 3+):

1. English (default)
2. Turkish
3. Arabic (RTL)
4. Persian (RTL) — optional wave 2

All user-facing strings externalized; dates/numbers locale-aware.

---

## 14. Non-goals (v1)

- In-app payments to creators (barter-only, like TSS)
- Public unauthenticated offer browsing
- Creator-to-creator messaging
- AI content generation
