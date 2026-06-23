#!/bin/bash
# Restart Marvi Society Node app and verify port 3000.
# Run as root on WHM server.
set -euo pipefail

MARVI_APP_DIR="${MARVI_APP_DIR:-/opt/marvisociety-web}"
MARVI_PORT="${MARVI_PORT:-3000}"

log() { echo "[marvi-app] $*"; }

if [[ ! -d "$MARVI_APP_DIR" ]]; then
  echo "Missing $MARVI_APP_DIR — run whm-install-from-git.sh first." >&2
  exit 1
fi

# HOSTNAME on Linux is often the machine name; Next.js binds to it instead of 0.0.0.0
cat > "$MARVI_APP_DIR/start.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export NODE_ENV=production
export PORT="${PORT:-3000}"
export HOSTNAME="0.0.0.0"
exec node apps/web/server.js
EOF
chmod +x "$MARVI_APP_DIR/start.sh"

log "Restarting PM2 on port ${MARVI_PORT}…"
pm2 delete marvisociety-web 2>/dev/null || true
cd "$MARVI_APP_DIR"
PORT="$MARVI_PORT" HOSTNAME=0.0.0.0 pm2 start ./start.sh --name marvisociety-web
pm2 save

sleep 2
if curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${MARVI_PORT}/privacy" | grep -q 200; then
  log "✓ App responding on http://127.0.0.1:${MARVI_PORT}/privacy"
else
  log "✗ App not responding — PM2 logs:"
  pm2 logs marvisociety-web --lines 30 --nostream || true
  ss -tlnp | grep ":${MARVI_PORT}" || netstat -tlnp | grep ":${MARVI_PORT}" || true
  exit 1
fi

pm2 status marvisociety-web
