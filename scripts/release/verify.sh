#!/bin/bash
# Pre-flight: combine migrations, health check, web + iOS builds.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
marvi_require_repo

SKIP_IOS="${MARVI_SKIP_IOS_BUILD:-0}"
SKIP_WEB="${MARVI_SKIP_WEB_BUILD:-0}"
SKIP_HEALTH="${MARVI_SKIP_HEALTH:-0}"

echo ""
echo "Marvi Society — Verify"
echo "======================"
echo ""

marvi_info "Combining database migrations..."
bash "$REPO_ROOT/infra/supabase/scripts/combine-migrations.sh"
marvi_update_manifest_db
marvi_ok "Migrations combined"

if [[ "$SKIP_HEALTH" != "1" ]]; then
  marvi_info "Running health check..."
  if bash "$REPO_ROOT/scripts/check-health.sh"; then
    marvi_ok "Health check passed"
  else
    marvi_warn "Health check failed (missing Supabase config or empty DB)"
    marvi_warn "Continue setup: docs/OPERATIONS.md → Database"
  fi
fi

if [[ "$SKIP_WEB" != "1" ]]; then
  marvi_info "Building web..."
  cd "$REPO_ROOT/apps/web"
  npm install --silent 2>/dev/null || npm install
  npm run build
  marvi_ok "Web build passed"
fi

if [[ "$SKIP_IOS" != "1" ]]; then
  marvi_info "Building iOS..."
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild \
    -project "$REPO_ROOT/apps/ios/MarviSociety.xcodeproj" \
    -scheme MarviSociety \
    -destination 'generic/platform=iOS' \
    -configuration Debug \
    build \
    | tail -5
  marvi_ok "iOS build passed"
else
  marvi_warn "iOS build skipped (MARVI_SKIP_IOS_BUILD=1)"
fi

marvi_ok "Verify complete"
echo ""
