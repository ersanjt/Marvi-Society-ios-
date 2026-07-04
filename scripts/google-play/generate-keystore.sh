#!/bin/bash
# Create upload keystore for Google Play (run once, store passwords in a password manager).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/apps/android"
KEYSTORE="$ANDROID/marvi-release.jks"

if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore already exists: $KEYSTORE"
  exit 0
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "Install JDK (Android Studio includes keytool)."
  exit 1
fi

echo "Creating release keystore for com.marvisociety.app ..."
keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -alias marvi \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Marvi Society, OU=Mobile, O=Marvi Society, L=Istanbul, ST=Istanbul, C=TR"

echo ""
echo "Next:"
echo "  cp apps/android/keystore.properties.example apps/android/keystore.properties"
echo "  # Fill storePassword / keyPassword"
echo "  npm run build:android"
