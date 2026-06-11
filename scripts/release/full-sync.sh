#!/bin/bash
# End-to-end sync after any work session: verify → database → GitHub.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
marvi_require_repo

COMMIT_MSG="${1:-chore(ops): full stack sync $(date -u +%Y-%m-%dT%H:%M:%SZ)}"
FAST="${MARVI_FAST_SYNC:-0}"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Marvi Society — Full Stack Sync        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

bash "$REPO_ROOT/scripts/release/status.sh" || true

if [[ "$FAST" == "1" ]]; then
  export MARVI_SKIP_IOS_BUILD=1
  export MARVI_SKIP_WEB_BUILD=1
  marvi_warn "Fast sync: skipping web/iOS builds"
fi

marvi_info "Step 1/3 — Verify..."
if bash "$REPO_ROOT/scripts/release/verify.sh"; then
  marvi_ok "Verify passed"
else
  marvi_warn "Verify had warnings — continuing sync"
fi

marvi_info "Step 2/3 — Database..."
bash "$REPO_ROOT/scripts/release/sync-database.sh" || marvi_warn "Database sync incomplete (see above)"

marvi_info "Step 3/3 — GitHub..."
if bash "$REPO_ROOT/scripts/release/sync-github.sh" "$COMMIT_MSG"; then
  marvi_ok "GitHub synced"
else
  marvi_err "GitHub sync failed — run: gh auth login"
  exit 1
fi

echo ""
marvi_ok "Full sync complete"
echo "  Status:  npm run status"
echo "  Rollback: npm run rollback"
echo ""
