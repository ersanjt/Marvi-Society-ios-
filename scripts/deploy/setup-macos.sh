#!/bin/bash
# Marvi Society — macOS setup wizard (database + iOS + web)
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Marvi Society — Setup Wizard (macOS)             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
echo "▸ Checking tools…"

if [[ ! -d "/Applications/Xcode.app" ]]; then
  echo "  ✗ Xcode not found — install from App Store"
  exit 1
fi
echo "  ✓ Xcode"

if command -v node >/dev/null 2>&1; then
  echo "  ✓ Node.js $(node --version)"
else
  echo "  Installing Node.js via Homebrew…"
  brew install node
fi

# ── 2. Supabase ─────────────────────────────────────────────────────────────
echo ""
echo "▸ Supabase (database)"
echo ""
echo "  1. Open https://supabase.com/dashboard"
echo "  2. Create project: marvi-society (region: Frankfurt)"
echo "  3. SQL Editor → paste ALL_MIGRATIONS_COMBINED.sql → Run"
echo "  4. Authentication → Add user → copy UUID"
echo "  5. Run seed-after-deploy.sql with your UUID"
echo ""
read -r -p "Open Supabase Dashboard in browser? [Y/n] " OPEN_SB
OPEN_SB=${OPEN_SB:-Y}
if [[ "$OPEN_SB" =~ ^[Yy]$ ]]; then
  open "https://supabase.com/dashboard"
fi

read -r -p "Open combined SQL file in TextEdit? [Y/n] " OPEN_SQL
OPEN_SQL=${OPEN_SQL:-Y}
if [[ "$OPEN_SQL" =~ ^[Yy]$ ]]; then
  open -e "$REPO_ROOT/infra/supabase/ALL_MIGRATIONS_COMBINED.sql"
fi

echo ""
read -r -p "Enter Supabase Project URL (or press Enter to skip): " SB_URL
if [[ -n "$SB_URL" ]]; then
  read -r -p "Enter Supabase anon key: " SB_ANON
  read -r -p "Enter Supabase service_role key (for web): " SB_SERVICE

  # iOS
  cat > "$REPO_ROOT/apps/ios/Config/Secrets.xcconfig" <<EOF
MARVI_API_MODE = supabase
MARVI_SUPABASE_URL = $SB_URL
MARVI_SUPABASE_ANON_KEY = $SB_ANON

INFOPLIST_KEY_MARVI_SUPABASE_URL = \$(MARVI_SUPABASE_URL)
INFOPLIST_KEY_MARVI_SUPABASE_ANON_KEY = \$(MARVI_SUPABASE_ANON_KEY)
INFOPLIST_KEY_MARVI_API_MODE = \$(MARVI_API_MODE)
EOF
  echo "  ✓ iOS Secrets.xcconfig updated"

  # Web
  cat > "$REPO_ROOT/apps/web/.env.local" <<EOF
NEXT_PUBLIC_SUPABASE_URL=$SB_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SB_ANON
SUPABASE_SERVICE_ROLE_KEY=$SB_SERVICE
NEXT_PUBLIC_SITE_URL=http://localhost:3000
EOF
  echo "  ✓ Web .env.local created"
fi

# ── 3. Web ──────────────────────────────────────────────────────────────────
echo ""
echo "▸ Web app"
cd "$REPO_ROOT/apps/web"
if [[ ! -d node_modules ]]; then
  echo "  Installing npm packages…"
  npm install
fi
echo "  ✓ Dependencies ready"
echo ""
read -r -p "Start web dev server now? [y/N] " START_WEB
if [[ "$START_WEB" =~ ^[Yy]$ ]]; then
  echo "  → http://localhost:3000"
  npm run dev &
fi

# ── 4. iOS ──────────────────────────────────────────────────────────────────
echo ""
echo "▸ iOS app"
read -r -p "Open Xcode project? [Y/n] " OPEN_XCODE
OPEN_XCODE=${OPEN_XCODE:-Y}
if [[ "$OPEN_XCODE" =~ ^[Yy]$ ]]; then
  open "$REPO_ROOT/apps/ios/MarviSociety.xcodeproj"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Done! Next steps:"
echo "  • iOS: Run on real iPhone (Sign in with Apple)"
echo "  • Invite code: MARVI-IST"
echo "  • App Store: Apple Developer account required"
echo "════════════════════════════════════════════════════════════"
echo ""
