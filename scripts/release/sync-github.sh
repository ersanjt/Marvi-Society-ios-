#!/bin/bash
# Stage, commit (if needed), and push to GitHub.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
marvi_require_repo

MESSAGE="${1:-}"
BRANCH=$(git -C "$REPO_ROOT" branch --show-current)

echo ""
echo "Marvi Society — Sync GitHub"
echo "==========================="
echo ""

if ! marvi_github_authenticated; then
  marvi_err "GitHub CLI not authenticated"
  echo ""
  echo "  Run once:"
  echo "    gh auth login"
  echo "  Then:"
  echo "    npm run sync:github"
  echo ""
  exit 1
fi

git -C "$REPO_ROOT" fetch origin "$BRANCH" 2>/dev/null || true

if [[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  marvi_info "Working tree clean — checking push..."
else
  if [[ -z "$MESSAGE" ]]; then
    MESSAGE="chore(ops): sync workspace $(date -u +%Y-%m-%d)"
  fi
  marvi_info "Committing changes..."
  git -C "$REPO_ROOT" add -A
  git -C "$REPO_ROOT" commit -m "$MESSAGE"
  marvi_ok "Committed: $MESSAGE"
fi

AHEAD=$(git -C "$REPO_ROOT" rev-list --count "origin/$BRANCH"..HEAD 2>/dev/null || echo "0")
if [[ "$AHEAD" == "0" ]]; then
  marvi_ok "Already up to date with origin/$BRANCH"
  marvi_append_sync_log "ok" "github already synced"
  exit 0
fi

marvi_info "Pushing $AHEAD commit(s) to origin/$BRANCH..."
if git -C "$REPO_ROOT" push -u origin "$BRANCH"; then
  marvi_ok "Pushed to GitHub"
  SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
  marvi_append_sync_log "ok" "pushed $SHA to origin/$BRANCH"
else
  marvi_err "Push failed"
  marvi_append_sync_log "error" "git push failed"
  exit 1
fi

echo ""
