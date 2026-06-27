#!/bin/bash
# Upload Marvi Society IPA to App Store Connect / TestFlight via API key.
# Requires: Xcode (altool), App Store Connect API key (.p8).
set -euo pipefail

export PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEFAULT_IPA="$REPO_ROOT/apps/ios/.build/export/MarviSociety.ipa"

API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-JT328F7C3Z}"
API_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-8b84fa76-827a-48b1-bbce-71bdce84ac52}"
API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8}"
IPA="${1:-$DEFAULT_IPA}"

if [[ ! -f "$IPA" ]]; then
  echo "✗ IPA not found: $IPA"
  echo "  Run: npm run build:ios"
  exit 1
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "✗ API key not found: $API_KEY_PATH"
  echo "  Copy AuthKey_${API_KEY_ID}.p8 to that path (chmod 600), or set:"
  echo "    APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_${API_KEY_ID}.p8"
  exit 1
fi

chmod 600 "$API_KEY_PATH" 2>/dev/null || true
mkdir -p "$(dirname "$API_KEY_PATH")"

echo "→ Uploading to App Store Connect…"
echo "   IPA:      $IPA"
echo "   Key ID:   $API_KEY_ID"
echo "   Issuer:   $API_ISSUER_ID"
echo ""

xcrun altool --upload-app \
  -f "$IPA" \
  -t ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID"

echo ""
echo "✓ Upload complete. Processing in App Store Connect usually takes 5–15 minutes."
echo "  https://appstoreconnect.apple.com → Marvi Society → TestFlight"
