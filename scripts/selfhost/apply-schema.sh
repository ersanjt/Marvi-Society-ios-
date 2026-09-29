#!/usr/bin/env bash
# Apply Marvi schema onto self-hosted Postgres: compat layer, then each migration once.
# Safe to re-run: applied versions are tracked in supabase_migrations.schema_migrations.
#
# On the VPS (after install-postgres-whm.sh):
#   bash scripts/selfhost/apply-schema.sh
# Anywhere psql can reach the DB:
#   MARVI_DATABASE_URL=postgresql://marvi:...@127.0.0.1:5432/marvi bash scripts/selfhost/apply-schema.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPAT="$ROOT/infra/selfhost/compat/00_roles_auth_storage.sql"
MIGRATIONS="$ROOT/infra/supabase/migrations"

if [[ -z "${MARVI_DATABASE_URL:-}" && -f /etc/marvi/postgres.env ]]; then
  # shellcheck disable=SC1091
  source /etc/marvi/postgres.env
fi
URL="${MARVI_DATABASE_URL:-}"
[[ -n "$URL" ]] || { echo "Set MARVI_DATABASE_URL or run install-postgres-whm.sh first." >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "psql not found — install the PostgreSQL client." >&2; exit 1; }

PSQL=(psql "$URL" -X -q -v ON_ERROR_STOP=1)

server_version="$("${PSQL[@]}" -tAc "SHOW server_version_num")"
if (( server_version < 150000 )); then
  echo "PostgreSQL $server_version is too old — migrations need 15+ (security_invoker views). Use install-postgres-whm.sh." >&2
  exit 1
fi

echo "→ compat layer"
"${PSQL[@]}" -f "$COMPAT"

applied=0
skipped=0
for file in $(find "$MIGRATIONS" -maxdepth 1 -name '*.sql' | sort); do
  base="$(basename "$file" .sql)"
  version="${base%%_*}"
  name="${base#*_}"

  exists="$("${PSQL[@]}" -tAc "SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '$version'")"
  if [[ "$exists" == "1" ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  echo "→ $base"
  # Vanilla Postgres has no pg_net; compat stubs net.http_post instead.
  sed -E '/CREATE EXTENSION[^;]*pg_net/Id' "$file" \
    | "${PSQL[@]}" -1 -f - \
    || { echo "✗ Failed on $base — nothing from this file was committed." >&2; exit 1; }
  "${PSQL[@]}" -c "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('$version', '$name') ON CONFLICT (version) DO NOTHING"
  applied=$((applied + 1))
done

echo "✓ Schema ready — applied $applied, already present $skipped"
