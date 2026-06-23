#!/bin/bash
# Create review@marvisociety.com in Supabase Auth (service role required).
# Run on Mac or WHM after exporting SUPABASE_SERVICE_ROLE_KEY.
set -euo pipefail

REVIEW_EMAIL="${REVIEW_EMAIL:-review@marvisociety.com}"
REVIEW_PASSWORD="${REVIEW_PASSWORD:-MarviReview2026!}"
SB_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}"
SB_SERVICE="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [[ -z "$SB_SERVICE" ]]; then
  echo "✗ Set SUPABASE_SERVICE_ROLE_KEY" >&2
  exit 1
fi

echo "→ Provisioning $REVIEW_EMAIL …"

resp=$(curl -sS -w "\n%{http_code}" -X POST "$SB_URL/auth/v1/admin/users" \
  -H "apikey: $SB_SERVICE" \
  -H "Authorization: Bearer $SB_SERVICE" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$REVIEW_EMAIL\",
    \"password\": \"$REVIEW_PASSWORD\",
    \"email_confirm\": true,
    \"user_metadata\": {
      \"full_name\": \"Apple Review\",
      \"locale\": \"en\",
      \"referral_code\": \"MARVI-IST\"
    }
  }")

code=$(echo "$resp" | tail -1)
body=$(echo "$resp" | sed '$d')

if [[ "$code" == "200" || "$code" == "201" ]]; then
  echo "✓ Auth user created"
elif echo "$body" | grep -qi "already been registered"; then
  echo "✓ User already exists — updating password…"
  user_id=$(curl -sS "$SB_URL/auth/v1/admin/users?email=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REVIEW_EMAIL'))")" \
    -H "apikey: $SB_SERVICE" -H "Authorization: Bearer $SB_SERVICE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['users'][0]['id'] if d.get('users') else '')" 2>/dev/null || echo "")
  if [[ -n "$user_id" ]]; then
    curl -sS -X PUT "$SB_URL/auth/v1/admin/users/$user_id" \
      -H "apikey: $SB_SERVICE" -H "Authorization: Bearer $SB_SERVICE" \
      -H "Content-Type: application/json" \
      -d "{\"password\":\"$REVIEW_PASSWORD\",\"email_confirm\":true}" >/dev/null
    echo "✓ Password updated for $user_id"
  fi
else
  echo "✗ Failed (HTTP $code): $body" >&2
  exit 1
fi

echo ""
echo "Next: run infra/supabase/setup-review-account.sql in Supabase SQL Editor"
echo ""
echo "Apple Review Notes:"
echo "  Email: $REVIEW_EMAIL"
echo "  Password: $REVIEW_PASSWORD"
echo "  Invite code: MARVI-IST"
