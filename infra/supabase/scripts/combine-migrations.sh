#!/usr/bin/env bash
# Concatenate ordered migrations into ALL_MIGRATIONS_COMBINED.sql for one-shot SQL Editor deploy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$SUPABASE_DIR/../.." && pwd)"
MIGRATIONS_DIR="$SUPABASE_DIR/migrations"
OUTPUT="$SUPABASE_DIR/ALL_MIGRATIONS_COMBINED.sql"

if [[ ! -d "$MIGRATIONS_DIR" ]]; then
  echo "Missing migrations directory: $MIGRATIONS_DIR" >&2
  exit 1
fi

{
  echo "-- Marvi Society — combined migrations"
  echo "-- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "-- Source: infra/supabase/migrations/*.sql (lexicographic order)"
  echo "-- Do not edit by hand; run: npm run db:combine"
  echo ""

  find "$MIGRATIONS_DIR" -maxdepth 1 -name '*.sql' -print | sort | while read -r file; do
    echo "-- ═══════════════════════════════════════════════════════════════════════════"
    echo "-- $(basename "$file")"
    echo "-- ═══════════════════════════════════════════════════════════════════════════"
    cat "$file"
    echo ""
    echo ""
  done
} > "$OUTPUT"

echo "Wrote $OUTPUT ($(wc -l < "$OUTPUT" | tr -d ' ') lines)"
