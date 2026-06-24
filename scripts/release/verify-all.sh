#!/bin/bash
# Full production readiness check — run before TestFlight / App Review.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        Marvi Society — Full Verification (all)           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

FAIL=0

run() {
  local name="$1"
  shift
  echo "── $name ──"
  if "$@"; then
    echo ""
  else
    echo "✗ $name FAILED"
    echo ""
    FAIL=1
  fi
}

run "Health (DB + Xcode)" bash "$REPO_ROOT/scripts/check-health.sh"
run "E2E (review account + web)" bash "$REPO_ROOT/scripts/app-store/verify-e2e.sh"
run "Auth URLs" bash "$REPO_ROOT/scripts/app-store/verify-auth-urls.sh"
run "Supabase RPCs" bash "$REPO_ROOT/scripts/verify-supabase-rpcs.sh"

echo "── Edge functions ──"
for fn in send-email send-push delete-own-account; do
  code=$(curl -sS -m 12 -o /dev/null -w "%{http_code}" \
    "https://gaswjuvyzliislqrljof.supabase.co/functions/v1/$fn" 2>/dev/null || echo "000")
  if [[ "$code" == "404" ]]; then
    echo "  ✗ $fn — not deployed (deploy: supabase functions deploy $fn)"
    FAIL=1
  else
    echo "  ✓ $fn — reachable (HTTP $code)"
  fi
done
echo ""

if [[ -f "$REPO_ROOT/apps/web/.env.local" ]] || [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  run "Email pipeline" bash "$REPO_ROOT/scripts/app-store/verify-emails.sh"
else
  echo "── Email pipeline ──"
  echo "  ⚠ Skipped — set SUPABASE_SERVICE_ROLE_KEY or apps/web/.env.local"
  echo ""
fi

echo "── iOS sign-in flags (Secrets.xcconfig) ──"
if [[ -f "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" ]]; then
  grep -E '^MARVI_(APPLE|GOOGLE)_SIGN_IN_ENABLED' "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" || true
  echo "  (NO = App Review safe; YES = full social login build)"
else
  echo "  ✗ Missing Secrets.xcconfig"
  FAIL=1
fi
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "Status: ALL AUTOMATED CHECKS PASSED"
else
  echo "Status: SOME CHECKS NEED ATTENTION (see above)"
  exit 1
fi
echo ""
