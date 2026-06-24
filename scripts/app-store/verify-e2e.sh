#!/bin/bash
# End-to-end smoke test: review account login + Explore data (no secrets printed).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_URL=""
SB_KEY=""

if [[ -f "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" ]]; then
  SB_URL=$(grep '^MARVI_SUPABASE_URL' "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //' | sed 's|https:/\$()/|https://|' | sed 's|\$()/|/|')
  SB_KEY=$(grep '^MARVI_SUPABASE_ANON_KEY' "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //')
fi

SB_URL="${SB_URL:-https://gaswjuvyzliislqrljof.supabase.co}"
SB_KEY="${SB_KEY:-sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y}"
REVIEW_EMAIL="${REVIEW_EMAIL:-review@marvisociety.com}"
REVIEW_PASSWORD="${REVIEW_PASSWORD:-MarviReview2026!}"

echo ""
echo "Marvi Society — E2E Smoke Test"
echo "==============================="
echo ""

FAIL=0

# 1. Production web
health=$(curl -sS -m 15 "https://marvisociety.com/api/health" 2>/dev/null || echo "")
if echo "$health" | grep -q '"status":"ok"'; then
  echo "✓ Production health ok"
else
  echo "✗ Production health degraded — set SUPABASE_SERVICE_ROLE_KEY on WHM"
  FAIL=1
fi

# 2. Legal + contact pages
for path in /privacy /terms /delete-account /contact; do
  code=$(curl -sS -m 12 -o /dev/null -w "%{http_code}" "https://marvisociety.com${path}" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    echo "✓ Web page $path"
  else
    echo "✗ Web page $path HTTP $code"
    FAIL=1
  fi
done

# 3. Review login
login_resp=$(curl -sS -m 20 -X POST "$SB_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SB_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$REVIEW_EMAIL\",\"password\":\"$REVIEW_PASSWORD\"}" 2>/dev/null || echo "{}")

if echo "$login_resp" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('access_token') else 1)" 2>/dev/null; then
  echo "✓ Review account login"
  TOKEN=$(echo "$login_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
else
  err=$(echo "$login_resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error_description') or d.get('msg') or d)" 2>/dev/null || echo "unknown")
  echo "✗ Review login failed: $err"
  FAIL=1
  TOKEN=""
fi

if [[ -n "$TOKEN" ]]; then
  # 4. Profile approved (via RPC — avoids RLS on email filter)
  ctx=$(curl -sS -m 15 -X POST "$SB_URL/rest/v1/rpc/fetch_account_context" \
    -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" -d "{}" 2>/dev/null || echo "[]")
  if echo "$ctx" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    rows = data if isinstance(data, list) else [data]
    ok = any(isinstance(r, dict) and r.get('status') == 'approved' for r in rows)
    sys.exit(0 if ok else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
    echo "✓ Review profile approved"
  else
    echo "✗ Review profile not approved — run infra/supabase/provision-review-account.sql"
    FAIL=1
  fi

  # 5. Explore offers
  offers=$(curl -sS -m 15 "$SB_URL/rest/v1/offers_public?select=id&limit=1" \
    -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "[]")
  count=$(echo "$offers" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  if [[ "$count" -gt 0 ]]; then
    echo "✓ Explore offers_public reachable ($count+ rows)"
  else
    echo "✗ offers_public empty"
    FAIL=1
  fi

  # 6. Demo booking for My Events (Etkinliklerim)
  bookings=$(curl -sS -m 15 "$SB_URL/rest/v1/bookings?select=id&limit=1" \
    -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "[]")
  bcount=$(echo "$bookings" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)
  if [[ "$bcount" -gt 0 ]]; then
    echo "✓ Review account has demo booking(s)"
  else
    echo "✗ No bookings for review account — run infra/supabase/provision-review-account.sql"
    FAIL=1
  fi
fi

# 7. Referral code exists
ref=$(curl -sS -m 15 "$SB_URL/rest/v1/referral_codes?code=eq.MARVI-IST&select=code" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $SB_KEY" 2>/dev/null || echo "[]")
if echo "$ref" | grep -q MARVI-IST; then
  echo "✓ Referral code MARVI-IST active"
else
  echo "✗ Referral MARVI-IST missing"
  FAIL=1
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "Status: ALL E2E CHECKS PASSED"
else
  echo "Status: SOME CHECKS FAILED"
  exit 1
fi
echo ""
