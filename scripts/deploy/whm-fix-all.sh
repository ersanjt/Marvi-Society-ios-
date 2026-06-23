#!/bin/bash
# Self-contained repair: restart Node app + Apache proxy (no nginx location override)
set -uo pipefail

MARVI_DOMAIN="${MARVI_DOMAIN:-marvisociety.com}"
MARVI_APP_DIR="${MARVI_APP_DIR:-/opt/marvisociety-web}"
MARVI_PORT="${MARVI_PORT:-3000}"
MARVI_CPANEL_USER="${MARVI_CPANEL_USER:-marvisociety}"

log() { echo "[marvi] $*"; }

# ── 1. Restart Node app ─────────────────────────────────────────────
[[ -d "$MARVI_APP_DIR" ]] || { echo "Missing $MARVI_APP_DIR" >&2; exit 1; }

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

log "Restarting PM2…"
pm2 delete marvisociety-web 2>/dev/null || true
cd "$MARVI_APP_DIR"
PORT="$MARVI_PORT" HOSTNAME=0.0.0.0 pm2 start ./start.sh --name marvisociety-web
pm2 save && sleep 2

curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${MARVI_PORT}/privacy" | grep -q 200 \
  || { log "✗ App down on :${MARVI_PORT}"; pm2 logs marvisociety-web --lines 15 --nostream; exit 1; }
log "✓ App OK on :${MARVI_PORT}"

# ── 2. cPanel user ──────────────────────────────────────────────────
[[ -f /etc/userdomains ]] && MARVI_CPANEL_USER=$(awk -v d="$MARVI_DOMAIN" '$1==d {print $2; exit}' /etc/userdomains || true)
MARVI_CPANEL_USER="${MARVI_CPANEL_USER:-marvisociety}"
DOCROOT="/home/${MARVI_CPANEL_USER}/public_html"
mkdir -p "$DOCROOT"

# ── 3. Remove ALL marvi nginx overrides (they cause duplicate location /) ──
log "Removing marvi nginx overrides (cPanel already has location /)…"
rm -f /etc/nginx/conf.d/marvi-*.conf
rm -f "/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}/marvi-"*.conf
rm -f "/etc/nginx/ea-nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}/marvi-"*.conf

# ── 4. Apache proxy (nginx → apache → node) ─────────────────────────
PROXY_CONF='<IfModule mod_proxy.c>
  ProxyPreserveHost On
  ProxyPass / http://127.0.0.1:'"${MARVI_PORT}"'/
  ProxyPassReverse / http://127.0.0.1:'"${MARVI_PORT}"'/
</IfModule>'

for APACHE_BASE in std ssl; do
  APACHE_INC="/etc/apache2/conf.d/userdata/${APACHE_BASE}/2_4/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
  mkdir -p "$APACHE_INC"
  printf '%s\n' "$PROXY_CONF" > "${APACHE_INC}/marvi-proxy.conf"
  log "Apache proxy → ${APACHE_INC}/marvi-proxy.conf"
done

echo "Options -Indexes" > "$DOCROOT/.htaccess"
chown -R "${MARVI_CPANEL_USER}:${MARVI_CPANEL_USER}" "$DOCROOT" 2>/dev/null || true

# ── 5. Rebuild & restart ────────────────────────────────────────────
[[ -x /scripts/rebuildhttpdconf ]] && /scripts/rebuildhttpdconf
[[ -x /usr/local/cpanel/scripts/rebuildnginx ]] && /usr/local/cpanel/scripts/rebuildnginx
/scripts/restartsrv_nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
/scripts/restartsrv_httpd 2>/dev/null || systemctl restart httpd 2>/dev/null || true
sleep 2

# ── 6. Test ─────────────────────────────────────────────────────────
SERVER_IP=$(curl -4 -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
log "Tests:"
curl -sS -o /dev/null -w "  :${MARVI_PORT}/privacy → %{http_code}\n" "http://127.0.0.1:${MARVI_PORT}/privacy" || true

if systemctl is-active nginx >/dev/null 2>&1; then
  log "✓ nginx running"
  for target in "127.0.0.1" "${SERVER_IP}"; do
    code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Host: ${MARVI_DOMAIN}" "http://${target}/privacy" 2>/dev/null || echo "000")
    log "  vhost ${target}/privacy → ${code}"
  done
else
  log "✗ nginx still down — run: nginx -t"
  nginx -t 2>&1 | tail -3 || true
fi

log ""
log "Cloudflare: A @ and www → ${SERVER_IP}  |  SSL: Full"
pm2 status marvisociety-web
