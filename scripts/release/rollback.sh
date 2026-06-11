#!/bin/bash
# Rollback guidance and safe git revert helper.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
marvi_require_repo

ACTION="${1:-help}"
TARGET="${2:-}"

echo ""
echo "Marvi Society — Rollback"
echo "========================"
echo ""

case "$ACTION" in
  help|"" )
    cat <<'GUIDE'

ROLLBACK PLAYBOOK
-----------------

1. APPLICATION (iOS)
   • Revert git to a known tag: git checkout v0.2.0
   • Rebuild in Xcode → Archive → resubmit if already in App Store
   • TestFlight: promote previous build in App Store Connect

2. WEB (Vercel)
   • Dashboard → Deployments → previous deployment → Promote to Production
   • Or CLI: vercel rollback (in apps/web)
   • Or git revert on main → auto-redeploy if Git connected

3. DATABASE (Supabase)
   • Supabase does NOT support automatic down-migrations
   • Dashboard → Database → Backups (Pro) or point-in-time recovery
   • Forward-fix: add a new migration that undoes the change
   • Never re-run ALL_MIGRATIONS_COMBINED on a live DB with data

4. GITHUB
   • View history: git log --oneline -20
   • Revert one commit:  npm run rollback -- git <sha>
   • Checkout release:    git checkout v0.2.0

COMMANDS
  npm run status              Current stack state
  npm run rollback -- git abc Revert commit (creates revert commit)
  npm run rollback -- tags    List release tags

GUIDE
    ;;

  git)
    if [[ -z "$TARGET" ]]; then
      marvi_err "Usage: npm run rollback -- git <commit-sha>"
      exit 1
    fi
    marvi_info "Creating revert commit for $TARGET..."
    git -C "$REPO_ROOT" revert --no-edit "$TARGET"
    marvi_ok "Revert commit created — run: npm run sync"
    ;;

  tags)
    git -C "$REPO_ROOT" tag -l 'v*' --sort=-version:refname | head -20
    ;;

  *)
    marvi_err "Unknown action: $ACTION (try: help, git, tags)"
    exit 1
    ;;
esac

echo ""
