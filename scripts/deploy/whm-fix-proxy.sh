#!/bin/bash
# Fix nginx/Apache reverse proxy for marvisociety.com → Node on :3000
# Run as root after whm-install.sh
set -euo pipefail

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

# cPanel EA4: nginx user include
NGINX_DIR="/etc/nginx/conf.d/users/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
if [[ -d /etc/nginx/conf.d/users ]] || mkdir -p "$NGINX_DIR" 2>/dev/null; then
  log "Configuring nginx proxy → 127.0.0.1:${MARVI_PORT}"
  cat > "${NGINX_DIR}/marvi-node-proxy.conf" <<EOF
# Marvi Society Next.js
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
  if [[ -x /scripts/rebuildhttpdconf ]]; then
    /scripts/rebuildhttpdconf
  fi
  if [[ -x /usr/local/cpanel/scripts/rebuildnginx ]]; then
    /usr/local/cpanel/scripts/rebuildnginx
  fi
  systemctl restart nginx 2>/dev/null || service nginx restart 2>/dev/null || true
fi

# Apache userdata proxy (fallback)
APACHE_INC="/etc/apache2/conf.d/userdata/std/2_4/${MARVI_CPANEL_USER}/${MARVI_DOMAIN}"
mkdir -p "$APACHE_INC"
cat > "${APACHE_INC}/marvi-proxy.conf" <<EOF
<IfModule mod_proxy.c>
  ProxyPreserveHost On
  ProxyPass / http://127.0.0.1:${MARVI_PORT}/
  ProxyPassReverse / http://127.0.0.1:${MARVI_PORT}/
</IfModule>
EOF

if [[ -x /scripts/rebuildhttpdconf ]]; then
  /scripts/rebuildhttpdconf
  systemctl restart httpd 2>/dev/null || service httpd restart 2>/dev/null || true
fi

# Minimal index redirect fallback
cat > "$DOCROOT/index.html" <<EOF
<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=/"></head>
<body>Marvi Society — loading…</body></html>
EOF
chown -R "${MARVI_CPANEL_USER}:${MARVI_CPANEL_USER}" "$DOCROOT" 2>/dev/null || true

log "Local tests:"
curl -sS -o /dev/null -w "  port ${MARVI_PORT}/privacy → %{http_code}\n" "http://127.0.0.1:${MARVI_PORT}/privacy" || true
curl -sS -o /dev/null -w "  vhost /privacy → %{http_code}\n" -H "Host: ${MARVI_DOMAIN}" "http://127.0.0.1/privacy" || true

SERVER_IP=$(curl -4 -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
log ""
log "NEXT: Cloudflare DNS"
log "  A  @   → ${SERVER_IP}  (Proxy ON orange cloud)"
log "  A  www → ${SERVER_IP}"
log "  SSL/TLS → Full"
log ""
log "Then test: curl -I https://marvisociety.com/privacy"
