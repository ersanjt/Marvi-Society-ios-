#!/bin/bash
# One-time production email setup checklist (run on Mac with Supabase CLI logged in).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_REF="${SUPABASE_PROJECT_REF:-gaswjuvyzliislqrljof}"
SB_DIR="$REPO_ROOT/infra/supabase"

echo ""
echo "Marvi Society — Production Email Setup"
echo "======================================="
echo ""
echo "Project: $PROJECT_REF"
echo ""

steps=(
  "1. Resend: verify domain marvisociety.com + create API key"
  "2. cPanel: create support@marvisociety.com (fix suppoert@ typo if present)"
  "3. Supabase Dashboard → Edge Functions → Secrets:"
  "     RESEND_API_KEY=re_..."
  "     MARVI_FROM_EMAIL=Marvi Society <hello@marvisociety.com>"
  "     MARVI_REPLY_TO=support@marvisociety.com"
  "4. Deploy edge function send-email"
  "5. SQL Editor: run migration 20260624000001_email_production_hardening.sql"
  "6. SQL Editor: run infra/supabase/scripts/setup-email-dispatch.sql (set service role key)"
  "7. Supabase Auth → SMTP: smtp.resend.com:465, user resend, pass API key"
  "8. Database Webhook: email_outbox INSERT → /functions/v1/send-email"
  "9. WHM: SUPABASE_SERVICE_ROLE_KEY in PM2 env"
  "10. Test: bash scripts/app-store/verify-emails.sh"
)

for step in "${steps[@]}"; do
  echo "  $step"
done

echo ""
read -r -p "Deploy send-email now? [y/N] " deploy
if [[ "${deploy,,}" == "y" ]]; then
  if command -v supabase >/dev/null 2>&1; then
    (cd "$SB_DIR" && supabase functions deploy send-email --project-ref "$PROJECT_REF")
    echo "✓ send-email deployed"
  else
    echo "✗ supabase CLI not found — install: brew install supabase/tap/supabase"
    exit 1
  fi
fi

echo ""
echo "Verify:"
echo "  curl -s https://${PROJECT_REF}.supabase.co/functions/v1/send-email | python3 -m json.tool"
echo "  bash scripts/app-store/verify-emails.sh"
echo ""
