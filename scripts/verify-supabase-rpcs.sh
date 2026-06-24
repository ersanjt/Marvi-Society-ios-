#!/bin/bash
# Verify Supabase RPCs and schema required by iOS + web (uses anon key from Secrets.xcconfig).
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SB_URL=""
SB_KEY=""
if [[ -f "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" ]]; then
  SB_URL=$(grep MARVI_SUPABASE_URL "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //' | sed 's|https:/\$()/|https://|' | sed 's|\$()/|/|')
  SB_KEY=$(grep MARVI_SUPABASE_ANON_KEY "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //')
fi

if [[ -z "$SB_URL" || -z "$SB_KEY" ]]; then
  echo "✗ Missing Supabase credentials in Secrets.xcconfig"
  exit 1
fi

api_get() {
  curl -sS -w "\n%{http_code}" -H "apikey: $SB_KEY" -H "Authorization: Bearer $SB_KEY" "$SB_URL/rest/v1/$1"
}

api_rpc() {
  curl -sS -w "\n%{http_code}" -X POST "$SB_URL/rest/v1/rpc/$1" \
    -H "apikey: $SB_KEY" -H "Authorization: Bearer $SB_KEY" \
    -H "Content-Type: application/json" -d "${2:-{}}"
}

check_rpc_exists() {
  local name="$1"
  local body="${2:-{}}"
  local resp code body_out
  resp=$(api_rpc "$name" "$body")
  code=$(echo "$resp" | tail -1)
  body_out=$(echo "$resp" | sed '$d')
  if [[ "$code" == "404" ]] && echo "$body_out" | grep -qi "could not find"; then
    echo "  ✗ $name — NOT DEPLOYED (404)"
    return 1
  fi
  # 401 = exists but needs auth; 400/42883 = exists with wrong args; 200/204 = ok
  echo "  ✓ $name — deployed (HTTP $code)"
  return 0
}

echo ""
echo "Marvi Society — Supabase RPC Verification"
echo "=========================================="
echo "Project: $SB_URL"
echo ""

FAIL=0

echo "Core RPCs:"
check_rpc_exists "fetch_account_context" || FAIL=1
check_rpc_exists "ensure_creator_profile" || FAIL=1
check_rpc_exists "redeem_referral_code" '{"p_code":"MARVI2026"}' || FAIL=1

echo ""
echo "Multi-venue RPCs:"
check_rpc_exists "fetch_my_venues" || FAIL=1
check_rpc_exists "set_active_venue" '{"p_venue_id":"00000000-0000-0000-0000-000000000001"}' || FAIL=1
check_rpc_exists "register_venue_location" '{"p_venue_name":"Test","p_area":"Test","p_category":"dining"}' || FAIL=1
check_rpc_exists "resolve_active_venue_id" || FAIL=1

echo ""
echo "Campaign / venue RPCs:"
check_rpc_exists "submit_campaign_for_review" '{"p_title":"t","p_category":"dining","p_model":"invitation","p_date_label":"TBD","p_value_label":"x","p_slots":2,"p_deliverables":["story"]}' || FAIL=1
check_rpc_exists "fetch_swipe_candidates" || FAIL=1
check_rpc_exists "fetch_venue_review_queue" || FAIL=1

echo ""
echo "Account lifecycle:"
check_rpc_exists "pause_own_account" || FAIL=1
check_rpc_exists "reactivate_own_account" || FAIL=1
check_rpc_exists "delete_own_account" || FAIL=1

echo ""
echo "Schema:"
resp=$(api_get "profiles?select=active_venue_id&limit=0")
code=$(echo "$resp" | tail -1)
if [[ "$code" == "200" ]]; then
  echo "  ✓ profiles.active_venue_id column"
else
  body=$(echo "$resp" | sed '$d')
  if echo "$body" | grep -qi "active_venue_id"; then
    echo "  ✗ profiles.active_venue_id — missing (run apply-multi-venue.sql)"
    FAIL=1
  else
    echo "  ? profiles query HTTP $code"
  fi
fi

del_resp=$(api_get "deletion_requests?select=id&limit=0")
del_code=$(echo "$del_resp" | tail -1)
if [[ "$del_code" == "200" ]]; then
  echo "  ✓ deletion_requests table"
else
  echo "  ✗ deletion_requests — missing (run apply-account-lifecycle.sql or demo_leads migration)"
  FAIL=1
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "Status: ALL CHECKS PASSED"
else
  echo "Status: SOME CHECKS FAILED — run missing apply-*.sql in Supabase SQL Editor"
  echo ""
  echo "Recommended order:"
  echo "  1. infra/supabase/apply-referral-fix.sql"
  echo "  2. infra/supabase/apply-admin-operations.sql"
  echo "  3. infra/supabase/apply-push-outbox.sql"
  echo "  4. infra/supabase/apply-account-lifecycle.sql"
  echo "  5. infra/supabase/apply-multi-venue.sql"
fi
echo ""
