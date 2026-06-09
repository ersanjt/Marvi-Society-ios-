# Marvi Society Backend Schema

This is the production backend plan for replacing local `UserDefaults` persistence with a real API.

## Recommended stack

For the fastest first production build:

- Supabase Auth
- Supabase Postgres
- Supabase Storage for proof screenshots and venue media
- Supabase Edge Functions for review automation and notifications
- Apple Push Notification service through a backend notification worker

Firebase is also possible, but Supabase maps better to admin workflows, relational bookings, and review queues.

## Tables

### users

- id
- role: creator, venue, admin
- email
- phone
- apple_user_id
- status
- created_at

### creator_profiles

- id
- user_id
- full_name
- instagram_handle
- city
- audience_count
- niches
- languages
- status: under_review, approved, paused
- score
- proof_rate
- bio
- created_at
- updated_at

### venue_profiles

- id
- owner_user_id
- venue_name
- area
- category
- address
- contact_name
- contact_phone
- status: under_review, approved, paused
- created_at
- updated_at

### offers

- id
- venue_id
- title
- category
- date_start
- date_end
- value_label
- capacity
- remaining_slots
- description
- deliverables
- requirements
- host_note
- status: draft, review, live, completed
- created_at
- updated_at

### bookings

- id
- offer_id
- creator_id
- stage: invited, confirmed, checked_in, proof_due, completed, cancelled
- check_in_code
- guest_name
- proof_deadline
- created_at
- updated_at

### proof_submissions

- id
- booking_id
- creator_id
- links
- screenshot_paths
- status: pending, approved, flagged
- admin_note
- created_at
- reviewed_at

### admin_tasks

- id
- type: creator_application, venue_application, campaign_review, proof_review
- subject_id
- title
- subtitle
- priority
- status: open, approved, rejected
- assigned_admin_id
- created_at
- resolved_at

### strikes

- id
- creator_id
- booking_id
- reason
- severity
- created_by
- created_at

### notifications

- id
- user_id
- title
- body
- type
- read_at
- created_at

## API surface

### Creator app

- `GET /offers`
- `GET /offers/:id`
- `POST /offers/:id/accept`
- `POST /bookings/:id/cancel`
- `POST /bookings/:id/check-in`
- `POST /bookings/:id/proof`
- `GET /me/profile`
- `PATCH /me/profile`

### Venue app

- `GET /venue/campaigns`
- `POST /venue/campaigns`
- `PATCH /venue/campaigns/:id`
- `GET /venue/campaigns/:id/bookings`
- `GET /venue/metrics`

### Admin app

- `GET /admin/tasks`
- `POST /admin/tasks/:id/approve`
- `POST /admin/tasks/:id/reject`
- `GET /admin/creators/:id`
- `GET /admin/venues/:id`
- `POST /admin/creators/:id/strike`

## Access rules

- Creators can read only live offers and their own bookings.
- Creators can submit proof only for their own bookings.
- Venues can read only their own venue campaigns and bookings.
- Venues cannot approve creators directly in the first production version.
- Admins can read and update all review queues.
- Proof assets should use signed URLs and expire.

## App migration plan

1. Keep `AppState` as the UI state owner.
2. Create a `MarviAPI` protocol with the API calls above.
3. Implement `LocalMarviAPI` for previews and offline demos.
4. Implement `SupabaseMarviAPI` for production.
5. Replace direct state mutations with async API calls.
