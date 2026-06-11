#!/bin/bash
# Shared helpers for Marvi ops scripts.
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MARVI_CONFIG="$REPO_ROOT/.marvi/config.json"
MARVI_MANIFEST="$REPO_ROOT/release/manifest.json"
MARVI_LOG_DIR="$REPO_ROOT/release/logs"

marvi_color() {
  local code="$1"
  shift
  printf "\033[%sm%s\033[0m\n" "$code" "$*"
}

marvi_info() { marvi_color "36" "ℹ $*"; }
marvi_ok() { marvi_color "32" "✓ $*"; }
marvi_warn() { marvi_color "33" "⚠ $*"; }
marvi_err() { marvi_color "31" "✗ $*" >&2; }

marvi_require_repo() {
  if [[ ! -d "$REPO_ROOT/.git" ]]; then
    marvi_err "Not a git repository: $REPO_ROOT"
    exit 1
  fi
}

marvi_migration_head() {
  find "$REPO_ROOT/infra/supabase/migrations" -maxdepth 1 -name '*.sql' -print \
    | sort \
    | tail -1 \
    | sed 's|.*/||; s/\.sql$//'
}

marvi_migration_count() {
  find "$REPO_ROOT/infra/supabase/migrations" -maxdepth 1 -name '*.sql' | wc -l | tr -d ' '
}

marvi_update_manifest_db() {
  local head count
  head="$(marvi_migration_head)"
  count="$(marvi_migration_count)"
  python3 - "$MARVI_MANIFEST" "$head" "$count" <<'PY'
import json, sys
path, head, count = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data.setdefault("components", {}).setdefault("database", {})
data["components"]["database"]["migrationHead"] = head
data["components"]["database"]["migrationCount"] = int(count)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

marvi_append_sync_log() {
  local status="$1"
  local message="$2"
  mkdir -p "$MARVI_LOG_DIR"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  python3 - "$MARVI_MANIFEST" "$ts" "$status" "$message" <<'PY'
import json, sys
path, ts, status, message = sys.argv[1:5]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
entry = {"at": ts, "status": status, "message": message}
data.setdefault("syncLog", []).insert(0, entry)
data["syncLog"] = data["syncLog"][:50]
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
  echo "$ts [$status] $message" >> "$MARVI_LOG_DIR/sync.log"
}

marvi_github_authenticated() {
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

marvi_supabase_linked() {
  [[ -f "$REPO_ROOT/infra/supabase/.temp/project-ref" ]] || \
    [[ -f "$REPO_ROOT/infra/supabase/.branches/_current_branch" ]]
}
