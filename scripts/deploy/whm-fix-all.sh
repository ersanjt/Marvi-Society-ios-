#!/bin/bash
# One-shot repair: restart Node app + configure reverse proxy.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$DIR/whm-restart-app.sh"
bash "$DIR/whm-fix-proxy.sh"
