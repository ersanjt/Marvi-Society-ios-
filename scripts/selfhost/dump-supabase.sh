#!/usr/bin/env bash
# Dump live Supabase (schema+data) into a gitignored folder. Does NOT print the password.
#
# From this Mac (CLI already linked to marvi-society):
#   PGPASSWORD='your-supabase-db-password' bash scripts/selfhost/dump-supabase.sh
#
# Password: Supabase Dashboard → Project Settings → Database → Database password
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/infra/selfhost/dumps"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

if [[ -z "${PGPASSWORD:-}" && -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "Set PGPASSWORD to the Supabase database password (Dashboard → Database settings)." >&2
  exit 1
fi
export PGPASSWORD="${PGPASSWORD:-$SUPABASE_DB_PASSWORD}"

cd "$ROOT/infra/supabase"

echo "→ schema dump"
supabase db dump --linked -f "$OUT/schema-$STAMP.sql"
echo "→ data dump (public + auth)"
supabase db dump --linked --data-only --use-copy -f "$OUT/data-$STAMP.sql"

# Keep a stable "latest" pointer for restore-dump.sh
ln -sfn "schema-$STAMP.sql" "$OUT/schema-latest.sql"
ln -sfn "data-$STAMP.sql" "$OUT/data-latest.sql"

echo "✓ Wrote dumps to $OUT (gitignored). Copy them to the VPS then run restore-dump.sh"
ls -lh "$OUT"/schema-"$STAMP".sql "$OUT"/data-"$STAMP".sql
