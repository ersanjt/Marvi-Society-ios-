#!/bin/bash
# Upload AAB to Google Play (internal testing track by default).
# Requires: Google Play Console app created + service account with Release Manager role.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/scripts/release/lib.sh"

PACKAGE="com.marvisociety.app"
TRACK="${MARVI_PLAY_TRACK:-internal}"
AAB="${1:-$ROOT/apps/android/app/build/outputs/bundle/release/app-release.aab}"
SA_JSON="${GOOGLE_PLAY_SERVICE_ACCOUNT:-$ROOT/apps/android/play-service-account.json}"

if [[ ! -f "$AAB" ]]; then
  marvi_err "AAB not found. Run: npm run build:android"
  exit 1
fi

if [[ ! -f "$SA_JSON" ]]; then
  marvi_err "Google Play service account JSON not found."
  echo ""
  echo "  1. Play Console → Setup → API access → Link Cloud project"
  echo "  2. Create service account with Release Manager"
  echo "  3. Save JSON as: apps/android/play-service-account.json (gitignored)"
  echo "  4. Re-run: npm run publish:android"
  echo ""
  echo "  Or upload manually: Play Console → Testing → Internal testing → Create release"
  echo "  AAB path: $AAB"
  exit 1
fi

if ! command -v fastlane >/dev/null 2>&1; then
  marvi_info "Installing fastlane via gem (user install)..."
  gem install fastlane --user-install 2>/dev/null || true
  export PATH="$HOME/.gem/ruby/$(ruby -e 'print RUBY_VERSION[/^\d+\.\d+/]')/bin:$PATH"
fi

if ! command -v fastlane >/dev/null 2>&1; then
  marvi_err "Install fastlane: brew install fastlane"
  exit 1
fi

marvi_info "Uploading to Google Play ($TRACK track)..."
fastlane supply \
  --aab "$AAB" \
  --package_name "$PACKAGE" \
  --track "$TRACK" \
  --json_key "$SA_JSON" \
  --skip_upload_metadata \
  --skip_upload_images \
  --skip_upload_screenshots

marvi_ok "Uploaded to $TRACK track. Promote in Play Console when ready."
