#!/bin/bash
# Marvi Society — full WHM setup from GitHub (web + proxy + secrets + verify)
# Run as root in WHM Terminal.
#
# Required env (paste before running):
#   export GITHUB_TOKEN='ghp_...'              # GitHub → Settings → Developer settings → PAT (repo scope)
#   export SUPABASE_SERVICE_ROLE_KEY='eyJ...'  # Supabase → Settings → API → service_role
#
# Optional:
#   export MARVI_DOMAIN=marvisociety.com
#   export MARVI_BRANCH=main
#
# Then:
#   curl -fsSL "https://raw.githubusercontent.com/ersanjt/Marvi-Society-ios-/main/scripts/deploy/whm-complete-setup.sh" -o /root/whm-complete-setup.sh
#   bash /root/whm-complete-setup.sh
#
# Or if repo already cloned:
#   bash /opt/marvisociety-src/scripts/deploy/whm-complete-setup.sh
set -euo pipefail

MARVI_DOMAIN="${MARVI_DOMAIN:-marvisociety.com}"
MARVI_REPO="${MARVI_REPO:-https://github.com/ersanjt/Marvi-Society-ios-.git}"
MARVI_BRANCH="${MARVI_BRANCH:-main}"
MARVI_SRC="${MARVI_SRC:-/opt/marvisociety-src}"
MARVI_APP_DIR="${MARVI_APP_DIR:-/opt/marvisociety-web}"
MARVI_PORT="${MARVI_PORT:-3000}"

log() { echo ""; echo "[marvi] $*"; }
die() { echo "[marvi] ✗ $*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "Run as root (WHM Terminal)."

# ── 0. Validate secrets ─────────────────────────────────────────────
[[ -n "${GITHUB_TOKEN:-}" ]] || die "Set GITHUB_TOKEN (GitHub PAT with repo access)."
[[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]] || die "Set SUPABASE_SERVICE_ROLE_KEY (Supabase Dashboard → API → service_role)."

export NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}"
export NEXT_PUBLIC_SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y}"
export NEXT_PUBLIC_SITE_URL="https://${MARVI_DOMAIN}"

# ── 1. Node.js 20 + PM2 + git ─────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
  log "Installing Node.js 20…"
  curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
  yum install -y nodejs git
fi
command -v git >/dev/null 2>&1 || yum install -y git
command -v pm2 >/dev/null 2>&1 || npm install -g pm2
log "Node $(node -v) · PM2 $(pm2 -v 2>/dev/null || echo ok)"

# ── 2. Clone / update from GitHub ───────────────────────────────────
CLONE_URL="https://${GITHUB_TOKEN}@github.com/ersanjt/Marvi-Society-ios-.git"
if [[ -d "$MARVI_SRC/.git" ]]; then
  log "Updating repository at $MARVI_SRC…"
  cd "$MARVI_SRC"
  git remote set-url origin "$CLONE_URL"
  git fetch origin "$MARVI_BRANCH"
  git checkout "$MARVI_BRANCH"
  git reset --hard "origin/$MARVI_BRANCH"
else
  log "Cloning repository…"
  rm -rf "$MARVI_SRC"
  git clone --depth 1 --branch "$MARVI_BRANCH" "$CLONE_URL" "$MARVI_SRC"
fi

# ── 3. Build standalone web bundle ──────────────────────────────────
log "Building Next.js standalone bundle…"
cd "$MARVI_SRC"
bash scripts/deploy/build-web-standalone.sh

# ── 4. Install to /opt/marvisociety-web ─────────────────────────────
export MARVI_ARCHIVE="$MARVI_SRC/apps/web/.deploy/marvisociety-web.tar.gz"
bash scripts/deploy/whm-install.sh

# ── 5. Proxy + secrets + PM2 restart ────────────────────────────────
bash scripts/deploy/whm-fix-all.sh

# ── 6. Verify ───────────────────────────────────────────────────────
log "Verification:"
PASS=0
for path in / /privacy /terms /delete-account /api/health; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" -m 20 "http://127.0.0.1:${MARVI_PORT}${path}" || echo "000")
  echo "  http://127.0.0.1:${MARVI_PORT}${path} → ${code}"
done

health=$(curl -sS -m 15 "http://127.0.0.1:${MARVI_PORT}/api/health" 2>/dev/null || echo "{}")
echo "  health body: $health"
if echo "$health" | grep -q '"status":"ok"'; then
  log "✓ Production health OK"
  PASS=1
else
  log "✗ Health not ok — check SUPABASE_SERVICE_ROLE_KEY in $MARVI_APP_DIR/apps/web/.env.production"
fi

log "Remote check (if DNS points here):"
curl -sS -o /dev/null -w "  https://${MARVI_DOMAIN}/ → %{http_code}\n" -m 20 "https://${MARVI_DOMAIN}/" 2>/dev/null || true

if [[ "$PASS" -eq 1 ]]; then
  log "✓ WHM setup complete"
else
  die "Setup finished with health errors — fix secrets and run: bash $MARVI_SRC/scripts/deploy/whm-fix-all.sh"
fi
