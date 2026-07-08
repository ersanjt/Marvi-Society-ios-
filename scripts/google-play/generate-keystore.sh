#!/bin/bash
# Create upload keystore for Google Play (run once). Passwords saved to gitignored files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/apps/android"
KEYSTORE="$ANDROID/marvi-release.jks"
PROPS="$ANDROID/keystore.properties"
BACKUP="$ANDROID/KEYSTORE_BACKUP.local.txt"

if [[ -f "$KEYSTORE" && -f "$PROPS" ]]; then
  echo "Keystore already exists: $KEYSTORE"
  exit 0
fi

JAVA_BIN="${JAVA_HOME:-}/bin/keytool"
if [[ ! -x "$JAVA_BIN" ]]; then
  for candidate in \
    "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/keytool" \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"; do
    if [[ -x "$candidate" ]]; then
      JAVA_BIN="$candidate"
      break
    fi
  done
fi

if [[ ! -x "$JAVA_BIN" ]]; then
  echo "Install JDK: brew install openjdk@17"
  exit 1
fi

PASS="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)"

echo "Creating release keystore for com.marvisociety.app ..."
"$JAVA_BIN" -genkeypair -v \
  -keystore "$KEYSTORE" \
  -alias marvi \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" \
  -keypass "$PASS" \
  -dname "CN=Marvi Society, OU=Mobile, O=Marvi Society, L=Istanbul, ST=Istanbul, C=TR"

cat > "$PROPS" <<EOF
storeFile=marvi-release.jks
storePassword=$PASS
keyAlias=marvi
keyPassword=$PASS
EOF

cat > "$BACKUP" <<EOF
Marvi Society — Android upload keystore (KEEP SAFE — required for all Play updates)
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Package: com.marvisociety.app
Keystore file: apps/android/marvi-release.jks
Alias: marvi
Store password: $PASS
Key password: $PASS

Copy this file + marvi-release.jks to 1Password or another machine.
Never commit these to git.
EOF

echo ""
echo "✓ Keystore: $KEYSTORE"
echo "✓ Properties: $PROPS"
echo "✓ Backup credentials: $BACKUP"
echo ""
echo "Next: npm run build:android"
