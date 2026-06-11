#!/bin/sh
# Injects Supabase credentials from xcconfig into Secrets.plist inside the app bundle.
set -eu

PLIST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Secrets.plist"

if [ ! -f "$PLIST" ]; then
  echo "warning: Secrets.plist not found at $PLIST"
  exit 0
fi

if [ -z "${MARVI_SUPABASE_URL:-}" ] || [ -z "${MARVI_SUPABASE_ANON_KEY:-}" ]; then
  echo "error: MARVI_SUPABASE_URL / MARVI_SUPABASE_ANON_KEY not set in xcconfig"
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :MARVI_SUPABASE_URL ${MARVI_SUPABASE_URL}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :MARVI_SUPABASE_ANON_KEY ${MARVI_SUPABASE_ANON_KEY}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :MARVI_API_MODE ${MARVI_API_MODE:-supabase}" "$PLIST"

echo "Injected Supabase config into Secrets.plist"
