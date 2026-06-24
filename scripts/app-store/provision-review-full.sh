#!/bin/bash
# Provision Apple Review account entirely via Supabase Admin + REST (no SQL Editor).
# Requires: SUPABASE_SERVICE_ROLE_KEY in env or apps/web/.env.local
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REVIEW_EMAIL="${REVIEW_EMAIL:-review@marvisociety.com}"
REVIEW_PASSWORD="${REVIEW_PASSWORD:-MarviReview2026!}"
SB_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}"

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" && -f "$REPO_ROOT/apps/web/.env.local" ]]; then
  # shellcheck disable=SC2046
  export $(grep -E '^SUPABASE_SERVICE_ROLE_KEY=' "$REPO_ROOT/apps/web/.env.local" | xargs) || true
fi

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "✗ SUPABASE_SERVICE_ROLE_KEY missing."
  echo "  Paste service_role key into apps/web/.env.local then re-run."
  echo "  Supabase → Project Settings → API → service_role (secret)"
  exit 1
fi

KEY="$SUPABASE_SERVICE_ROLE_KEY"
HDR=(-H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json")

echo "→ Auth user $REVIEW_EMAIL"
bash "$REPO_ROOT/scripts/app-store/provision-review-account.sh"

USER_ID=$(curl -sS "$SB_URL/auth/v1/admin/users?email=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REVIEW_EMAIL'))")" \
  "${HDR[@]}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['users'][0]['id'] if d.get('users') else '')")

[[ -n "$USER_ID" ]] || { echo "✗ Could not resolve user id"; exit 1; }
echo "✓ User id $USER_ID"

echo "→ profiles (admin, approved, MARVI-IST)"
curl -sS -X POST "$SB_URL/rest/v1/profiles" \
  "${HDR[@]}" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "{\"id\":\"$USER_ID\",\"email\":\"$REVIEW_EMAIL\",\"role\":\"admin\",\"status\":\"approved\",\"preferred_locale\":\"en\",\"referral_code\":\"MARVI-IST\"}" >/dev/null

echo "→ creator_profiles"
curl -sS -X POST "$SB_URL/rest/v1/creator_profiles" \
  "${HDR[@]}" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "{
    \"user_id\":\"$USER_ID\",
    \"full_name\":\"Apple Review\",
    \"instagram_handle\":\"@marvisociety_review\",
    \"city\":\"istanbul\",
    \"status\":\"approved\",
    \"score\":90,
    \"audience_count\":12000,
    \"proof_rate\":98,
    \"niches\":[\"Dining\",\"Lifestyle\",\"Nightlife\"],
    \"languages\":[\"English\",\"Turkish\"]
  }" >/dev/null

echo "→ venue_profiles"
EXISTING_VENUE=$(curl -sS "$SB_URL/rest/v1/venue_profiles?owner_user_id=eq.$USER_ID&select=id" \
  "${HDR[@]}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" 2>/dev/null || echo "")

if [[ -z "$EXISTING_VENUE" ]]; then
  curl -sS -X POST "$SB_URL/rest/v1/venue_profiles" \
    "${HDR[@]}" \
    -d "{
      \"owner_user_id\":\"$USER_ID\",
      \"venue_name\":\"Marvi Review Venue\",
      \"area\":\"Karaköy\",
      \"category\":\"dining\",
      \"address\":\"Karaköy, Istanbul\",
      \"contact_name\":\"Apple Review\",
      \"status\":\"approved\",
      \"lat\":41.0256,
      \"lng\":28.9744
    }" >/dev/null
else
  curl -sS -X PATCH "$SB_URL/rest/v1/venue_profiles?id=eq.$EXISTING_VENUE" \
    "${HDR[@]}" \
    -d '{"status":"approved"}' >/dev/null
fi

echo "→ verify login"
login=$(curl -sS -X POST "$SB_URL/auth/v1/token?grant_type=password" \
  -H "apikey: sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$REVIEW_EMAIL\",\"password\":\"$REVIEW_PASSWORD\"}")
TOKEN=$(echo "$login" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
[[ -n "$TOKEN" ]] || { echo "✗ Login failed"; exit 1; }

CREATOR_ID=$(curl -sS "$SB_URL/rest/v1/creator_profiles?user_id=eq.$USER_ID&select=id" \
  "${HDR[@]}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" 2>/dev/null || echo "")
OFFER_ID=$(curl -sS "$SB_URL/rest/v1/offers?status=eq.live&select=id&order=created_at.desc&limit=1" \
  "${HDR[@]}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" 2>/dev/null || echo "")

if [[ -n "$CREATOR_ID" && -n "$OFFER_ID" ]]; then
  echo "→ demo booking (My Events)"
  curl -sS -X POST "$SB_URL/rest/v1/bookings" \
    "${HDR[@]}" \
    -H "Prefer: resolution=merge-duplicates" \
    -d "{
      \"offer_id\":\"$OFFER_ID\",
      \"creator_id\":\"$CREATOR_ID\",
      \"stage\":\"confirmed\",
      \"check_in_code\":\"4242\",
      \"proof_deadline_label\":\"Tomorrow, 20:00\",
      \"guest_name\":\"Apple Review\",
      \"proof_status\":\"not_started\"
    }" >/dev/null || true
fi

ctx=$(curl -sS -X POST "$SB_URL/rest/v1/rpc/fetch_account_context" \
  -H "apikey: sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d "{}")
echo "✓ Account context: $ctx"

offers=$(curl -sS "$SB_URL/rest/v1/offers_public?select=id&limit=3" \
  -H "apikey: sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y" \
  -H "Authorization: Bearer $TOKEN")
count=$(echo "$offers" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "✓ Live offers visible: $count+"
echo ""
echo "Review account ready for App Store Connect."
