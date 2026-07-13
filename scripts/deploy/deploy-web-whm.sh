#!/usr/bin/env bash
# Deploy latest main → live marvisociety.com on THIS WHM box.
# Run as root in WHM Terminal:
#   cd /opt/marvisociety-src && git pull && bash scripts/deploy/deploy-web-whm.sh
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root in WHM Terminal." >&2; exit 1; }

SRC="${MARVI_SRC:-/opt/marvisociety-src}"
APP="${MARVI_APP_DIR:-/opt/marvisociety-web}"
PORT="${MARVI_PORT:-3000}"

log() { echo "[marvi-deploy] $*"; }

[[ -d "$SRC/.git" ]] || { echo "Missing $SRC — run whm-install-from-git.sh first." >&2; exit 1; }

log "Pulling origin/main…"
cd "$SRC"
git fetch origin main
git reset --hard origin/main

log "Installing deps + building web…"
cd "$SRC"
npm ci
npm run web:build

log "Refreshing runtime under $APP…"
if [[ -f "$SRC/scripts/deploy/whm-install-from-git.sh" ]]; then
  # Reuse install path without re-cloning when possible
  export MARVI_SRC="$SRC"
  export MARVI_APP_DIR="$APP"
  export MARVI_PORT="$PORT"
  export MARVI_DOMAIN="${MARVI_DOMAIN:-marvisociety.com}"
fi

# Ensure start script binds 0.0.0.0
mkdir -p "$APP"
cat > "$APP/start.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export NODE_ENV=production
export PORT="${PORT:-3000}"
export HOSTNAME="0.0.0.0"
# Prefer standalone server if present
if [[ -f ./apps/web/server.js ]]; then
  exec node apps/web/server.js
fi
if [[ -f ./server.js ]]; then
  exec node server.js
fi
echo "No server.js found" >&2
exit 1
EOF
chmod +x "$APP/start.sh"

# Copy standalone output when available
if [[ -d "$SRC/apps/web/.next/standalone" ]]; then
  rsync -a "$SRC/apps/web/.next/standalone/" "$APP/"
  mkdir -p "$APP/apps/web/.next"
  rsync -a "$SRC/apps/web/.next/static" "$APP/apps/web/.next/" 2>/dev/null || true
  rsync -a "$SRC/apps/web/public" "$APP/apps/web/" 2>/dev/null || true
fi

# Preserve production env
if [[ -f "$APP/apps/web/.env.production" ]]; then
  log "Keeping existing apps/web/.env.production"
elif [[ -f "$SRC/apps/web/.env.production" ]]; then
  mkdir -p "$APP/apps/web"
  cp "$SRC/apps/web/.env.production" "$APP/apps/web/.env.production"
fi

log "Restarting PM2…"
pm2 delete marvisociety-web 2>/dev/null || true
cd "$APP"
PORT="$PORT" HOSTNAME=0.0.0.0 pm2 start ./start.sh --name marvisociety-web
pm2 save 2>/dev/null || true

sleep 2
curl -sS -m 12 -o /dev/null -w "local_privacy=%{http_code}\n" "http://127.0.0.1:${PORT}/privacy" || true
curl -sS -m 12 -o /dev/null -w "local_callback=%{http_code}\n" "http://127.0.0.1:${PORT}/auth/callback" || true
pm2 status | head -20
log "✓ Deploy complete — https://marvisociety.com"
