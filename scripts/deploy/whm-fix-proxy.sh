#!/bin/bash
# Fix nginx/Apache reverse proxy for marvisociety.com → Node on :3000
# Run as root after whm-restart-app.sh
set -uo pipefail

MARVI_DOMAIN="${MARVI_DOMAIN:-marvisociety.com}"
MARVI_PORT="${MARVI_PORT:-3000}"
MARVI_CPANEL_USER="${MARVI_CPANEL_USER:-marvisociety}"

log() { echo "[marvi-fix] $*"; }

if [[ -f /etc/userdomains ]]; then
  detected=$(awk -v d="$MARVI_DOMAIN" '$1==d {print $2; exit}' /etc/userdomains || true)
  [[ -n "$detected" ]] && MARVI_CPANEL_USER="$detected"
fi

DOCROOT="/home/${MARVI_CPANEL_USER}/public_html"
mkdir -p "$DOCROOT"

# Disable directory listing — was showing "Index of /"
if [[ -f "$DOCROOT/.htaccess" ]]; then
  grep -q 'Options -Indexes' "$DOCROOT/.htaccess" || sed -i '1i Options -Indexes' "$DOCROOT/.htaccess" 2>/dev/null || true
else
  echo "Options -Indexes" > "$DOCROOT/.htaccess"
fi

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

# cPanel userdata nginx include (primary path on EA4)
CPANEL_NGINX="/var/cpanel/userdata/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$CPANEL_NGINX"
log "cPanel nginx include → ${CPANEL_NGINX}/nginx.conf.include"
printf '%s\n' "$NGINX_PROXY" > "${CPANEL_NGINX}/nginx.conf.include"

# Legacy EA4 path
NGINX_CANDIDATES=(
  "/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
  "/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}"
)
for dir in "${NGINX_CANDIDATES[@]}"; do
  if mkdir -p "$dir" 2>/dev/null; then
    log "nginx conf.d → ${dir}/marvi-node-proxy.conf"
    printf '%s\n' "$NGINX_PROXY" > "${dir}/marvi-node-proxy.conf"
  fi
done

# Apache userdata proxy (cPanel)
APACHE_INC="/etc/apache2/conf.d/userdata/std/2_4/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$APACHE_INC"
cat > "${APACHE_INC}/marvi-proxy.conf" <<EOF
<IfModule mod_proxy.c>
  ProxyPreserveHost On
  ProxyPass / http://127.0.0.1:${MARVI_PORT}/
  ProxyPassReverse / http://127.0.0.1:${MARVI_PORT}/
</IfModule>
EOF
log "Apache userdata → ${APACHE_INC}/marvi-proxy.conf"

# SSL variant
APACHE_SSL="/etc/apache2/conf.d/userdata/ssl/2_4/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$APACHE_SSL"
cp "${APACHE_INC}/marvi-proxy.conf" "${APACHE_SSL}/marvi-proxy.conf"

# .htaccess fallback (Apache backend)
cat > "$DOCROOT/.htaccess" <<EOF
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.*)$ http://127.0.0.1:${MARVI_PORT}/\$1 [P,L]
EOF
chown -R "${MARVI_CPANEL_USER}:${MARVI_CPANEL_USER}" "$DOCROOT" 2>/dev/null || true

if [[ -x /scripts/rebuildhttpdconf ]]; then
  log "Rebuilding Apache config…"
  /scripts/rebuildhttpdconf
fi
if [[ -x /usr/local/cpanel/scripts/rebuildnginx ]]; then
  log "Rebuilding nginx config…"
  /usr/local/cpanel/scripts/rebuildnginx
fi

systemctl restart httpd 2>/dev/null || service httpd restart 2>/dev/null || true
systemctl restart nginx 2>/dev/null || service nginx restart 2>/dev/null || true

log "Local tests:"
curl -sS -o /dev/null -w "  port ${MARVI_PORT}/privacy → %{http_code}\n" "http://127.0.0.1:${MARVI_PORT}/privacy" || echo "  port ${MARVI_PORT} → FAILED"
curl -sS -o /dev/null -w "  vhost /privacy → %{http_code}\n" -H "Host: ${MARVI_DOMAIN}" "http://127.0.0.1/privacy" || echo "  vhost → FAILED"

SERVER_IP=$(curl -4 -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
log ""
log "Cloudflare DNS: A @ and www → ${SERVER_IP}  |  SSL: Full"
