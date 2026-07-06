#!/bin/bash
# Package AAB + store assets for Google Play Console upload.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/release/google-play"
SRC_SCREEN="$ROOT/apps/web/public/screenshots/iphone"
ICON_SRC="$ROOT/apps/ios/MarviSociety/Resources/Assets.xcassets/AppIcon.appiconset/MarviIcon.png"
AAB="$ROOT/apps/android/app/build/outputs/bundle/release/app-release.aab"

mkdir -p "$OUT/screenshots/phone"

if [[ -f "$AAB" ]]; then
  cp "$AAB" "$OUT/app-release.aab"
  echo "✓ AAB copied"
else
  echo "⚠ AAB missing — run: npm run build:android"
fi

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$OUT/icon-512.png"
  if command -v sips >/dev/null 2>&1; then
    sips -z 512 512 "$OUT/icon-512.png" >/dev/null 2>&1 || true
  fi
  echo "✓ Icon 512"
fi

for f in marvi-01-kesfet marvi-02-profil-creator marvi-03-etkinliklerim marvi-04-sosyal-hesaplar marvi-05-yasal-hesap; do
  if [[ -f "$SRC_SCREEN/${f}.png" ]]; then
    cp "$SRC_SCREEN/${f}.png" "$OUT/screenshots/phone/"
  fi
done
echo "✓ Screenshots"

cp "$ROOT/docs/google-play/STORE_LISTING.md" "$OUT/"
cp "$ROOT/docs/google-play/CONTENT_RATING.md" "$OUT/"
cp "$ROOT/docs/google-play/DATA_SAFETY.md" "$OUT/"
cp "$ROOT/docs/google-play/SUBMIT_NOW.md" "$OUT/"

cat > "$OUT/README.txt" <<EOF
Marvi Society — Google Play upload bundle
Package: com.marvisociety.app

1. Upload app-release.aab in Play Console → Release → Internal testing
2. Store text: STORE_LISTING.md
3. Screenshots: screenshots/phone/
4. Icon: icon-512.png
5. Full steps: SUBMIT_NOW.md
EOF

echo ""
echo "Release bundle ready: $OUT"
ls -lh "$OUT" 2>/dev/null | head -10
