# Marvi Society — Product Definition

**Version:** 1.0 (June 2026)  
**Platform:** iOS (primary), Web (marketing + legal + portal), Supabase (backend)

## What Marvi Society is

Marvi Society is a **private, invitation-only marketplace** that connects **approved creators** with **verified venue partners** for structured collaborations in Istanbul (expandable to other cities).

Creators receive curated experiences (dining, nightlife, wellness, beauty, fitness, retail). Venues receive agreed social content (stories, posts, reviews) through a managed workflow: invitation → booking → check-in → proof submission → review.

**Business model:** Barter (experience in exchange for content). No direct cash payments between creators and venues in v1.

## User roles

| Role | Access | Primary screens |
|------|--------|-----------------|
| **Creator** | Default after onboarding | Explore, My Events, Profile |
| **Venue** | If `venue_profiles` linked to account | Venue Studio, Inbox, Account |
| **Admin** | If `profiles.role = admin` | Admin queue, Inbox, Account |

## Core user journeys

### Creator

1. **Onboarding** — Invite code, profile (Instagram, city), 18+ and legal acceptance, Sign in with Apple or email.
2. **Explore** — Browse live campaigns, filter by area/date/category, save offers, view brief.
3. **Accept** — Reserve a slot; booking appears in My Events.
4. **Check-in** — Enter 4-digit code at venue.
5. **Proof** — Submit story/post/review links (+ optional screenshot).
6. **Profile** — Edit handles, sync account, view strikes and membership status.

### Venue

1. **Campaign builder** — Submit campaign for admin review.
2. **Studio** — View campaigns; review creators (swipe UI — backend matching v2).
3. **Inbox** — Operational notifications.

### Admin

1. **Review queue** — Approve/reject creator applications, campaigns, proof submissions.
2. **Metrics** — Live offers, bookings, strikes.

## Product rules (enforced in app + backend)

- **18+ only** — Confirmed at onboarding; stated in Terms.
- **Invite-only** — Valid `referral_codes` required at sign-up.
- **Admin approval** — Creator `status` may be `under_review` until approved.
- **Capacity** — `accept_offer` RPC decrements `remaining_slots`; no overbooking.
- **Check-in** — Venue-issued code required; invalid code rejected.
- **Proof deadline** — Submissions tracked; strikes for repeated misses.
- **Strikes** — Affect matching priority; pause/terminate for abuse.

## Legal & compliance surfaces

| Document | URL | In-app |
|----------|-----|--------|
| Privacy Policy | `/privacy` | Profile, Onboarding links |
| Terms of Service | `/terms` | Profile, Onboarding acceptance |
| Community Guidelines | `/community-guidelines` | Profile |
| Delete account | `/delete-account` | Profile (Apple requirement) |
| Support | `/contact` | Profile |

Locales: English + Turkish (web follows site locale cookie; iOS legal links open English web pages).

## Data processed (App Store Privacy Labels)

- Email, name, user ID (account)
- Photos/videos (optional proof screenshots)
- Precise location (when-in-use, map/nearby)
- Product interaction (bookings, proof links)

**Not collected:** Advertising tracking, contacts, microphone, background location.

## Technical architecture

```
iOS App (SwiftUI)
    ↓ HTTPS + JWT
Supabase (Auth, Postgres, RLS, RPC, Storage)
    ↑
Web (Next.js on Vercel) — marketing, legal, delete-account, portal
```

## App Store identity

- **Bundle ID:** `com.marvisociety.app`
- **Name:** Marvi Society
- **Category:** Lifestyle
- **Age rating:** 17+ recommended (nightlife, user-generated proof content)
- **Encryption:** Standard HTTPS only (`ITSAppUsesNonExemptEncryption = NO`)

## Out of scope for v1.0

- In-app payments / subscriptions
- Remote push (APNs) — local reminders only
- Creator swipe matching backend (UI present for venues)
- Phone/SMS auth

## Related docs

- [App Store listing copy](app-store/LISTING.md)
- [Submission checklist](app-store/CHECKLIST.md)
- [Deployment](DEPLOYMENT.md)
- [Architecture](ARCHITECTURE.md)
