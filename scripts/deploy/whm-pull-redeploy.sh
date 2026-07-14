#!/usr/bin/env bash
# Paste in WHM Terminal as root to pull latest main and restart the web app.
# Fixes live 404s for routes that exist in git (e.g. /invite).
set -euo pipefail

SRC="${MARVI_SRC:-/opt/marvisociety-src}"
APP="${MARVI_APP_DIR:-/opt/marvisociety-web}"

echo "Marvi — WHM pull + rebuild"
cd "$SRC"
git fetch origin main
git reset --hard origin/main
npm ci
npm run web:build

if [[ -d "$APP" ]]; then
  rsync -a --delete "$SRC/apps/web/.next/standalone/" "$APP/" || true
  mkdir -p "$APP/apps/web"
  if [[ -f "$SRC/apps/web/.env.production" && ! -f "$APP/apps/web/.env.production" ]]; then
    cp "$SRC/apps/web/.env.production" "$APP/apps/web/.env.production"
  fi
fi

if [[ -x "$SRC/scripts/deploy/whm-restart-app.sh" ]]; then
  bash "$SRC/scripts/deploy/whm-restart-app.sh"
else
  pm2 restart marvisociety-web
fi

pm2 status | head -15
curl -sS -m 10 -o /dev/null -w "invite=%{http_code}\n" http://127.0.0.1:3000/invite || true
curl -sS -m 10 -o /dev/null -w "privacy=%{http_code}\n" http://127.0.0.1:3000/privacy || true
echo "Done. Public check: https://marvisociety.com/invite"
