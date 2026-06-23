#!/bin/bash
# Set production secrets on WHM server and restart app.
# Usage (WHM root):
#   export SUPABASE_SERVICE_ROLE_KEY='eyJ...'
#   export NEXT_PUBLIC_SITE_URL='https://marvisociety.com'
#   bash whm-set-production-secrets.sh
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/marvisociety-web/apps/web/.env.production}"
MARVI_PORT="${MARVI_PORT:-3000}"

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "✗ Set SUPABASE_SERVICE_ROLE_KEY first (Supabase Dashboard → Settings → API → service_role)" >&2
  exit 1
fi

mkdir -p "$(dirname "$ENV_FILE")"
cat > "$ENV_FILE" <<EOF
NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY:-sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y}
NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL:-https://marvisociety.com}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
EOF
chmod 600 "$ENV_FILE"

echo "✓ Wrote $ENV_FILE"
pm2 restart marvisociety-web 2>/dev/null || true
sleep 2

health=$(curl -sS "http://127.0.0.1:${MARVI_PORT}/api/health" 2>/dev/null || echo '{}')
echo "Health: $health"
if echo "$health" | grep -q '"status":"ok"'; then
  echo "✓ Production secrets OK"
else
  echo "⚠ Health not ok — check pm2 logs marvisociety-web"
fi
