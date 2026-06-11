#!/bin/bash
# Marvi Society — run on iPhone Simulator (local demo mode, no Supabase needed)
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="MarviSociety"
SIMULATOR_NAME="${1:-iPhone 17}"

echo "→ Building Marvi Society for $SIMULATOR_NAME…"
xcodebuild \
  -project "$PROJECT_DIR/MarviSociety.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -5

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MarviSociety-*/Build/Products/Debug-iphonesimulator -name "MarviSociety.app" -maxdepth 1 2>/dev/null | head -1)
if [[ -z "$APP_PATH" ]]; then
  echo "Build succeeded but could not find MarviSociety.app"
  exit 1
fi

DEVICE_ID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME (" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
if [[ -z "$DEVICE_ID" ]]; then
  echo "Simulator '$SIMULATOR_NAME' not found. Run: xcrun simctl list devices"
  exit 1
fi

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch "$DEVICE_ID" com.marvisociety.app

echo "✓ Marvi Society is running on $SIMULATOR_NAME"
