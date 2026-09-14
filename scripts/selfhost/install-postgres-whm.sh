#!/usr/bin/env bash
# Install PostgreSQL on the WHM/cPanel VPS (NOT MySQL/MariaDB).
# Run as root in WHM Terminal:
#   bash /opt/marvisociety-src/scripts/selfhost/install-postgres-whm.sh
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }

DB_NAME="${MARVI_DB_NAME:-marvi}"
DB_USER="${MARVI_DB_USER:-marvi}"
DB_PASS="${MARVI_DB_PASSWORD:-}"

if [[ -z "$DB_PASS" ]]; then
  DB_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
  GENERATED_PASS=1
else
  GENERATED_PASS=0
fi

echo "Marvi — install self-hosted PostgreSQL"
echo "Database: $DB_NAME  User: $DB_USER"
echo ""

if command -v psql >/dev/null 2>&1; then
  echo "PostgreSQL client already present: $(psql --version)"
else
  if [[ -x /usr/local/cpanel/scripts/installpostgres ]]; then
    echo "Installing via WHM installpostgres…"
    /usr/local/cpanel/scripts/installpostgres || true
  fi
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y postgresql-server postgresql postgresql-contrib || dnf install -y postgresql16-server postgresql16 postgresql16-contrib || true
  elif command -v yum >/dev/null 2>&1; then
    yum install -y postgresql-server postgresql postgresql-contrib || true
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib
  fi
fi

command -v psql >/dev/null 2>&1 || {
  echo "PostgreSQL did not install. In WHM go to: SQL Services → Postgres Config → Install." >&2
  exit 1
}

if command -v postgresql-setup >/dev/null 2>&1; then
  postgresql-setup --initdb 2>/dev/null || postgresql-setup initdb 2>/dev/null || true
fi
systemctl enable --now postgresql 2>/dev/null || systemctl enable --now postgresql-16 2>/dev/null || service postgresql start || true

run_as_postgres() {
  if id postgres >/dev/null 2>&1; then
    su - postgres -c "$1"
  else
    sudo -u postgres bash -lc "$1"
  fi
}

run_as_postgres "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER'\" | grep -q 1" \
  || run_as_postgres "psql -c \"CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' SUPERUSER CREATEDB;\""
run_as_postgres "psql -tc \"SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'\" | grep -q 1" \
  || run_as_postgres "psql -c \"CREATE DATABASE $DB_NAME OWNER $DB_USER;\""

CONF_DIR="/etc/marvi"
mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR"
cat > "$CONF_DIR/postgres.env" <<EOF
MARVI_DB_NAME=$DB_NAME
MARVI_DB_USER=$DB_USER
MARVI_DB_PASSWORD=$DB_PASS
MARVI_DATABASE_URL=postgresql://$DB_USER:$DB_PASS@127.0.0.1:5432/$DB_NAME
EOF
chmod 600 "$CONF_DIR/postgres.env"

echo ""
echo "PostgreSQL is ready on 127.0.0.1:5432"
echo "Credentials written to $CONF_DIR/postgres.env (root only)."
if [[ "$GENERATED_PASS" == "1" ]]; then
  echo "A password was generated. Keep /etc/marvi/postgres.env private."
fi
echo ""
echo "Next:"
echo "  bash scripts/selfhost/apply-schema.sh"
echo "  bash scripts/selfhost/restore-dump.sh   # after dumping Supabase"
