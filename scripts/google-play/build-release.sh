#!/bin/bash
# Build signed Android App Bundle (.aab) for Google Play.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/apps/android"
source "$ROOT/scripts/release/lib.sh"

marvi_require_repo

# JDK: Android Studio JBR, then Homebrew openjdk@17
if [[ -z "${JAVA_HOME:-}" ]]; then
  for candidate in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
    "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"; do
    if [[ -x "$candidate/bin/java" ]]; then
      export JAVA_HOME="$candidate"
      break
    fi
  done
fi

if [[ -z "${JAVA_HOME:-}" ]] || ! "$JAVA_HOME/bin/java" -version >/dev/null 2>&1; then
  marvi_err "JDK not found. Install Android Studio or: brew install openjdk@17"
  exit 1
fi

LOCAL_PROPS="$ANDROID/local.properties"
if [[ ! -f "$LOCAL_PROPS" ]]; then
  IOS_SECRETS="$ROOT/apps/ios/Config/Secrets.xcconfig"
  if [[ -f "$IOS_SECRETS" ]]; then
    marvi_info "Creating local.properties from iOS Secrets.xcconfig..."
    URL=$(grep 'MARVI_SUPABASE_URL' "$IOS_SECRETS" | head -1 | sed 's/.*= *//' | tr -d ' ')
    URL="${URL//\$\(\)/}"
    KEY=$(grep 'MARVI_SUPABASE_ANON_KEY' "$IOS_SECRETS" | head -1 | sed 's/.*= *//' | tr -d ' ')
    SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    cat > "$LOCAL_PROPS" <<EOF
MARVI_SUPABASE_URL=$URL
MARVI_SUPABASE_ANON_KEY=$KEY
MARVI_API_MODE=supabase
sdk.dir=$SDK
EOF
    marvi_ok "Wrote $LOCAL_PROPS"
  else
    marvi_err "Missing $LOCAL_PROPS — copy local.properties.example and add Supabase keys"
    exit 1
  fi
fi

if [[ ! -f "$ANDROID/keystore.properties" ]]; then
  marvi_warn "No keystore.properties — building unsigned release bundle (Play Console can sign on first upload)"
fi

marvi_info "Building release AAB (v$(grep versionName "$ANDROID/app/build.gradle.kts" | head -1 | sed 's/.*"\(.*\)".*/\1/'))..."
cd "$ANDROID"
chmod +x gradlew
./gradlew :app:bundleRelease --no-daemon

AAB="$ANDROID/app/build/outputs/bundle/release/app-release.aab"
if [[ -f "$AAB" ]]; then
  marvi_ok "AAB ready: $AAB"
  ls -lh "$AAB"
else
  marvi_err "Build finished but AAB not found"
  exit 1
fi
