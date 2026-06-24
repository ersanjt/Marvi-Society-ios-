#!/bin/bash
# Verify Supabase auth redirect configuration (password reset must NOT use localhost on phones).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SB_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}"
SITE_URL="${NEXT_PUBLIC_SITE_URL:-https://marvisociety.com}"

echo ""
echo "Marvi Society — Auth URL check"
echo "==============================="
echo ""

FAIL=0

for path in /auth/reset-password /auth/callback; do
  code=$(curl -sS -m 15 -o /dev/null -w "%{http_code}" "${SITE_URL}${path}" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    echo "✓ ${SITE_URL}${path} (HTTP $code)"
  else
    echo "✗ ${SITE_URL}${path} HTTP $code — deploy web app first"
    FAIL=1
  fi
done

echo ""
echo "Supabase Dashboard (REQUIRED — fixes localhost in emails):"
echo "  Authentication → URL Configuration"
echo "  Site URL: https://marvisociety.com"
echo "  Redirect URLs: https://marvisociety.com/auth/reset-password"
echo ""
echo "Email templates: infra/supabase/auth-email-templates/README.md"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "Status: Web auth pages reachable"
else
  echo "Status: Deploy web to production, then update Supabase Site URL"
  exit 1
fi
echo ""
