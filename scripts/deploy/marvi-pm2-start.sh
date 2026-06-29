#!/bin/bash
# PM2 entrypoint for Next.js standalone on WHM. Sources apps/web/.env.production at runtime.
set -euo pipefail
cd "$(dirname "$0")"
export NODE_ENV=production
export PORT="${PORT:-3000}"
export HOSTNAME="0.0.0.0"
ENV_FILE="apps/web/.env.production"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi
exec node apps/web/server.js
