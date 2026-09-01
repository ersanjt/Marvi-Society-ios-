# Marvi Society — Product Definition

**Version:** 1.6 (August 2026)  
**Platform:** iOS (primary), Android, Web (marketing + legal + portal + billing), Supabase (backend)

## What Marvi Society is

Marvi Society is a **private, admin-approved marketplace** that connects **approved creators** with **verified venue partners** for structured collaborations in Istanbul (expandable to other cities).

Creators receive curated experiences (dining, nightlife, wellness, beauty, fitness, retail). Venues receive agreed social content (stories, posts, reviews) through a managed workflow: invitation → booking → check-in → proof submission → review.

**Access model:** Sign up with email / Apple / Google → add Instagram or TikTok → wait for **admin approval**. Referral/invite codes are optional growth tools (admin-issued), not a hard membership gate.

**Collaboration model:** Barter between creators and venues (experience in exchange for agreed social content). Marvi does not take a cut of creator–venue barter.

**Revenue model (B2B, venues pay):** Creators stay free. Venues pay Marvi on the web portal via Stripe:

- **Free** — one live campaign on Explore.
- **Partner** — monthly subscription; unlimited live campaigns for the billed venue.
- **Featured Boost** — one-time placement of a live offer in the Discover featured carousel until `featured_until`.

No creator in-app purchases. StoreKit is not used for venue billing.

## User roles

| Role | Access | Primary screens |
|------|--------|-----------------|
| **Creator** | Default after onboarding | Explore, My Events, Profile |
| **Venue** | If `venue_profiles` linked to account | Venue Studio, Inbox, Account |
| **Admin** | If `profiles.role = admin` | Admin queue, Inbox, Account |

## Core user journeys

### Creator

1. **Onboarding** — Profile (Instagram or TikTok, city), 18+ and legal acceptance, Sign in with Apple / Google / email.
2. **Admin approval** — Membership stays under review until an operator approves.
3. **Explore** — Browse live campaigns, filter by area/date/category, save offers, view brief.
4. **Accept** — Reserve a slot; booking appears in My Events.
5. **Check-in** — Enter 4-digit code at venue.
6. **Proof** — Submit story/post/review links (+ optional screenshot).
7. **Profile** — Edit handles, optional Instagram DM verification, sync account, view strikes and membership status.

### Venue

1. **Campaign builder** — Submit campaign for admin review.
2. **Studio** — View campaigns; review creators (swipe UI — backend matching v2).
3. **Inbox** — Operational notifications.
4. **Billing** — Partner plan and Featured Boost on the web portal (`/portal/billing`, `/pricing`).

### Admin

1. **Review queue** — Approve/reject creator applications, campaigns, proof submissions.
2. **Metrics** — Live offers, bookings, strikes.

## Product rules (enforced in app + backend)

- **18+ only** — Confirmed at onboarding and stored as `profiles.age_confirmed_at`. Stated in Terms. App Store age rating remains **17+** (Apple’s nearest bucket for nightlife / UGC); product eligibility is 18+.
- **Admin approval** — Creator `status` stays `under_review` until approved (hard gate to the main app).
- **Social handles** — Instagram **or** TikTok required before accepting offers.
- **Social DM verify** — Optional trust signal (profile health + admin queue); not required to accept.
- **Invite codes** — Optional referral/growth tool issued by admins; not required for signup or accept.
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
| Cookie policy | `/cookies` | Banner + footer |
| Pricing (venues) | `/pricing` | Marketing, portal billing |
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
- **Age rating:** App Store **17+** (Apple’s nearest nightlife / UGC bucket). Product eligibility and onboarding confirmation are **18+**, stored as `age_confirmed_at`.
- **Encryption:** Standard HTTPS only (`ITSAppUsesNonExemptEncryption = NO`)

## Out of scope

- Creator in-app purchases / StoreKit subscriptions
- Cash settlement between creators and venues
- Android FCM remote push (iOS APNs path exists; FCM is a later parity item)
- Phone/SMS auth

## Related docs

- [App Store listing copy](app-store/LISTING.md)
- [Submission checklist](app-store/CHECKLIST.md)
- [Deployment](DEPLOYMENT.md)
- [Architecture](ARCHITECTURE.md)
