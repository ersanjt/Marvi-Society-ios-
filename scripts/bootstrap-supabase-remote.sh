#!/bin/bash
# Apply migrations to linked Supabase project + print bootstrap instructions.
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_REF=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.marvi/config.json'))['supabase']['projectRef'])")

echo ""
echo "Marvi Society — Remote Supabase bootstrap"
echo "=========================================="
echo ""
echo "Project ref: $PROJECT_REF"
echo ""

bash "$REPO_ROOT/infra/supabase/scripts/combine-migrations.sh"

if command -v npx >/dev/null 2>&1; then
  cd "$REPO_ROOT/infra/supabase"
  if [[ ! -f .temp/project-ref ]] 2>/dev/null; then
    echo "Linking project (requires: npx supabase login)..."
    npx supabase link --project-ref "$PROJECT_REF" || true
  fi
  if npx supabase db push 2>/dev/null; then
    echo "✓ Migrations pushed via CLI"
  else
    echo "⚠ CLI push skipped — paste ALL_MIGRATIONS_COMBINED.sql in SQL Editor"
  fi
else
  echo "⚠ npx not found — paste ALL_MIGRATIONS_COMBINED.sql in SQL Editor"
fi

echo ""
echo "Next (SQL Editor):"
echo "  1. infra/supabase/bootstrap-production.sql"
echo "     (edit email → run once after signing in to the app)"
echo "  2. npm run health"
echo ""
