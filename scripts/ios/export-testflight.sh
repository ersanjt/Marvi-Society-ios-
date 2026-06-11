#!/bin/bash
# Archive Marvi Society for TestFlight upload (requires Apple Developer Program).
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)/apps/ios"
ARCHIVE_PATH="$PROJECT_DIR/.build/MarviSociety.xcarchive"
EXPORT_PATH="$PROJECT_DIR/.build/export"

echo "→ Archiving Release build…"
xcodebuild \
  -project "$PROJECT_DIR/MarviSociety.xcodeproj" \
  -scheme MarviSociety \
  -configuration Release \
  -derivedDataPath "$PROJECT_DIR/.build/DerivedData" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

echo "✓ Archive created: $ARCHIVE_PATH"
echo "→ Upload with Xcode Organizer or:"
echo "  xcrun altool --upload-app -f \"$EXPORT_PATH/MarviSociety.ipa\" -t ios --apiKey YOUR_KEY --apiIssuer YOUR_ISSUER"
