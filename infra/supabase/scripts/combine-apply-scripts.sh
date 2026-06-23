#!/usr/bin/env bash
# Combine idempotent apply-*.sql patches for existing Supabase projects.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="$SUPABASE_DIR/apply-production-all.sql"

ORDER=(
  apply-referral-fix.sql
  apply-admin-operations.sql
  apply-push-outbox.sql
  apply-account-lifecycle.sql
  apply-multi-venue.sql
)

{
  echo "-- Marvi Society — production patches (idempotent)"
  echo "-- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "-- Run in Supabase SQL Editor on EXISTING projects (schema already deployed)."
  echo "-- Safe to re-run. Do not use on empty DB — use ALL_MIGRATIONS_COMBINED.sql instead."
  echo ""

  for file in "${ORDER[@]}"; do
    path="$SUPABASE_DIR/$file"
    [[ -f "$path" ]] || { echo "Missing $path" >&2; exit 1; }
    echo "-- ═══════════════════════════════════════════════════════════════════════════"
    echo "-- $file"
    echo "-- ═══════════════════════════════════════════════════════════════════════════"
    cat "$path"
    echo ""
    echo ""
  done
} > "$OUTPUT"

echo "Wrote $OUTPUT ($(wc -l < "$OUTPUT" | tr -d ' ') lines)"
