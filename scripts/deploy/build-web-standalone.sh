#!/bin/bash
# Build production standalone bundle for WHM/cPanel upload.
# Output: apps/web/.deploy/marvisociety-web.tar.gz
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WEB="$ROOT/apps/web"
OUT="$WEB/.deploy"
STAGE="$OUT/stage"

echo "→ Building Marvi Society web (standalone)…"
cd "$ROOT"
npm install --workspace=@marvi-society/web --include-workspace-root 2>/dev/null || npm install

export NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-https://gaswjuvyzliislqrljof.supabase.co}"
export NEXT_PUBLIC_SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-sb_publishable_SA0BDjBy4ow7haaZzX7Zlg_t0wFvO0Y}"
export NEXT_PUBLIC_SITE_URL="${NEXT_PUBLIC_SITE_URL:-https://marvisociety.com}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

cd "$WEB"
npm run build

rm -rf "$STAGE"
mkdir -p "$STAGE"

# Standalone server bundle
cp -R .next/standalone/. "$STAGE/"
mkdir -p "$STAGE/apps/web/.next"
cp -R .next/static "$STAGE/apps/web/.next/static"
cp -R public "$STAGE/apps/web/public" 2>/dev/null || true

# Production env (server-side)
cat > "$STAGE/apps/web/.env.production" <<EOF
NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
EOF

# PM2 / cPanel start helper
cat > "$STAGE/start.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export NODE_ENV=production
export PORT="${PORT:-3000}"
export HOSTNAME="${HOSTNAME:-0.0.0.0}"
exec node apps/web/server.js
EOF
chmod +x "$STAGE/start.sh"

mkdir -p "$OUT"
tar -czf "$OUT/marvisociety-web.tar.gz" -C "$STAGE" .
SIZE=$(du -h "$OUT/marvisociety-web.tar.gz" | cut -f1)
echo "✓ Package: $OUT/marvisociety-web.tar.gz ($SIZE)"
echo ""
echo "Upload to WHM server, then run:"
echo "  bash scripts/deploy/whm-install.sh"
