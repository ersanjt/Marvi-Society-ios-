#!/bin/bash
# App Store preflight — run before Submit for Review
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
warn() { echo "  ⚠ $*"; }
ok() { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; FAIL=1; }

echo ""
echo "Marvi Society — App Store Preflight"
echo "===================================="
echo ""

echo "Website:"
for path in / /privacy /terms /community-guidelines /delete-account /contact; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" -m 15 "https://marvisociety.com${path}" 2>/dev/null || echo "ERR")
  if [[ "$code" == "200" ]]; then ok "https://marvisociety.com${path} → $code"
  else bad "https://marvisociety.com${path} → $code"; fi
done

health=$(curl -sS -m 10 "https://marvisociety.com/api/health" 2>/dev/null || echo "")
if echo "$health" | grep -q '"status":"ok"'; then
  ok "API health → ok"
elif echo "$health" | grep -q degraded; then
  bad "API health degraded — set SUPABASE_SERVICE_ROLE_KEY on WHM server"
else
  bad "API health unreachable"
fi

echo ""
echo "Supabase:"
bash "$REPO_ROOT/scripts/verify-supabase-rpcs.sh" >/dev/null 2>&1 && ok "All RPCs deployed" || bad "RPC verification failed"

echo ""
echo "iOS:"
if [[ -f "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" ]]; then ok "Secrets.xcconfig present"
else bad "Missing Secrets.xcconfig"; fi

if [[ -f "$REPO_ROOT/apps/ios/MarviSociety/Resources/Assets.xcassets/AppIcon.appiconset/MarviIcon.png" ]]; then
  ok "App icon 1024×1024 present"
else bad "Missing MarviIcon.png"; fi

team=$(grep DEVELOPMENT_TEAM "$REPO_ROOT/apps/ios/MarviSociety.xcodeproj/project.pbxproj" | head -1 | sed 's/.*= //' | tr -d ';')
ok "Development team: $team"
ok "Bundle: com.marvisociety.app · v1.0 (1)"

echo ""
echo "App Store Connect (manual):"
warn "Attach build 1.0 (1) to version 1.0"
warn "Upload screenshots (6.5\" minimum)"
warn "Complete App Privacy + Age rating questionnaires"
warn "Review Notes: demo email + password + invite code"
warn "Export compliance: No encryption"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "Status: TECHNICALLY READY — complete App Store Connect items above"
else
  echo "Status: FIX FAILURES ABOVE BEFORE SUBMIT"
fi
echo ""
