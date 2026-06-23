#!/bin/bash
# Marvi Society — run all local automation (no billing accounts required)
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo ""
echo "══════════════════════════════════════════"
echo "  Marvi Society — Local automation"
echo "══════════════════════════════════════════"
echo ""

echo "▶ Tip: use 'npm run sync' for full stack sync (DB + GitHub + verify)"
echo ""

echo "▶ 0/5 App Store preflight (live site + RPCs)..."
bash "$REPO_ROOT/scripts/app-store-preflight.sh" || true

echo ""
echo "▶ 1/5 Health check (Supabase API)..."
bash "$REPO_ROOT/scripts/check-health.sh"

echo ""
echo "▶ 2/5 Build web (Next.js)..."
cd "$REPO_ROOT/apps/web"
npm install --silent 2>/dev/null || npm install
npm run build

echo ""
echo "▶ 3/5 Build iOS..."
cd "$REPO_ROOT/apps/ios"
xcodebuild -project MarviSociety.xcodeproj -scheme MarviSociety \
  -destination 'generic/platform=iOS' -configuration Debug build \
  | tail -3

APP="$HOME/Library/Developer/Xcode/DerivedData/MarviSociety-"*/Build/Products/Debug-iphoneos/MarviSociety.app

echo ""
echo "▶ 4/5 Install on iPhone (if connected)..."
if xcrun devicectl list devices 2>/dev/null | grep -q connected; then
  DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | awk '/connected/{print $NF; exit}' | tr -d '()')
  if [[ -n "$DEVICE_ID" && -d $APP ]]; then
    xcrun devicectl device install app --device "$DEVICE_ID" $APP && echo "✓ Installed on device"
  else
    echo "⚠ Device found but install skipped (check APP path)"
  fi
else
  echo "⚠ No iPhone connected — plug in and run again"
fi

echo ""
echo "══════════════════════════════════════════"
echo "  Manual steps (need your login):"
echo "══════════════════════════════════════════"
echo ""
echo "  SQL:  Run infra/supabase/safe-production-update.sql"
echo "        in Supabase SQL Editor (NOT initial schema!)"
echo ""
echo "  WHM:  export SUPABASE_SERVICE_ROLE_KEY='…' && bash scripts/deploy/whm-fix-all.sh"
echo "        (Supabase Dashboard → Settings → API → service_role)"
echo ""
echo "  Apple: developer.apple.com enroll (\$99) for App Store"
echo ""
