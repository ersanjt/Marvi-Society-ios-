#!/bin/bash
# Install Marvi Society Next.js app on AlmaLinux + cPanel/WHM.
# Run as root in WHM Terminal.
#
# Usage:
#   export MARVI_DOMAIN=marvisociety.com
#   export MARVI_CPANEL_USER=marvisociety   # optional — auto-detected if account exists
#   export MARVI_ARCHIVE=/root/marvisociety-web.tar.gz
#   bash whm-install.sh
set -euo pipefail

MARVI_DOMAIN="${MARVI_DOMAIN:-marvisociety.com}"
MARVI_ARCHIVE="${MARVI_ARCHIVE:-/root/marvisociety-web.tar.gz}"
MARVI_APP_DIR="${MARVI_APP_DIR:-/opt/marvisociety-web}"
MARVI_PORT="${MARVI_PORT:-3000}"

log() { echo "[marvi] $*"; }

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (WHM Terminal)." >&2
  exit 1
fi

if [[ ! -f "$MARVI_ARCHIVE" ]]; then
  echo "Missing archive: $MARVI_ARCHIVE" >&2
  echo "Upload marvisociety-web.tar.gz to /root/ first." >&2
  exit 1
fi

# Node.js 20+
if ! command -v node >/dev/null 2>&1 || [[ "$(node -p 'process.versions.node.split(\".\")[0]')" -lt 18 ]]; then
  log "Installing Node.js 20…"
  if command -v dnf >/dev/null 2>&1; then
    dnf module reset -y nodejs 2>/dev/null || true
    dnf module enable -y nodejs:20 2>/dev/null || true
    dnf install -y nodejs npm
  elif command -v yum >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    yum install -y nodejs
  else
    echo "Install Node.js 20+ manually." >&2
    exit 1
  fi
fi
log "Node $(node -v)"

# PM2 for process management
if ! command -v pm2 >/dev/null 2>&1; then
  log "Installing PM2…"
  npm install -g pm2
fi

log "Extracting $MARVI_ARCHIVE → $MARVI_APP_DIR"
rm -rf "$MARVI_APP_DIR"
mkdir -p "$MARVI_APP_DIR"
tar -xzf "$MARVI_ARCHIVE" -C "$MARVI_APP_DIR"

cd "$MARVI_APP_DIR"
chmod +x start.sh

log "Starting app on port $MARVI_PORT…"
PORT="$MARVI_PORT" pm2 delete marvisociety-web 2>/dev/null || true
PORT="$MARVI_PORT" pm2 start ./start.sh --name marvisociety-web
pm2 save
pm2 startup systemd -u root --hp /root 2>/dev/null || true

# Detect cPanel user for domain
if [[ -z "${MARVI_CPANEL_USER:-}" ]] && [[ -f /etc/userdomains ]]; then
  MARVI_CPANEL_USER=$(awk -v d="$MARVI_DOMAIN" '$1==d {print $2; exit}' /etc/userdomains || true)
fi
MARVI_CPANEL_USER="${MARVI_CPANEL_USER:-marvisociety}"

DOCROOT="/home/${MARVI_CPANEL_USER}/public_html"
if [[ ! -d "/home/${MARVI_CPANEL_USER}" ]]; then
  log "Creating cPanel account ${MARVI_CPANEL_USER}…"
  EMAIL="${MARVI_ADMIN_EMAIL:-admin@${MARVI_DOMAIN}}"
  PASS="${MARVI_CPANEL_PASS:-$(openssl rand -base64 16)}"
  whmapi1 createacct username="$MARVI_CPANEL_USER" domain="$MARVI_DOMAIN" password="$PASS" contactemail="$EMAIL" plan=default 2>/dev/null || true
  log "cPanel password (save it): $PASS"
fi

mkdir -p "$DOCROOT"

# Apache reverse proxy via .htaccess (cPanel)
cat > "$DOCROOT/.htaccess" <<EOF
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.*)$ http://127.0.0.1:${MARVI_PORT}/\$1 [P,L]
EOF

# Enable proxy modules if Apache
if command -v httpd >/dev/null 2>&1; then
  grep -q 'proxy_module' /etc/apache2/conf.modules.d/00-proxy.conf 2>/dev/null || true
fi

chown -R "${MARVI_CPANEL_USER}:${MARVI_CPANEL_USER}" "$DOCROOT" 2>/dev/null || true

# AutoSSL / Let's Encrypt
if command -v /usr/local/cpanel/bin/autossl_check >/dev/null 2>&1; then
  log "Requesting AutoSSL for $MARVI_DOMAIN…"
  /usr/local/cpanel/bin/autossl_check --user "$MARVI_CPANEL_USER" 2>/dev/null || true
fi

# Restart Apache
systemctl restart httpd 2>/dev/null || systemctl restart apache2 2>/dev/null || service httpd restart 2>/dev/null || true

log "Done."
log "App:  http://127.0.0.1:${MARVI_PORT}"
log "Site: https://${MARVI_DOMAIN}"
log ""
log "Cloudflare DNS: set A record @ → $(curl -sS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
log "Cloudflare SSL mode: Full (strict) after AutoSSL completes"
log ""
log "Test: curl -I http://127.0.0.1:${MARVI_PORT}/privacy"
pm2 status marvisociety-web
