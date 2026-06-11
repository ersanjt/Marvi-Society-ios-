#!/bin/bash
# Combine migrations and optionally push to linked Supabase project.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
marvi_require_repo

PUSH="${MARVI_DB_PUSH:-auto}"
PROJECT_REF=$(python3 -c "import json; print(json.load(open('$MARVI_CONFIG'))['supabase']['projectRef'])" 2>/dev/null || echo "")

echo ""
echo "Marvi Society — Sync Database"
echo "=============================="
echo ""

bash "$REPO_ROOT/infra/supabase/scripts/combine-migrations.sh"
marvi_update_manifest_db
marvi_ok "Combined SQL: infra/supabase/ALL_MIGRATIONS_COMBINED.sql"

if [[ "$PUSH" == "0" || "$PUSH" == "false" ]]; then
  marvi_info "DB push skipped (MARVI_DB_PUSH=0)"
  marvi_info "Manual: paste ALL_MIGRATIONS_COMBINED.sql in Supabase SQL Editor"
  marvi_append_sync_log "partial" "migrations combined only (push skipped)"
  exit 0
fi

if ! command -v npx >/dev/null 2>&1; then
  marvi_warn "npx not found — cannot db push via CLI"
  marvi_info "Manual: Supabase Dashboard → SQL Editor → ALL_MIGRATIONS_COMBINED.sql"
  marvi_append_sync_log "partial" "migrations combined; CLI push unavailable"
  exit 0
fi

cd "$REPO_ROOT/infra/supabase"

if [[ "$PUSH" == "force" ]] || marvi_supabase_linked; then
  marvi_info "Pushing migrations via Supabase CLI..."
  if [[ -n "$PROJECT_REF" ]] && ! marvi_supabase_linked; then
    marvi_info "Linking project ref: $PROJECT_REF"
    npx supabase link --project-ref "$PROJECT_REF"
  fi
  if npx supabase db push; then
    marvi_ok "Database migrations applied"
    marvi_append_sync_log "ok" "supabase db push succeeded (head: $(marvi_migration_head))"
  else
    marvi_err "db push failed"
    marvi_info "Fallback: paste ALL_MIGRATIONS_COMBINED.sql in SQL Editor"
    marvi_append_sync_log "error" "supabase db push failed"
    exit 1
  fi
else
  marvi_warn "Supabase CLI not linked"
  echo ""
  echo "  Option A (recommended): npm run db:push"
  echo "  Option B: paste infra/supabase/ALL_MIGRATIONS_COMBINED.sql in SQL Editor"
  echo "  Project ref: $PROJECT_REF"
  marvi_append_sync_log "partial" "migrations combined; CLI not linked"
fi

echo ""
