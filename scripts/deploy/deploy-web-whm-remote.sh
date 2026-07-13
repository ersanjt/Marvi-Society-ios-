#!/usr/bin/env bash
# Deploy Marvi web to the WHM/cPanel server (NOT Vercel).
#
# Preferred (run inside WHM Terminal as root):
#   bash scripts/deploy/deploy-web-whm.sh
#
# Or from this Mac once SSH root access works:
#   MARVI_WHM_HOST=root@92.205.182.143 bash scripts/deploy/deploy-web-whm-remote.sh
set -euo pipefail

HOST="${MARVI_WHM_HOST:-root@92.205.182.143}"
SRC="${MARVI_SRC:-/opt/marvisociety-src}"
APP="${MARVI_APP_DIR:-/opt/marvisociety-web}"

echo "Marvi Society — WHM remote deploy"
echo "Host: $HOST"
echo ""

ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" bash -s <<EOF
set -euo pipefail
SRC="$SRC"
APP="$APP"

echo "→ git pull in \$SRC"
cd "\$SRC"
git fetch origin main
git reset --hard origin/main

echo "→ build web"
cd "\$SRC"
npm ci
npm run web:build

echo "→ sync standalone build into \$APP"
# Prefer existing install path used by PM2
if [[ -d "\$APP" ]]; then
  rsync -a --delete "\$SRC/apps/web/.next/standalone/" "\$APP/" 2>/dev/null || true
  mkdir -p "\$APP/apps/web"
  # Keep env
  if [[ -f "\$APP/apps/web/.env.production" ]]; then
    echo "  keeping existing .env.production"
  elif [[ -f "\$SRC/apps/web/.env.production" ]]; then
    cp "\$SRC/apps/web/.env.production" "\$APP/apps/web/.env.production"
  fi
fi

# Fallback rebuild-in-place used by older installs
if [[ -d "\$SRC/apps/web" ]]; then
  cd "\$SRC/apps/web"
  # If PM2 runs from /opt/marvisociety-web via standalone server.js, rebuild install script
  if [[ -x /opt/marvisociety-src/scripts/deploy/whm-restart-app.sh ]]; then
    bash /opt/marvisociety-src/scripts/deploy/whm-restart-app.sh || pm2 restart marvisociety-web
  else
    pm2 restart marvisociety-web
  fi
fi

pm2 status | head -20
curl -sS -m 10 -o /dev/null -w "local_privacy=%{http_code}\\n" http://127.0.0.1:3000/privacy || true
curl -sS -m 10 -o /dev/null -w "local_callback=%{http_code}\\n" http://127.0.0.1:3000/auth/callback || true
echo "✓ WHM deploy finished"
EOF
