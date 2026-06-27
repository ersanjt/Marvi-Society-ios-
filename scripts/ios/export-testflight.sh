#!/bin/bash
# Archive + export IPA for App Store Connect / TestFlight.
# Requires: Apple Developer Program (Team GG773SAZP9), Xcode signed in, Secrets.xcconfig.
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS="$ROOT/apps/ios"
ARCHIVE="$IOS/.build/MarviSociety.xcarchive"
EXPORT="$IOS/.build/export"
EXPORT_OPTS="$IOS/Config/ExportOptions.plist"
TEAM_ID="GG773SAZP9"

if [[ ! -f "$IOS/Config/Secrets.xcconfig" ]]; then
  echo "✗ Missing $IOS/Config/Secrets.xcconfig"
  echo "  cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig"
  exit 1
fi

echo "→ Team: $TEAM_ID"
echo "→ Archiving Release build…"
xcodebuild \
  -project "$IOS/MarviSociety.xcodeproj" \
  -scheme MarviSociety \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$IOS/.build/DerivedData" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive

echo "→ Exporting App Store IPA…"
rm -rf "$EXPORT"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  -allowProvisioningUpdates

IPA="$(find "$EXPORT" -maxdepth 1 -name '*.ipa' | head -1)"
if [[ -n "$IPA" ]]; then
  echo "✓ IPA ready: $IPA"
  echo ""
  echo "Upload: npm run upload:ios"
  echo "   or: bash scripts/ios/upload-testflight.sh \"$IPA\""
else
  echo "✓ Archive: $ARCHIVE (open in Organizer to upload)"
fi
