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

NGINX_PROXY='location / {
    proxy_pass http://127.0.0.1:'"${MARVI_PORT}"';
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
}'

# EA-Nginx per-domain include (directory, NOT userdata file path)
for NGINX_DIR in \
  "/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}" \
  "/etc/nginx/ea-nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"; do
  if mkdir -p "$NGINX_DIR" 2>/dev/null; then
    log "nginx → ${NGINX_DIR}/marvi-proxy.conf"
    printf '%s\n' "$NGINX_PROXY" > "${NGINX_DIR}/marvi-proxy.conf"
  fi
done

# Global fallback include
if [[ -d /etc/nginx/conf.d ]]; then
  cat > "/etc/nginx/conf.d/marvi-${MARVI_DOMAIN}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${MARVI_DOMAIN} www.${MARVI_DOMAIN};
    ${NGINX_PROXY}
}
EOF
  log "nginx global → /etc/nginx/conf.d/marvi-${MARVI_DOMAIN}.conf"
fi

# Apache userdata proxy (backend behind nginx on some setups)
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
log "Apache userdata proxy configured"

cat > "$DOCROOT/.htaccess" <<EOF
Options -Indexes
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.*)$ http://127.0.0.1:${MARVI_PORT}/\$1 [P,L]
EOF
chown -R "${MARVI_CPANEL_USER}:${MARVI_CPANEL_USER}" "$DOCROOT" 2>/dev/null || true

# ── 3. Rebuild & start web servers ──────────────────────────────────
[[ -x /scripts/rebuildhttpdconf ]] && /scripts/rebuildhttpdconf
[[ -x /usr/local/cpanel/scripts/rebuildnginx ]] && /usr/local/cpanel/scripts/rebuildnginx

systemctl start httpd 2>/dev/null || service httpd start 2>/dev/null || true
systemctl start nginx 2>/dev/null || service nginx start 2>/dev/null || true
/scripts/restartsrv_httpd 2>/dev/null || true
/scripts/restartsrv_nginx 2>/dev/null || true

sleep 2

# ── 4. Test ─────────────────────────────────────────────────────────
SERVER_IP=$(curl -4 -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
log "Tests:"
curl -sS -o /dev/null -w "  port ${MARVI_PORT}/privacy → %{http_code}\n" "http://127.0.0.1:${MARVI_PORT}/privacy" || true

for target in "127.0.0.1" "${SERVER_IP}"; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Host: ${MARVI_DOMAIN}" "http://${target}/privacy" 2>/dev/null || echo "000")
  log "  vhost ${target}/privacy → ${code}"
done

log ""
log "Done. Cloudflare DNS: A @ and www → ${SERVER_IP}  |  SSL: Full"
pm2 status marvisociety-web
