#!/bin/bash
# Email infrastructure smoke test (read-only checks + optional outbox query).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_URL="${MARVI_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}"
SB_SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [[ -z "$SB_SERVICE_KEY" && -f "$REPO_ROOT/apps/web/.env.local" ]]; then
  SB_SERVICE_KEY=$(grep '^SUPABASE_SERVICE_ROLE_KEY=' "$REPO_ROOT/apps/web/.env.local" | head -1 | cut -d= -f2- | tr -d '"')
fi

echo ""
echo "Marvi Society — Email Verification"
echo "==================================="
echo ""

FAIL=0

# 1. send-email edge function deployed?
send_health=$(curl -sS -m 15 "$SB_URL/functions/v1/send-email" 2>/dev/null || echo "")
if echo "$send_health" | grep -q '"service":"send-email"'; then
  echo "✓ send-email edge function deployed"
  if echo "$send_health" | grep -q '"resendConfigured":true'; then
    echo "✓ RESEND_API_KEY configured on edge function"
  else
    echo "✗ RESEND_API_KEY missing on edge function — add secret + redeploy"
    FAIL=1
  fi
else
  code=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" "$SB_URL/functions/v1/send-email" 2>/dev/null || echo "000")
  echo "✗ send-email not deployed (HTTP $code) — run: supabase functions deploy send-email"
  FAIL=1
fi

# 2. Production web health (needs service role for full delete flow)
health=$(curl -sS -m 12 "https://marvisociety.com/api/health" 2>/dev/null || echo "")
if echo "$health" | grep -q '"status":"ok"'; then
  echo "✓ Production web health ok (service role set)"
elif echo "$health" | grep -q '"status":"degraded"'; then
  echo "✗ Production degraded — SUPABASE_SERVICE_ROLE_KEY missing on WHM"
  FAIL=1
else
  echo "✗ Production health unreachable"
  FAIL=1
fi

# 3. Contact API exists (HEAD/OPTIONS not needed — dry validation)
contact_code=$(curl -sS -m 12 -o /dev/null -w "%{http_code}" \
  -X POST "https://marvisociety.com/api/contact" \
  -H "Content-Type: application/json" \
  -d '{}' 2>/dev/null || echo "000")
if [[ "$contact_code" == "400" ]]; then
  echo "✓ Contact API route live (validation works)"
else
  echo "✗ Contact API unexpected HTTP $contact_code"
  FAIL=1
fi

# 4. email_outbox recent rows (requires service role)
if [[ -n "$SB_SERVICE_KEY" ]]; then
  outbox=$(curl -sS -m 15 "$SB_URL/rest/v1/email_outbox?select=template,status,error_message,created_at&order=created_at.desc&limit=5" \
    -H "apikey: $SB_SERVICE_KEY" \
    -H "Authorization: Bearer $SB_SERVICE_KEY" 2>/dev/null || echo "[]")

  pending=$(echo "$outbox" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for r in d if r.get('status')=='pending'))" 2>/dev/null || echo 0)
  failed=$(echo "$outbox" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for r in d if r.get('status')=='failed'))" 2>/dev/null || echo 0)
  dispatch_err=$(echo "$outbox" | python3 -c "import sys,json; d=json.load(sys.stdin); print(any('Dispatch not configured' in (r.get('error_message') or '') for r in d))" 2>/dev/null || echo False)

  echo "✓ email_outbox readable ($pending pending, $failed failed in last 5)"
  if [[ "$dispatch_err" == "True" ]]; then
    echo "✗ Email dispatch not configured — run infra/supabase/scripts/setup-email-dispatch.sql"
    FAIL=1
  fi
  if [[ "$failed" -gt 0 ]]; then
    echo "  ⚠ Recent failed rows — check Supabase email_outbox.error_message"
  fi
else
  echo "⚠ Skipping email_outbox check — export SUPABASE_SERVICE_ROLE_KEY to verify queue"
fi

# 5. Support email DNS note
echo ""
echo "Manual checks (cPanel / Supabase Dashboard):"
echo "  • support@marvisociety.com inbox exists (NOT suppoert@)"
echo "  • Supabase Auth → SMTP → smtp.resend.com (for delete OTP + password reset)"
echo "  • Resend domain marvisociety.com = Verified"
echo "  • Database Webhook on email_outbox INSERT → send-email"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "Status: EMAIL INFRA CHECKS PASSED (run manual OTP test on /delete-account)"
else
  echo "Status: EMAIL INFRA NEEDS FIXES — see docs/EMAIL_SETUP.md"
  exit 1
fi
echo ""
