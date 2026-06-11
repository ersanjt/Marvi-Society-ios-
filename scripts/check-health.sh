#!/bin/bash
# Marvi Society — health check (database + config)
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Load iOS secrets
SB_URL=""
SB_KEY=""
if [[ -f "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" ]]; then
  SB_URL=$(grep MARVI_SUPABASE_URL "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //' | sed 's|\$()/|//|')
  SB_KEY=$(grep MARVI_SUPABASE_ANON_KEY "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //')
  API_MODE=$(grep '^MARVI_API_MODE' "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //')
fi

echo ""
echo "Marvi Society — Health Check"
echo "=========================="
echo ""

# iOS config
if [[ "$API_MODE" == "supabase" && -n "$SB_URL" && -n "$SB_KEY" ]]; then
  echo "✓ iOS: Supabase mode ($SB_URL)"
else
  echo "✗ iOS: local demo mode (Secrets.xcconfig not configured)"
fi

if [[ -z "$SB_URL" || -z "$SB_KEY" ]]; then
  echo "✗ No Supabase credentials found"
  exit 1
fi

api() {
  curl -s -H "apikey: $SB_KEY" -H "Authorization: Bearer $SB_KEY" "$SB_URL/rest/v1/$1"
}

OFFERS=$(api "offers?select=id&status=eq.live" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
PUBLIC_OFFERS=$(api "offers_public?select=id,venue_name,area" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)
VENUES=$(api "venue_profiles?select=id" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
REFERRALS=$(api "referral_codes?select=code" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

echo ""
echo "Database (public read):"
[[ "$OFFERS" -gt 0 ]] && echo "  ✓ offers (live): $OFFERS" || echo "  ✗ offers: empty — run seed SQL"
[[ "$PUBLIC_OFFERS" -gt 0 ]] && echo "  ✓ offers_public (iOS Explore): $PUBLIC_OFFERS" || echo "  ✗ offers_public: empty or no GRANT — run production_hardening.sql"
[[ "$VENUES" -gt 0 ]] && echo "  ✓ venue_profiles: $VENUES" || echo "  ✗ venue_profiles: empty"
[[ "$REFERRALS" -gt 0 ]] && echo "  ✓ referral_codes: $REFERRALS" || echo "  ✗ referral_codes: empty"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $SB_KEY" "$SB_URL/rest/v1/offers?select=id&limit=1")
[[ "$HTTP" == "200" ]] && echo "  ✓ API reachable (HTTP $HTTP)" || echo "  ✗ API error (HTTP $HTTP)"

# Xcode
if [[ -d "/Applications/Xcode.app" ]]; then
  echo ""
  echo "✓ Xcode installed"
else
  echo ""
  echo "✗ Xcode not found"
fi

echo ""
if [[ "$OFFERS" -gt 0 && "$PUBLIC_OFFERS" -gt 0 && "$REFERRALS" -gt 0 ]]; then
  echo "Status: READY for iOS Supabase testing"
else
  echo "Status: Needs setup — run production_hardening.sql + fix-user-account.sql in Supabase SQL Editor"
fi
echo ""
