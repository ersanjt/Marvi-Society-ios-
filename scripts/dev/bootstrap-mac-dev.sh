#!/usr/bin/env bash
# Bootstrap this Mac for Marvi iOS + Android development (user-space, no sudo).
# Usage: bash scripts/dev/bootstrap-mac-dev.sh
set -euo pipefail

TOOLS_SRC="${MARVI_TOOLS_SRC:-$HOME/Projects/Marvi-Society/.tools}"
SDK_LINK="$HOME/Library/Android/sdk"
JDK_HOME="$TOOLS_SRC/jdk/jdk-17.0.16+8/Contents/Home"

mkdir -p "$HOME/Applications" "$HOME/.local/bin" "$HOME/.appstoreconnect/private_keys" "$HOME/.android"

if [[ ! -e "$SDK_LINK" && -d "$TOOLS_SRC/android-sdk" ]]; then
  mkdir -p "$HOME/Library/Android"
  ln -sfn "$TOOLS_SRC/android-sdk" "$SDK_LINK"
  echo "✓ Linked Android SDK → $SDK_LINK"
fi

cat > "$HOME/.zprofile" <<EOF
# Marvi / mobile developer environment (Apple Silicon)
export JAVA_HOME="\${JAVA_HOME:-$JDK_HOME}"
export ANDROID_HOME="\${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export PATH="\$HOME/.local/bin:\$HOME/Applications/Android Studio.app/Contents/MacOS:\$JAVA_HOME/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/emulator:$TOOLS_SRC/node/bin:$TOOLS_SRC/bin:/Applications/Xcode.app/Contents/Developer/usr/bin:\$PATH"
export APP_STORE_CONNECT_API_KEY_ID="\${APP_STORE_CONNECT_API_KEY_ID:-U66SGD9ZWQ}"
export APP_STORE_CONNECT_ISSUER_ID="\${APP_STORE_CONNECT_ISSUER_ID:-8b84fa76-827a-48b1-bbce-71bdce84ac52}"
export APP_STORE_CONNECT_API_KEY_PATH="\${APP_STORE_CONNECT_API_KEY_PATH:-\$HOME/.appstoreconnect/private_keys/AuthKey_\${APP_STORE_CONNECT_API_KEY_ID}.p8}"
EOF
cp "$HOME/.zprofile" "$HOME/.zshrc"
echo "✓ Wrote ~/.zprofile and ~/.zshrc"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -d "$REPO_ROOT/apps/android" ]]; then
  echo "sdk.dir=$HOME/Library/Android/sdk" > "$REPO_ROOT/apps/android/local.properties"
  echo "✓ apps/android/local.properties"
fi

echo ""
echo "Still needed (manual, once):"
echo "  1) sudo password → install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
echo "  2) AuthKey_U66SGD9ZWQ.p8 → ~/.appstoreconnect/private_keys/"
echo "  3) Xcode → Settings → Accounts → sign in with Apple Developer"
echo "  4) Open ~/Applications/Android\\ Studio.app once to finish first-run"
echo ""
echo "Verify: source ~/.zprofile && java -version && adb version && xcodebuild -version"
