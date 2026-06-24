#!/bin/bash
# Full project audit — builds + Supabase health + SQL checklist
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo ""
echo "Marvi Society — Full Audit"
echo "=========================="
echo ""

bash "$REPO_ROOT/scripts/check-health.sh" || true

echo ""
if bash "$REPO_ROOT/scripts/verify-supabase-rpcs.sh"; then
  echo "Supabase schema/RPCs: verified"
else
  echo "SQL scripts to apply in Supabase (in order if fresh):"
  for f in \
    apply-referral-fix.sql \
    apply-admin-operations.sql \
    apply-push-outbox.sql \
    apply-account-lifecycle.sql \
    apply-multi-venue.sql
  do
    if [[ -f "$REPO_ROOT/infra/supabase/$f" ]]; then
      echo "  • infra/supabase/$f"
    fi
  done
fi

echo ""
echo "Building iOS (Simulator)..."
(cd "$REPO_ROOT/apps/ios" && xcodebuild -scheme MarviSociety \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "./.derivedData" \
  CODE_SIGNING_ALLOWED=NO build -quiet) && echo "✓ iOS BUILD SUCCEEDED" || echo "✗ iOS BUILD FAILED"

echo ""
echo "Building web..."
(cd "$REPO_ROOT/apps/web" && npm run build -q) && echo "✓ Web BUILD SUCCEEDED" || echo "✗ Web BUILD FAILED"

echo ""
echo "Production site:"
health=$(curl -sS -m 10 "https://marvisociety.com/api/health" 2>/dev/null || echo "")
if echo "$health" | grep -q '"status":"ok"'; then
  echo "  ✓ marvisociety.com/api/health → ok"
elif echo "$health" | grep -q degraded; then
  echo "  ✗ marvisociety.com/api/health → degraded (SUPABASE_SERVICE_ROLE_KEY missing on server)"
else
  echo "  ✗ marvisociety.com/api/health → unreachable"
fi

echo ""
echo "Local config reminders:"
if [[ -f "$REPO_ROOT/apps/web/.env.local" ]]; then
  if grep -q '^SUPABASE_SERVICE_ROLE_KEY=$' "$REPO_ROOT/apps/web/.env.local" 2>/dev/null; then
    echo "  ⚠ Web: set SUPABASE_SERVICE_ROLE_KEY in apps/web/.env.local for admin delete-account"
  else
    echo "  ✓ Web .env.local present"
  fi
else
  echo "  ⚠ Web: copy apps/web/.env.local.template → .env.local"
fi

if [[ -f "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" ]]; then
  echo "  ✓ iOS Secrets.xcconfig present"
else
  echo "  ⚠ iOS: copy Config/Secrets.xcconfig.example → Config/Secrets.xcconfig"
fi

echo ""
