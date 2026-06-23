#!/bin/bash
# Build and install Marvi Society on a connected iPhone (Personal Team signing).
# Usage:
#   ./install-device.sh              # first connected iPhone
#   ./install-device.sh Turgut       # match device name
#   ./install-device.sh 00008130-... # explicit device id
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="MarviSociety"
BUNDLE_ID="com.marvisociety.app"
DERIVED_DATA="$PROJECT_DIR/.build/DerivedData"
TARGET="${1:-}"

pick_device_id() {
  local query="$1"
  if [[ -n "$query" ]]; then
    xcodebuild -project "$PROJECT_DIR/MarviSociety.xcodeproj" -scheme "$SCHEME" -showdestinations 2>/dev/null \
      | grep "platform:iOS" | grep "arch:arm64" | grep -v Simulator \
      | grep -i "$query" \
      | sed -E 's/.*id:([^,}]+).*/\1/' | head -1
  else
    xcodebuild -project "$PROJECT_DIR/MarviSociety.xcodeproj" -scheme "$SCHEME" -showdestinations 2>/dev/null \
      | grep "platform:iOS" | grep "arch:arm64" | grep -v Simulator | grep "name:.*iPhone\|name:Turgut\|name:ersan" \
      | grep -v "error:" | head -1 \
      | sed -E 's/.*id:([^,}]+).*/\1/'
  fi
}

echo "→ Looking for connected iPhone…"
DEVICE_ID="$(pick_device_id "$TARGET")"

if [[ -z "$DEVICE_ID" ]]; then
  echo "✗ No usable iPhone found."
  echo ""
  echo "Available destinations:"
  xcodebuild -project "$PROJECT_DIR/MarviSociety.xcodeproj" -scheme "$SCHEME" -showdestinations 2>/dev/null \
    | grep "platform:iOS" | grep -v Simulator || true
  echo ""
  echo "If a device shows 'unpaired', open Xcode → Window → Devices and Simulators,"
  echo "select the phone, click Pair, and accept the prompt on the device."
  exit 1
fi

DEVICE_NAME=$(xcodebuild -project "$PROJECT_DIR/MarviSociety.xcodeproj" -scheme "$SCHEME" -showdestinations 2>/dev/null \
  | grep "id:$DEVICE_ID" | sed -E 's/.*name:([^,}]+).*/\1/' | head -1)

echo "→ Device: ${DEVICE_NAME:-$DEVICE_ID} ($DEVICE_ID)"
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
if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ Build succeeded but MarviSociety.app not found in DerivedData"
  exit 1
fi

echo "→ Installing on device…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "→ Launching…"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

echo "✓ Marvi Society installed on ${DEVICE_NAME:-your iPhone}"
