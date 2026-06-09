# Marvi Society MVP Scope

## Product direction

Marvi Society is an Istanbul-first private collaboration marketplace. It gives approved creators access to curated venue experiences, while restaurants, clinics, studios, clubs, and retail partners receive structured social content and proof of delivery.

## Roles

- Creator member: applies, gets approved, discovers offers, accepts invitations, attends, submits proof.
- Venue partner: submits venue details, creates promotions, reviews attendance and proof.
- Admin operator: approves members and venues, curates matching, monitors strikes, handles support.

## MVP screens

- Onboarding and role selection
- Discover feed
- Offer detail
- Bookings and proof checklist
- Creator profile
- Inbox notifications
- Venue studio
- Campaign builder
- Admin control dashboard
- Review queue

## Backend entities

- users
- creator_profiles
- venue_profiles
- offers
- bookings
- deliverables
- proof_submissions
- reviews
- strikes
- notifications

## First production integrations

- Authentication: Apple, phone, email
- Instagram profile verification
- Push notifications
- Image/link proof upload
- Admin dashboard
- Venue approval workflow

## Implemented in local prototype

- Creator can accept and cancel offers.
- Accepting an offer creates a booking.
- Bookings include check-in code, stage, checklist, proof deadline, and proof status.
- Creator can submit proof links.
- Proof submission creates an admin review task.
- Venue can create a campaign draft.
- Campaign drafts create admin review tasks.
- Admin can approve or reject review tasks.
- User can switch between creator, venue, and admin workspaces from Profile.
- Local state is persisted with `UserDefaults`.
- Profile includes settings and demo reset controls.
- Professional design system is documented in `docs/DESIGN_SYSTEM.md`.
- App icon and brand mark assets are included in the asset catalog.

## Backend preparation

The initial production schema and API plan lives in `docs/BACKEND_SCHEMA.md`.

## Open decisions

- Primary app language: English, Turkish, Persian, or multilingual
- Approval criteria for creators
- Whether venues can directly invite creators or only admins can match
- Whether members can bring guests
- Payment model for venues
- Legal terms, privacy policy, and creator agreement for Turkey
