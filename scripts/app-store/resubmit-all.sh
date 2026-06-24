#!/bin/bash
# App Store resubmit pipeline (run on Mac).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Marvi Society — App Review Resubmit (all steps)      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

FAIL=0

if [[ -f "$REPO_ROOT/apps/web/.env.local" ]]; then
  # shellcheck disable=SC2046
  export $(grep -E '^SUPABASE_SERVICE_ROLE_KEY=' "$REPO_ROOT/apps/web/.env.local" | xargs) || true
fi

if [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  bash "$REPO_ROOT/scripts/app-store/provision-review-full.sh" || FAIL=1
else
  echo "⚠ Skipping Supabase provision — set SUPABASE_SERVICE_ROLE_KEY in apps/web/.env.local"
  echo "  Or run infra/supabase/provision-review-account.sql in SQL Editor"
  FAIL=1
fi

bash "$REPO_ROOT/scripts/app-store/build-ios-release.sh" || FAIL=1

bash "$REPO_ROOT/scripts/app-store/verify-e2e.sh" || FAIL=1

echo ""
echo "── App Store Connect (manual) ──"
echo "  1. Upload $REPO_ROOT/apps/ios/.build/export/MarviSociety.ipa"
echo "  2. App Review Information:"
echo "       review@marvisociety.com / MarviReview2026!"
echo "  3. Notes: docs/app-store/CONNECT_PASTE.txt"
echo "  4. Reply to App Review → Resubmit"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "Status: LOCAL PIPELINE COMPLETE"
else
  echo "Status: SOME STEPS NEED ATTENTION"
  exit 1
fi
