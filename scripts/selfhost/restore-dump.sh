#!/usr/bin/env bash
# Restore a Supabase dump onto self-hosted Postgres.
# Run on the VPS after apply-schema.sh:
#   bash scripts/selfhost/restore-dump.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DUMP_DIR="${MARVI_DUMP_DIR:-$ROOT/infra/selfhost/dumps}"

if [[ -f /etc/marvi/postgres.env ]]; then
  # shellcheck disable=SC1091
  source /etc/marvi/postgres.env
fi

URL="${MARVI_DATABASE_URL:-}"
[[ -n "$URL" ]] || { echo "Set MARVI_DATABASE_URL or run install-postgres-whm.sh first." >&2; exit 1; }

DATA="${1:-$DUMP_DIR/data-latest.sql}"
[[ -f "$DATA" ]] || { echo "Missing data dump: $DATA" >&2; exit 1; }

echo "→ restoring $DATA"
# Data-only dump from Supabase still references auth.users; compat table must exist.
psql "$URL" -v ON_ERROR_STOP=0 -f "$DATA"
echo "✓ Restore finished (review notices above for skipped storage/auth extras)"
