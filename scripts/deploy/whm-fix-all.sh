#!/bin/bash
# Self-contained repair: restart Node app + configure reverse proxy for marvisociety.com
# Single-file — safe to curl directly to /root/whm-fix-all.sh
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

if curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:${MARVI_PORT}/privacy" | grep -q 200; then
  log "✓ App OK on http://127.0.0.1:${MARVI_PORT}/privacy"
else
  log "✗ App not responding — logs:"
  pm2 logs marvisociety-web --lines 20 --nostream || true
  exit 1
fi

# ── 2. Configure nginx/Apache proxy ─────────────────────────────────
if [[ -f /etc/userdomains ]]; then
  detected=$(awk -v d="$MARVI_DOMAIN" '$1==d {print $2; exit}' /etc/userdomains || true)
  [[ -n "$detected" ]] && MARVI_CPANEL_USER="$detected"
fi

DOCROOT="/home/${MARVI_CPANEL_USER}/public_html"
mkdir -p "$DOCROOT"

NGINX_PROXY=$(cat <<EOF
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
)

CPANEL_NGINX="/var/cpanel/userdata/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$CPANEL_NGINX"
log "nginx include → ${CPANEL_NGINX}/nginx.conf.include"
printf '%s\n' "$NGINX_PROXY" > "${CPANEL_NGINX}/nginx.conf.include"

NGINX_DIR="/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$NGINX_DIR" 2>/dev/null && printf '%s\n' "$NGINX_PROXY" > "${NGINX_DIR}/marvi-node-proxy.conf" || true

APACHE_INC="/etc/apache2/conf.d/userdata/std/2_4/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$APACHE_INC"
cat > "${APACHE_INC}/marvi-proxy.conf" <<EOF
<IfModule mod_proxy.c>
  ProxyPreserveHost On
  ProxyPass / http://127.0.0.1:${MARVI_PORT}/
  ProxyPassReverse / http://127.0.0.1:${MARVI_PORT}/
</IfModule>
EOF

APACHE_SSL="/etc/apache2/conf.d/userdata/ssl/2_4/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$APACHE_SSL"
cp "${APACHE_INC}/marvi-proxy.conf" "${APACHE_SSL}/marvi-proxy.conf"

cat > "$DOCROOT/.htaccess" <<EOF
Options -Indexes
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.*)$ http://127.0.0.1:${MARVI_PORT}/\$1 [P,L]
EOF
chown -R "${MARVI_CPANEL_USER}:${MARVI_CPANEL_USER}" "$DOCROOT" 2>/dev/null || true

[[ -x /scripts/rebuildhttpdconf ]] && /scripts/rebuildhttpdconf
[[ -x /usr/local/cpanel/scripts/rebuildnginx ]] && /usr/local/cpanel/scripts/rebuildnginx
systemctl restart httpd 2>/dev/null || service httpd restart 2>/dev/null || true
systemctl restart nginx 2>/dev/null || service nginx restart 2>/dev/null || true

# ── 3. Test ─────────────────────────────────────────────────────────
log "Tests:"
curl -sS -o /dev/null -w "  port ${MARVI_PORT}/privacy → %{http_code}\n" "http://127.0.0.1:${MARVI_PORT}/privacy" || true
curl -sS -o /dev/null -w "  vhost /privacy → %{http_code}\n" -H "Host: ${MARVI_DOMAIN}" "http://127.0.0.1/privacy" || true

SERVER_IP=$(curl -4 -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
log ""
log "Done. Cloudflare DNS: A @ and www → ${SERVER_IP}  |  SSL: Full"
pm2 status marvisociety-web
