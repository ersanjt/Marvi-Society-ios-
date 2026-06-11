#!/bin/bash
# Push migrations to Supabase cloud. Requires: Node.js (npx), Supabase account.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/deploy/setup-supabase.sh YOUR_PROJECT_REF"
  echo "Example: ./scripts/deploy/setup-supabase.sh abcdefghijklmnop"
  exit 1
fi

PROJECT_REF="$1"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SUPABASE_DIR="$REPO_ROOT/infra/supabase"

echo ""
echo "=== Marvi Society — Supabase migrations ==="
echo "Project ref: $PROJECT_REF"
echo ""

cd "$SUPABASE_DIR"

if ! command -v npx >/dev/null 2>&1; then
  echo "Node.js / npx not found."
  echo "Install Node.js from https://nodejs.org then run this script again."
  echo ""
  echo "Or paste infra/supabase/ALL_MIGRATIONS_COMBINED.sql in Supabase SQL Editor."
  exit 1
fi

npx supabase login
npx supabase link --project-ref "$PROJECT_REF"
npx supabase db push

echo ""
echo "✓ Migrations applied."
echo ""
echo "Next:"
echo "  1. Supabase Dashboard → Authentication → Add user"
echo "  2. SQL Editor → run infra/supabase/seed-after-deploy.sql (replace UUID)"
echo "  3. ./apps/ios/configure-supabase.sh"
echo ""
