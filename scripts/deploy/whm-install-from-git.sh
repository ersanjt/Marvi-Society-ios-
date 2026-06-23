#!/bin/bash
# Build + install Marvi Society web directly on WHM (no local tarball).
# Run as root in WHM Terminal.
#
#   export GITHUB_TOKEN=ghp_xxx   # required — private repo
#   export MARVI_DOMAIN=marvisociety.com
#   bash whm-install-from-git.sh
set -euo pipefail

MARVI_DOMAIN="${MARVI_DOMAIN:-marvisociety.com}"
MARVI_REPO="${MARVI_REPO:-https://github.com/ersanjt/Marvi-Society-ios-.git}"
MARVI_BRANCH="${MARVI_BRANCH:-main}"
MARVI_SRC="${MARVI_SRC:-/opt/marvisociety-src}"
MARVI_PORT="${MARVI_PORT:-3000}"

log() { echo "[marvi] $*"; }

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }

# Node 20+
if ! command -v node >/dev/null 2>&1; then
  log "Installing Node.js 20…"
  curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
  yum install -y nodejs git
fi
command -v pm2 >/dev/null 2>&1 || npm install -g pm2

CLONE_URL="$MARVI_REPO"
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  CLONE_URL="https://${GITHUB_TOKEN}@github.com/ersanjt/Marvi-Society-ios-.git"
fi

log "Cloning repository…"
rm -rf "$MARVI_SRC"
git clone --depth 1 --branch "$MARVI_BRANCH" "$CLONE_URL" "$MARVI_SRC"

export NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}"
export NEXT_PUBLIC_SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y}"
export NEXT_PUBLIC_SITE_URL="https://${MARVI_DOMAIN}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

log "Building standalone bundle…"
cd "$MARVI_SRC"
bash scripts/deploy/build-web-standalone.sh

export MARVI_ARCHIVE="$MARVI_SRC/apps/web/.deploy/marvisociety-web.tar.gz"
bash scripts/deploy/whm-install.sh
