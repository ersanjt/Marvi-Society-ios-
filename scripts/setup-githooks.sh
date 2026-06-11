#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$REPO_ROOT/.githooks/pre-push"
git -C "$REPO_ROOT" config core.hooksPath .githooks
echo "✓ Git hooks enabled (.githooks/pre-push)"
echo "  Skip once: MARVI_SKIP_HOOKS=1 git push"
