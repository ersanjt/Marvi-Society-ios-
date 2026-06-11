#!/bin/bash
# Print full stack status: git, GitHub, database, iOS, web.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
marvi_require_repo

echo ""
echo "Marvi Society — System Status"
echo "=============================="
echo ""

# Git
BRANCH=$(git -C "$REPO_ROOT" branch --show-current)
AHEAD=$(git -C "$REPO_ROOT" rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
BEHIND=$(git -C "$REPO_ROOT" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
DIRTY=$(git -C "$REPO_ROOT" status --porcelain | wc -l | tr -d ' ')
LAST_COMMIT=$(git -C "$REPO_ROOT" log -1 --format='%h %s (%cr)')

echo "Git"
echo "  branch: $BRANCH"
echo "  ahead of origin/main: $AHEAD | behind: $BEHIND | uncommitted files: $DIRTY"
echo "  last commit: $LAST_COMMIT"

# GitHub
echo ""
echo "GitHub"
if marvi_github_authenticated; then
  marvi_ok "  gh CLI authenticated"
  REMOTE=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "none")
  echo "  remote: $REMOTE"
else
  marvi_warn "  gh not logged in — run: gh auth login"
fi

# Database
echo ""
echo "Database (Supabase)"
HEAD=$(marvi_migration_head)
COUNT=$(marvi_migration_count)
echo "  migrations: $COUNT files"
echo "  head: $HEAD"
if [[ -f "$REPO_ROOT/infra/supabase/ALL_MIGRATIONS_COMBINED.sql" ]]; then
  COMBINED_AGE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$REPO_ROOT/infra/supabase/ALL_MIGRATIONS_COMBINED.sql" 2>/dev/null || stat -c "%y" "$REPO_ROOT/infra/supabase/ALL_MIGRATIONS_COMBINED.sql" 2>/dev/null | cut -d. -f1)
  echo "  combined SQL updated: $COMBINED_AGE"
fi
if marvi_supabase_linked; then
  marvi_ok "  Supabase CLI linked"
else
  marvi_warn "  Supabase CLI not linked — run: npm run db:push"
fi

# iOS
echo ""
echo "iOS"
if [[ -f "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" ]]; then
  MODE=$(grep '^MARVI_API_MODE' "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" | head -1 | sed 's/.*= //' || true)
  marvi_ok "  Secrets.xcconfig present (mode: ${MODE:-unknown})"
else
  marvi_warn "  Secrets.xcconfig missing — run: apps/ios/configure-supabase.sh"
fi

# Web
echo ""
echo "Web"
if [[ -f "$REPO_ROOT/apps/web/.env.local" ]]; then
  marvi_ok "  .env.local present"
else
  marvi_warn "  .env.local missing — copy apps/web/.env.example"
fi

# Manifest
echo ""
echo "Release manifest"
if [[ -f "$MARVI_MANIFEST" ]]; then
  python3 - "$MARVI_MANIFEST" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print(f"  version: {data.get('version', '?')}")
db = data.get("components", {}).get("database", {})
print(f"  recorded migration head: {db.get('migrationHead', '?')}")
sync = data.get("syncLog", [])
if sync:
    print(f"  last sync: {sync[0].get('at')} — {sync[0].get('status')}: {sync[0].get('message')}")
PY
else
  marvi_warn "  release/manifest.json missing"
fi

echo ""
