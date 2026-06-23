#!/bin/bash
# One-command App Store prep (run on WHM or Mac with SUPABASE_SERVICE_ROLE_KEY set)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo ""
echo "Marvi Society — App Store prep"
echo "==============================="
echo ""

bash "$REPO_ROOT/scripts/app-store/provision-review-account.sh"
bash "$REPO_ROOT/scripts/app-store-preflight.sh"

echo ""
echo "Manual steps remaining:"
echo "  1. Supabase SQL Editor → infra/supabase/provision-review-account.sql"
echo "  2. Supabase Auth → SMTP (mail.marvisociety.com or Resend)"
echo "  3. App Store Connect → docs/app-store/SUBMIT_NOW.md"
echo ""
