#!/usr/bin/env bash
# Apply Marvi schema onto self-hosted Postgres (compat layer + combined migrations).
# Run on the VPS as root after install-postgres-whm.sh, OR locally if psql can reach the DB:
#   MARVI_DATABASE_URL=postgresql://marvi:...@127.0.0.1:5432/marvi bash scripts/selfhost/apply-schema.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPAT="$ROOT/infra/selfhost/compat/00_roles_auth_storage.sql"
COMBINED="$ROOT/infra/supabase/ALL_MIGRATIONS_COMBINED.sql"
FILTERED="$(mktemp)"
trap 'rm -f "$FILTERED"' EXIT

if [[ -f /etc/marvi/postgres.env ]]; then
  # shellcheck disable=SC1091
  source /etc/marvi/postgres.env
fi

URL="${MARVI_DATABASE_URL:-}"
[[ -n "$URL" ]] || { echo "Set MARVI_DATABASE_URL or run install-postgres-whm.sh first." >&2; exit 1; }

[[ -f "$COMPAT" ]] || { echo "Missing $COMPAT" >&2; exit 1; }
[[ -f "$COMBINED" ]] || {
  echo "Combined SQL missing — generating…"
  bash "$ROOT/infra/supabase/scripts/combine-migrations.sh"
}

# Vanilla Postgres has no pg_net package; the compat layer stubs net.http_post.
python3 - "$COMBINED" "$FILTERED" <<'PY'
import sys
src, dest = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
out = []
for line in text.splitlines(True):
    if "CREATE EXTENSION" in line.upper() and "PG_NET" in line.upper():
        out.append("-- skipped (self-host stub): " + line)
    else:
        out.append(line)
open(dest, "w", encoding="utf-8").writelines(out)
PY

echo "→ compat layer"
psql "$URL" -v ON_ERROR_STOP=1 -f "$COMPAT"
echo "→ Marvi migrations (pg_net skipped)"
psql "$URL" -v ON_ERROR_STOP=1 -f "$FILTERED"
echo "✓ Schema applied on self-hosted Postgres"
