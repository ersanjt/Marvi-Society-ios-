#!/bin/bash
# Self-contained repair: restart Node app + configure reverse proxy for marvisociety.com
set -uo pipefail

MARVI_DOMAIN="${MARVI_DOMAIN:-marvisociety.com}"
MARVI_APP_DIR="${MARVI_APP_DIR:-/opt/marvisociety-web}"
MARVI_PORT="${MARVI_PORT:-3000}"
MARVI_CPANEL_USER="${MARVI_CPANEL_USER:-marvisociety}"

log() { echo "[marvi] $*"; }

# ── 1. Restart Node app ─────────────────────────────────────────────
if [[ ! -d "$MARVI_APP_DIR" ]]; then
  echo "Missing $MARVI_APP_DIR — run whm-install-from-git.sh first." >&2
  exit 1
fi

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

if ! curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${MARVI_PORT}/privacy" | grep -q 200; then
  log "✗ App not responding on port ${MARVI_PORT}"
  pm2 logs marvisociety-web --lines 20 --nostream || true
  exit 1
fi
log "✓ App OK on http://127.0.0.1:${MARVI_PORT}/privacy"

# ── 2. Detect cPanel user ───────────────────────────────────────────
if [[ -f /etc/userdomains ]]; then
  detected=$(awk -v d="$MARVI_DOMAIN" '$1==d {print $2; exit}' /etc/userdomains || true)
  [[ -n "$detected" ]] && MARVI_CPANEL_USER="$detected"
fi
DOCROOT="/home/${MARVI_CPANEL_USER}/public_html"
mkdir -p "$DOCROOT"

# ── 3. Clean up duplicate nginx configs from prior runs ─────────────
log "Removing old marvi nginx configs…"
rm -f /etc/nginx/conf.d/marvi-*.conf
rm -f "/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}/marvi-"*.conf
rm -f "/etc/nginx/ea-nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}/marvi-"*.conf

# Single nginx location include (cPanel EA-Nginx merges this into the domain server block)
NGINX_DIR="/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$NGINX_DIR"
cat > "${NGINX_DIR}/marvi-proxy.conf" <<EOF
location / {
    proxy_pass http://127.0.0.1:${MARVI_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_cache_bypass \$http_upgrade;
}
EOF
log "nginx → ${NGINX_DIR}/marvi-proxy.conf (single file)"

# Apache userdata proxy (backend)
for APACHE_BASE in std ssl; do
  APACHE_INC="/etc/apache2/conf.d/userdata/${APACHE_BASE}/2_4/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
  mkdir -p "$APACHE_INC"
  cat > "${APACHE_INC}/marvi-proxy.conf" <<EOF
<IfModule mod_proxy.c>
  ProxyPreserveHost On
  ProxyPass / http://127.0.0.1:${MARVI_PORT}/
  ProxyPassReverse / http://127.0.0.1:${MARVI_PORT}/
</IfModule>
EOF
done

cat > "$DOCROOT/.htaccess" <<EOF
Options -Indexes
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.*)$ http://127.0.0.1:${MARVI_PORT}/\$1 [P,L]
EOF
chown -R "${MARVI_CPANEL_USER}:${MARVI_CPANEL_USER}" "$DOCROOT" 2>/dev/null || true

# ── 4. Rebuild & restart web servers ────────────────────────────────
[[ -x /scripts/rebuildhttpdconf ]] && /scripts/rebuildhttpdconf
[[ -x /usr/local/cpanel/scripts/rebuildnginx ]] && /usr/local/cpanel/scripts/rebuildnginx

/scripts/restartsrv_httpd 2>/dev/null || systemctl restart httpd 2>/dev/null || true
/scripts/restartsrv_nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
sleep 2

# ── 5. Test ─────────────────────────────────────────────────────────
SERVER_IP=$(curl -4 -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
log "Tests:"
curl -sS -o /dev/null -w "  port ${MARVI_PORT}/privacy → %{http_code}\n" "http://127.0.0.1:${MARVI_PORT}/privacy" || true

for target in "127.0.0.1" "${SERVER_IP}"; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Host: ${MARVI_DOMAIN}" "http://${target}/privacy" 2>/dev/null || echo "000")
  log "  vhost ${target}/privacy → ${code}"
done

if ! systemctl is-active nginx >/dev/null 2>&1; then
  log "✗ nginx not running — check: nginx -t"
  nginx -t 2>&1 | tail -5 || true
else
  log "✓ nginx running"
fi

log ""
log "Cloudflare DNS: A @ and www → ${SERVER_IP}  |  SSL: Full"
pm2 status marvisociety-web
