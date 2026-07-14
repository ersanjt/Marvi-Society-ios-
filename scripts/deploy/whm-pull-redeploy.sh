#!/usr/bin/env bash
# Paste in WHM Terminal as root to pull latest main and restart the web app.
# Fixes live 404s for routes that exist in git (e.g. /invite).
#
# Critical: preserve .env.production, copy static/public, rewrite start.sh,
# then pm2 delete+start (not a bare restart of a broken process).
set -euo pipefail

SRC="${MARVI_SRC:-/opt/marvisociety-src}"
APP="${MARVI_APP_DIR:-/opt/marvisociety-web}"
PORT="${MARVI_PORT:-3000}"

echo "Marvi — WHM pull + rebuild"
cd "$SRC"
git fetch origin main
git reset --hard origin/main
npm ci
npm run web:build

mkdir -p "$APP"
ENV_BAK="/tmp/marvi.env.production.bak"
if [[ -f "$APP/apps/web/.env.production" ]]; then
  cp -a "$APP/apps/web/.env.production" "$ENV_BAK"
  echo "→ preserved existing .env.production"
elif [[ -f "$SRC/apps/web/.env.production" ]]; then
  cp -a "$SRC/apps/web/.env.production" "$ENV_BAK"
fi

if [[ -d "$SRC/apps/web/.next/standalone" ]]; then
  echo "→ syncing standalone → $APP"
  # Avoid --delete so we never wipe env/start mid-deploy; overwrite files instead.
  rsync -a "$SRC/apps/web/.next/standalone/" "$APP/"
  mkdir -p "$APP/apps/web/.next"
  rsync -a "$SRC/apps/web/.next/static" "$APP/apps/web/.next/"
  rsync -a "$SRC/apps/web/public" "$APP/apps/web/" 2>/dev/null || true
fi

mkdir -p "$APP/apps/web"
if [[ -f "$ENV_BAK" ]]; then
  cp -a "$ENV_BAK" "$APP/apps/web/.env.production"
  echo "→ restored .env.production"
fi

cp "$SRC/scripts/deploy/marvi-pm2-start.sh" "$APP/start.sh"
chmod +x "$APP/start.sh"

if [[ ! -f "$APP/apps/web/server.js" && ! -f "$APP/server.js" ]]; then
  echo "ERROR: server.js missing under $APP — build/standalone incomplete" >&2
  ls -la "$APP" | head -30 >&2
  exit 1
fi

echo "→ restarting PM2 on :$PORT"
pm2 delete marvisociety-web 2>/dev/null || true
cd "$APP"
PORT="$PORT" HOSTNAME=0.0.0.0 pm2 start ./start.sh --name marvisociety-web
pm2 save 2>/dev/null || true
sleep 3

pm2 status marvisociety-web || pm2 status | head -15
echo "--- last logs ---"
pm2 logs marvisociety-web --lines 25 --nostream || true

invite=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/invite" || echo 000)
privacy=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/privacy" || echo 000)
echo "invite=$invite privacy=$privacy"
echo "Done. Public check: https://marvisociety.com/invite"

if [[ "$invite" != "200" && "$privacy" != "200" ]]; then
  echo "ERROR: app still not responding on :$PORT" >&2
  exit 1
fi
