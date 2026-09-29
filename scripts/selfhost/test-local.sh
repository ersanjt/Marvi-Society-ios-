#!/usr/bin/env bash
# Prove the self-hosted schema works on vanilla PostgreSQL 17 without touching any server:
# apply all migrations (twice, for idempotency), run the booking/RLS smoke test, and a
# Supabase-format dump → filter → restore roundtrip. Uses a throwaway cluster in .tools/pg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS="$ROOT/.tools/pg"
PORT="${MARVI_PG_PORT:-55432}"
mkdir -p "$TOOLS"
cd "$TOOLS"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) PLATFORM=darwin-arm64 ;;
  Darwin-x86_64) PLATFORM=darwin-x64 ;;
  Linux-x86_64) PLATFORM=linux-x64 ;;
  Linux-aarch64) PLATFORM=linux-arm64 ;;
  *) echo "Unsupported platform $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

[[ -f package.json ]] || echo '{"name":"marvi-pg-local","private":true}' > package.json
if [[ ! -x "node_modules/@embedded-postgres/$PLATFORM/native/bin/postgres" || ! -d node_modules/pg-copy-streams ]]; then
  VERSION="$(npm view "@embedded-postgres/$PLATFORM" versions --json | python3 -c 'import json,sys; print([v for v in json.load(sys.stdin) if v.startswith("17.")][-1])')"
  npm install --no-audit --no-fund "@embedded-postgres/$PLATFORM@$VERSION" pg pg-copy-streams >/dev/null
fi

BIN="$TOOLS/node_modules/@embedded-postgres/$PLATFORM/native/bin"
DATA="$TOOLS/data"
cleanup() { "$BIN/pg_ctl" -D "$DATA" -m fast stop >/dev/null 2>&1 || true; }
trap cleanup EXIT

rm -rf "$DATA"
"$BIN/initdb" -D "$DATA" -U postgres --auth=trust -E UTF8 >/dev/null
"$BIN/pg_ctl" -D "$DATA" -o "-p $PORT -k /tmp -c listen_addresses=127.0.0.1" -l "$TOOLS/pg.log" -w start >/dev/null

export MARVI_PG_TOOLS="$TOOLS" MARVI_PG_PORT="$PORT"
node "$ROOT/scripts/selfhost/test/apply.mjs" marvi_test
node "$ROOT/scripts/selfhost/test/smoke.mjs" marvi_test
node "$ROOT/scripts/selfhost/test/roundtrip.mjs" marvi_test marvi_restore
echo "✓ self-host tests passed"
