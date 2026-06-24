#!/usr/bin/env bash
# Smoke test after web deploy — expects SITE_URL or NEXT_PUBLIC_SITE_URL
set -euo pipefail

SITE_URL="${SITE_URL:-${NEXT_PUBLIC_SITE_URL:-https://marvisociety.com}}"
SITE_URL="${SITE_URL%/}"

echo "Verifying deploy at $SITE_URL"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$SITE_URL/api/health" || echo "000")
if [[ "$HTTP" != "200" ]]; then
  echo "✗ /api/health returned HTTP $HTTP"
  exit 1
fi
echo "✓ /api/health OK"

for path in "/" "/portal/login" "/admin"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SITE_URL$path" || echo "000")
  if [[ "$CODE" != "200" && "$CODE" != "307" && "$CODE" != "308" ]]; then
    echo "✗ $path returned HTTP $CODE"
    exit 1
  fi
  echo "✓ $path reachable (HTTP $CODE)"
done

echo "Deploy verification passed."
