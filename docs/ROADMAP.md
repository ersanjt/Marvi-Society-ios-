# Marvi Society — Product Roadmap

Phased delivery from local MVP to global production platform.

**Repository:** [github.com/ersanjt/Marvi-Society-ios-](https://github.com/ersanjt/Marvi-Society-ios-)

---

## Phase 0 — Foundation (Week 1–2) ✅ complete

**Goal:** Monorepo, architecture docs, CI skeleton, GitHub ready.

| Task | Status |
|------|--------|
| Architecture document | ✅ |
| Roadmap + competitive benchmark | ✅ |
| Monorepo folder structure | ✅ |
| OpenAPI contract skeleton | ✅ |
| GitHub repo + `.gitignore` + CI workflow | ✅ |
| iOS MVP preserved under `apps/ios/` | ✅ |

**Exit criteria:** Team can clone repo, read docs, open iOS project on Mac.

---

## Phase 1 — Backend MVP (Week 3–6) 🔄 in progress

**Goal:** Replace `UserDefaults` with real API; Istanbul-only beta.

| Workstream | Deliverables | Status |
|------------|--------------|--------|
| **Database** | Supabase migrations, RLS, RPC functions | ✅ |
| **Auth** | Apple Sign-In + Supabase token exchange | ✅ |
| **API** | `MarviAPI` + `SupabaseMarviAPI` + `LocalMarviAPI` | ✅ |
| **iOS** | AppState async sync, Profile sync UI | ✅ |
| **Storage** | Proof screenshot upload with signed URLs | ⏳ Phase 1b |
| **Admin** | Basic web review queue (approve/reject) | ⏳ Phase 3 |
| **Deploy** | Create Supabase project + run migrations | ⏳ manual step |

**Exit criteria:** 10 real creators + 5 venues in Istanbul closed beta; data persists across devices.

Setup guide: [PHASE1_SETUP.md](./PHASE1_SETUP.md)

---

## Phase 2 — Creator experience parity (Week 7–10) 🔄 in progress

**Goal:** Match Collabb core creator flows.

| Feature | Priority | Status |
|---------|----------|--------|
| Map view + nearby instant offers | P0 | ✅ |
| 4 collaboration models (invitation, event, gift, instant) | P0 | ✅ |
| Collaboration model filters in Discover | P0 | ✅ |
| Push notifications (proof reminder, instant nearby) | P0 | ✅ local |
| Instagram + TikTok profile linking UI | P0 | ✅ handles + deep links |
| Location service (when-in-use) | P0 | ✅ |
| Instagram/TikTok OAuth verification | P1 | ⏳ |
| Remote push via APNs + backend worker | P1 | ⏳ |
| Membership application workflow + admin approval | P0 | ⏳ partial (schema) |
| Inbox with real-time updates | P1 | ⏳ |
| Member score + strike system | P1 | ⏳ |

**Exit criteria:** Creator can discover on map, accept instant café offer, check in, submit proof, get push reminder.

---

## Phase 3 — Brand portal + marketing web (Week 11–14)

**Goal:** Public web presence like [collabb.me](https://collabb.me/).

| Surface | Pages / features |
|---------|------------------|
| **Marketing** | Home, creators, brands, FAQ, demo request, legal |
| **Brand portal** | Login, campaign builder, booking list, metrics |
| **SEO + i18n** | EN + TR; hreflang for UAE expansion |
| **Demo funnel** | HubSpot or internal lead table |

**Exit criteria:** Venue can sign up on web, create campaign, see creator bookings without iOS app.

---

## Phase 4 — Android + scale (Week 15–20)

**Goal:** Play Store launch; second city (Dubai or Izmir).

| Workstream | Deliverables |
|------------|--------------|
| **Android** | Kotlin Compose app, feature parity with iOS |
| **Shared QA** | Detox / Maestro E2E on critical flows |
| **Analytics** | PostHog funnels, venue ROI dashboard |
| **Referral** | Creator + venue referral codes (Collabb 1.0.1) |
| **Performance** | Feed pagination, image CDN, API caching |

**Exit criteria:** iOS + Android in stores; 100+ approved creators; 20+ live venues.

---

## Phase 5 — Global hardening (Week 21–28)

**Goal:** Production-grade ops for multi-city expansion.

| Area | Work |
|------|------|
| **Compliance** | GDPR, KVKK, Terms, Privacy, creator/venue agreements |
| **Payments** | Venue subscription (Stripe) — optional |
| **Moderation** | Safety reports, account freeze, appeal flow |
| **Localization** | AR, DE, ES (Collabb parity) |
| **SRE** | Staging env, load test, incident runbook |
| **Instagram ops** | Content calendar, UGC repost pipeline |

**Exit criteria:** 3+ cities; 99.9% API uptime; App Store rating target 4.5+.

---

## Milestone timeline (visual)

```text
Week:  1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21 … 28
       ├──P0──┤
               ├────── P1 Backend ──────┤
                                       ├──── P2 Creator parity ────┤
                                                                 ├──── P3 Web ────┤
                                                                                   ├──── P4 Android ────┤
                                                                                                       ├──── P5 Global ────►
```

---

## Team roles (recommended)

| Role | Phase 0–2 | Phase 3+ |
|------|-----------|----------|
| iOS engineer | 1 | 1 |
| Backend engineer | 1 | 1 |
| Full-stack (web) | — | 1 |
| Android engineer | — | 1 |
| Designer | 0.5 | 1 |
| Ops / community | — | 0.5 |

---

## Risk register

| Risk | Mitigation |
|------|------------|
| Instagram API restrictions | Manual verification fallback + admin review |
| Chicken-and-egg (creators vs venues) | Seed venues; invite micro-influencers first |
| App Store rejection (UGC) | Moderation, report flow, age gate |
| Collabb/TSS competition | Focus city depth before geographic spread |

---

## Definition of done (global product)

- [ ] iOS + Android in App Store / Play Store
- [ ] Marketing + brand portal live on custom domain
- [ ] 4 collaboration models production-ready
- [ ] Real auth, push, maps, social linking
- [ ] Admin moderation + legal pages
- [ ] EN + TR + AR localized
- [ ] CI/CD deploys on merge to `main`
- [ ] Analytics and error monitoring active
