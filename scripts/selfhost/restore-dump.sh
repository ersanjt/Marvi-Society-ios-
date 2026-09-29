#!/usr/bin/env bash
# Restore a Supabase data dump onto self-hosted Postgres (after apply-schema.sh).
#   bash scripts/selfhost/restore-dump.sh [path/to/data.sql]
#
# All-or-nothing: runs in one transaction. Triggers are disabled for the load so the
# signup trigger does not re-create profiles and guard triggers do not reject rows.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DUMP_DIR="${MARVI_DUMP_DIR:-$ROOT/infra/selfhost/dumps}"

if [[ -z "${MARVI_DATABASE_URL:-}" && -f /etc/marvi/postgres.env ]]; then
  # shellcheck disable=SC1091
  source /etc/marvi/postgres.env
fi
URL="${MARVI_DATABASE_URL:-}"
[[ -n "$URL" ]] || { echo "Set MARVI_DATABASE_URL or run install-postgres-whm.sh first." >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "psql not found — install the PostgreSQL client." >&2; exit 1; }

DATA="${1:-$DUMP_DIR/data-latest.sql}"
[[ -f "$DATA" ]] || { echo "Missing data dump: $DATA" >&2; exit 1; }

FILTERED="$(mktemp)"
trap 'rm -f "$FILTERED"' EXIT
python3 "$ROOT/scripts/selfhost/filter-dump.py" "$DATA" "$FILTERED"

existing="$(psql "$URL" -X -tAc "SELECT count(*) FROM auth.users")"
if [[ "$existing" != "0" && "${MARVI_RESTORE_FORCE:-0}" != "1" ]]; then
  echo "auth.users already has $existing rows. Restore into an empty database," >&2
  echo "or set MARVI_RESTORE_FORCE=1 if you know the rows do not overlap." >&2
  exit 1
fi

echo "→ restoring $(basename "$DATA")"
{
  echo "SET session_replication_role = replica;"
  cat "$FILTERED"
} | psql "$URL" -X -q -1 -v ON_ERROR_STOP=1 -f -

echo "→ row counts"
psql "$URL" -X -c "
  SELECT 'auth.users' AS table, count(*) FROM auth.users
  UNION ALL SELECT 'auth.identities', count(*) FROM auth.identities
  UNION ALL SELECT 'public.profiles', count(*) FROM public.profiles
  UNION ALL SELECT 'public.venue_profiles', count(*) FROM public.venue_profiles
  UNION ALL SELECT 'public.offers', count(*) FROM public.offers
  UNION ALL SELECT 'public.bookings', count(*) FROM public.bookings;"
echo "✓ Restore committed"
