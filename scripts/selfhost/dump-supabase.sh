#!/usr/bin/env bash
# Dump live Supabase data into a gitignored folder. Never prints the password.
#
# Option A — linked project (Dashboard → Project Settings → Database → Database password):
#   PGPASSWORD='…' bash scripts/selfhost/dump-supabase.sh
#
# Option B — if the pooler rejects the linked login ("tenant/user … not found"),
# paste the direct connection string from Dashboard → Connect → Direct connection:
#   SUPABASE_DB_URL='postgresql://postgres:…@db.gaswjuvyzliislqrljof.supabase.co:5432/postgres' \
#     bash scripts/selfhost/dump-supabase.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/infra/selfhost/dumps"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
# `private` holds check-in secrets; storage files live in Supabase S3 and move separately.
SCHEMAS="public,private,auth"
mkdir -p "$OUT"
chmod 700 "$OUT"

TARGET=()
if [[ -n "${SUPABASE_DB_URL:-}" ]]; then
  TARGET=(--db-url "$SUPABASE_DB_URL")
elif [[ -n "${PGPASSWORD:-}" || -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  export PGPASSWORD="${PGPASSWORD:-$SUPABASE_DB_PASSWORD}"
  TARGET=(--linked)
else
  echo "Set PGPASSWORD (Supabase database password) or SUPABASE_DB_URL." >&2
  exit 1
fi

cd "$ROOT/infra/supabase"

echo "→ schema dump (reference only; the VPS schema comes from migrations)"
supabase db dump "${TARGET[@]}" -s public,private -f "$OUT/schema-$STAMP.sql"
echo "→ data dump ($SCHEMAS)"
supabase db dump "${TARGET[@]}" --data-only --use-copy -s "$SCHEMAS" -f "$OUT/data-$STAMP.sql"

chmod 600 "$OUT"/*-"$STAMP".sql
ln -sfn "schema-$STAMP.sql" "$OUT/schema-latest.sql"
ln -sfn "data-$STAMP.sql" "$OUT/data-latest.sql"

echo "✓ Dumps in $OUT (gitignored, contains user PII)."
ls -lh "$OUT"/schema-"$STAMP".sql "$OUT"/data-"$STAMP".sql
echo "Copy data-$STAMP.sql to the VPS, then: bash scripts/selfhost/restore-dump.sh <file>"
