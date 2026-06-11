#!/bin/bash
# Build and install Marvi Society on a connected iPhone (Personal Team signing).
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="MarviSociety"
BUNDLE_ID="com.marvisociety.app"
DERIVED_DATA="$PROJECT_DIR/.build/DerivedData"

echo "→ Looking for connected iPhone…"
DEVICE_ID=$(xcodebuild -project "$PROJECT_DIR/MarviSociety.xcodeproj" -scheme "$SCHEME" -showdestinations 2>/dev/null \
  | grep "platform:iOS" | grep "arch:arm64" | grep -v Simulator | grep "name:.*iPhone" | head -1 \
  | sed -E 's/.*id:([^,}]+).*/\1/')

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null \
    | grep -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | grep connected | head -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "✗ No iPhone connected. Plug in your device and trust this Mac."
  exit 1
fi

echo "→ Device: $DEVICE_ID"
echo "→ Building for device…"

xcodebuild \
  -project "$PROJECT_DIR/MarviSociety.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "id=$DEVICE_ID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/MarviSociety.app"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "✗ Build succeeded but MarviSociety.app not found in DerivedData"
  exit 1
fi

echo "→ Installing on device…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "→ Launching…"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

echo "✓ Marvi Society installed on your iPhone"
