## [1.5.4] - 2026-09-01

Venue billing + Featured Boost, inbox/push for follows/DMs/comments, 18+ onboarding copy, and paid Featured date parsing.

- iOS 1.5.4 (103) · Android 1.9.13 (59)
- Migration head: `20260831020001_venue_billing_safety_and_trust`
- Web: `/pricing`, `/cookies`, portal billing, Stripe Checkout (code on `main`; live WHM still needs redeploy)

## [1.5.3] - 2026-08-13

Submit 1.5.3 (79) to App Review for public App Store release

- Migration head: `20260813010001_inbox_role_polish`

# Changelog

All notable changes are documented here. Use `npm run release -- <version> "summary"` for new releases.

## [0.2.0] - 2026-06-11

Secret Society UI parity, Supabase-only iOS, admin workspace fix, venue reviews, account context RPC, and professional ops toolchain.

- Migration head: `20260613000001_venue_reviews_strikes`
- iOS: multi-step onboarding, design system, admin console tab switching
- Web: marketing route group, legal pages, admin auth
- Ops: `scripts/marvi`, full-sync, rollback playbook, release manifest
