#!/bin/bash
# Archive + export Marvi Society IPA for App Store (build 1.0.x).
set -euo pipefail

export PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_DIR="$REPO_ROOT/apps/ios"
SCHEME="MarviSociety"
ARCHIVE="$IOS_DIR/.build/MarviSociety.xcarchive"
EXPORT_DIR="$IOS_DIR/.build/export"
EXPORT_OPTS="$IOS_DIR/Config/ExportOptions.plist"

echo ""
echo "Marvi Society — iOS Release Build"
echo "================================"
echo ""

xcodebuild -version 2>/dev/null | sed -n '1p'

cd "$IOS_DIR"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$IOS_DIR/.build"

echo "→ Archive (Release, generic iOS)…"
xcodebuild \
  -project MarviSociety.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=GG773SAZP9

echo "→ Export IPA…"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  -allowProvisioningUpdates

BUILD_NUM=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$ARCHIVE/Products/Applications/MarviSociety.app/Info.plist" 2>/dev/null || echo "?")
VERSION=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$ARCHIVE/Products/Applications/MarviSociety.app/Info.plist" 2>/dev/null || echo "?")

echo ""
echo "✓ IPA: $EXPORT_DIR/MarviSociety.ipa"
echo "✓ Version $VERSION ($BUILD_NUM)"
echo ""
echo "Upload: npm run upload:ios"
echo "   or: Xcode → Organizer → Distribute App"
