#!/usr/bin/env bash
# Install PostgreSQL 17 (same major as Supabase production) on the WHM/cPanel VPS.
# Not MySQL/MariaDB — Marvi relies on RLS, RPC functions, arrays and security_invoker views (PG 15+).
#
# Run as root in WHM Terminal:
#   bash /opt/marvisociety-src/scripts/selfhost/install-postgres-whm.sh
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }

PG_MAJOR="${MARVI_PG_MAJOR:-17}"
MIN_SERVER_VERSION=150000
DB_NAME="${MARVI_DB_NAME:-marvi}"
DB_USER="${MARVI_DB_USER:-marvi}"
DB_PASS="${MARVI_DB_PASSWORD:-}"
GENERATED_PASS=0
if [[ -z "$DB_PASS" ]]; then
  DB_PASS="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)"
  GENERATED_PASS=1
fi

log() { echo "[marvi-pg] $*"; }

run_pg() { su - postgres -c "$1"; }

server_version() {
  run_pg "psql -XtAc 'SHOW server_version_num'" 2>/dev/null | tr -d '[:space:]'
}

log "PostgreSQL $PG_MAJOR · database=$DB_NAME user=$DB_USER"

if id postgres >/dev/null 2>&1 && [[ -n "$(server_version)" ]]; then
  current="$(server_version)"
  if (( current < MIN_SERVER_VERSION )); then
    echo "A PostgreSQL server ($current) is already running but Marvi needs 15+." >&2
    echo "Upgrade it (or stop it) before continuing; this script will not replace a live cluster." >&2
    exit 1
  fi
  log "Existing PostgreSQL server $current is new enough — reusing it."
else
  if command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    PKG=$(command -v dnf || command -v yum)
    EL="$(rpm -E %rhel)"
    ARCH="$(uname -m)"
    log "Installing PGDG repo for EL$EL/$ARCH"
    $PKG install -y "https://download.postgresql.org/pub/repos/yum/reporpms/EL-${EL}-${ARCH}/pgdg-redhat-repo-latest.noarch.rpm"
    # Distro module ships an older major and shadows PGDG packages.
    $PKG -qy module disable postgresql 2>/dev/null || true
    $PKG install -y "postgresql${PG_MAJOR}-server" "postgresql${PG_MAJOR}" "postgresql${PG_MAJOR}-contrib"
    if [[ ! -f "/var/lib/pgsql/${PG_MAJOR}/data/PG_VERSION" ]]; then
      "/usr/pgsql-${PG_MAJOR}/bin/postgresql-${PG_MAJOR}-setup" initdb
    fi
    SERVICE="postgresql-${PG_MAJOR}"
    HBA="/var/lib/pgsql/${PG_MAJOR}/data/pg_hba.conf"
    for bin in psql pg_dump pg_restore; do
      ln -sf "/usr/pgsql-${PG_MAJOR}/bin/$bin" "/usr/local/bin/$bin"
    done
  elif command -v apt-get >/dev/null 2>&1; then
    log "Installing PGDG apt repo"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates postgresql-common
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y "postgresql-${PG_MAJOR}" "postgresql-contrib-${PG_MAJOR}" 2>/dev/null \
      || DEBIAN_FRONTEND=noninteractive apt-get install -y "postgresql-${PG_MAJOR}"
    SERVICE="postgresql"
    HBA="/etc/postgresql/${PG_MAJOR}/main/pg_hba.conf"
  else
    echo "Unsupported OS: need dnf/yum (AlmaLinux/Rocky/CentOS) or apt (Ubuntu/Debian)." >&2
    exit 1
  fi

  # RHEL defaults TCP localhost to ident, which rejects the app's password login.
  if [[ -f "$HBA" ]]; then
    sed -i -E 's/^(host\s+all\s+all\s+(127\.0\.0\.1\/32|::1\/128)\s+)(ident|md5|trust)\s*$/\1scram-sha-256/' "$HBA"
  fi
  systemctl enable "$SERVICE"
  systemctl restart "$SERVICE"
  sleep 2
fi

current="$(server_version)"
[[ -n "$current" ]] || { echo "PostgreSQL did not start — check: journalctl -u postgresql*" >&2; exit 1; }
(( current >= MIN_SERVER_VERSION )) || { echo "PostgreSQL $current is too old (need 15+)." >&2; exit 1; }
log "Server version $current"

# Superuser is required for session_replication_role during restore and for role/extension setup.
run_pg "psql -X -v ON_ERROR_STOP=1 -v u='$DB_USER' -v p='$DB_PASS' -v d='$DB_NAME'" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN SUPERUSER PASSWORD %L', :'u', :'p')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'u') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'u', :'p') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'d', :'u')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'d') \gexec
SQL

CONF_DIR="/etc/marvi"
mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR"
umask 077
cat > "$CONF_DIR/postgres.env" <<EOF
MARVI_DB_NAME=$DB_NAME
MARVI_DB_USER=$DB_USER
MARVI_DB_PASSWORD=$DB_PASS
MARVI_DATABASE_URL=postgresql://$DB_USER:$DB_PASS@127.0.0.1:5432/$DB_NAME
EOF
chmod 600 "$CONF_DIR/postgres.env"

# Prove the app-style login works over TCP (catches pg_hba ident issues).
PGPASSWORD="$DB_PASS" psql -X -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT 'login ok'" \
  || { echo "Password login over 127.0.0.1 failed — check $HBA" >&2; exit 1; }

echo ""
log "PostgreSQL ready on 127.0.0.1:5432 (not exposed publicly)."
log "Credentials: $CONF_DIR/postgres.env (root only)$( [[ $GENERATED_PASS == 1 ]] && echo ', password generated')"
echo ""
echo "Next:"
echo "  bash scripts/selfhost/apply-schema.sh"
echo "  bash scripts/selfhost/restore-dump.sh <data-dump.sql>"
