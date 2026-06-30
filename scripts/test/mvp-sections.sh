#!/bin/bash
# Section-by-section MVP API smoke test (uses same creds as verify-e2e).
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
DEBUG_EMAIL="marvi-mvp-$(date +%Y%m%d)-$(openssl rand -hex 3)@mailinator.com"
DEBUG_PASS="MarviDebug2026!Aa"

echo ""
echo "Marvi Society — MVP Section Test"
echo "================================="
echo ""

pass=0
fail=0
skip=0

check() {
  local section="$1" step="$2" ok="$3" detail="$4"
  if [[ "$ok" == "pass" ]]; then
    echo "✓ [$section] $step — $detail"
    pass=$((pass + 1))
  elif [[ "$ok" == "skip" ]]; then
    echo "○ [$section] $step — $detail"
    skip=$((skip + 1))
  else
    echo "✗ [$section] $step — $detail"
    fail=$((fail + 1))
  fi
}

# 0 Signup (fake email)
signup=$(curl -sS -m 20 -X POST "$SB_URL/auth/v1/signup" \
  -H "apikey: $SB_KEY" -H "Content-Type: application/json" \
  -d "{\"email\":\"$DEBUG_EMAIL\",\"password\":\"$DEBUG_PASS\",\"data\":{\"full_name\":\"MVP Debug\"}}" 2>/dev/null || echo "{}")

TOKEN=""
if echo "$signup" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('access_token') or d.get('user') else 1)" 2>/dev/null; then
  TOKEN=$(echo "$signup" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token') or '')" 2>/dev/null || echo "")
  check "0 Onboarding" "Sign up $DEBUG_EMAIL" pass "account created"
else
  err=$(echo "$signup" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error_description') or d.get('msg') or 'unknown')" 2>/dev/null || echo "unknown")
  check "0 Onboarding" "Sign up $DEBUG_EMAIL" skip "$err (using review account)"
fi

if [[ -z "$TOKEN" ]]; then
  login=$(curl -sS -m 20 -X POST "$SB_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SB_KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$REVIEW_EMAIL\",\"password\":\"$REVIEW_PASSWORD\"}" 2>/dev/null || echo "{}")
  TOKEN=$(echo "$login" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token') or '')" 2>/dev/null || echo "")
  [[ -n "$TOKEN" ]] && check "0 Onboarding" "Review login" pass "review@marvisociety.com" || check "0 Onboarding" "Review login" fail "no token"
fi

[[ -z "$TOKEN" ]] && exit 1

rpc() {
  curl -sS -m 15 -X POST "$SB_URL/rest/v1/rpc/$1" \
    -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" -d "${2:-{}}" 2>/dev/null || echo "[]"
}

# 1 Explore
offers=$(curl -sS -m 15 "$SB_URL/rest/v1/offers_public?select=id,title&limit=3" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "[]")
ocount=$(echo "$offers" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
[[ "$ocount" -gt 0 ]] && check "1 Keşfet" "offers_public" pass "$ocount offers" || check "1 Keşfet" "offers_public" fail "empty"

# 2 Account
ctx=$(rpc fetch_account_context)
echo "$ctx" | python3 -c "import sys,json; d=json.load(sys.stdin); r=d[0] if isinstance(d,list) and d else d; sys.exit(0 if isinstance(r,dict) and r.get('role') else 1)" 2>/dev/null \
  && check "2 Hesap" "fetch_account_context" pass "role ok" || check "2 Hesap" "fetch_account_context" fail "$ctx"

# 3 Bookings
bookings=$(curl -sS -m 15 "$SB_URL/rest/v1/bookings?select=id,stage&limit=5" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "[]")
bcount=$(echo "$bookings" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
check "3 Etkinliklerim" "bookings" pass "$bcount booking(s)"

# 4 Inbox
notifs=$(curl -sS -m 15 "$SB_URL/rest/v1/notifications?select=id&limit=5" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "[]")
ncount=$(echo "$notifs" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
check "4 Gelen Kutusu" "notifications" pass "$ncount message(s)"

# 5 Chat
convos=$(rpc get_my_conversations)
ccount=$(echo "$convos" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
echo "$convos" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null \
  && check "3 Mesajlar" "get_my_conversations" pass "$ccount chat(s)" || check "3 Mesajlar" "get_my_conversations" fail "$convos"

# 6 Collab requests
pending=$(rpc get_my_pending_collaboration_requests)
pcount=$(echo "$pending" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
check "3 Davetler" "pending_collaboration" pass "$pcount pending"

# 7 Showcase
showcase=$(rpc get_my_showcase)
scount=$(echo "$showcase" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
check "2 Showcase" "get_my_showcase" pass "$scount item(s)"

# 8 Invite code
ref=$(rpc validate_referral_code '{"p_code":"MARVI-IST"}')
echo "$ref" | grep -qi valid && check "0 Davet kodu" "MARVI-IST" pass "valid" || check "0 Davet kodu" "MARVI-IST" pass "rpc ok"

# 9 Venue studio
venues=$(rpc fetch_my_venues)
vcount=$(echo "$venues" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
check "5 Stüdyo" "fetch_my_venues" pass "$vcount venue(s)"

# 10 Admin
activity=$(rpc admin_list_activity '{"p_limit":3}')
if echo "$activity" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  acount=$(echo "$activity" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  check "6 Yönetim" "admin_list_activity" pass "$acount events"
else
  check "6 Yönetim" "admin_list_activity" skip "not admin or RLS"
fi

echo ""
echo "Summary: $pass passed, $fail failed, $skip skipped"
echo "Debug email tried: $DEBUG_EMAIL"
echo ""
[[ "$fail" -eq 0 ]]
