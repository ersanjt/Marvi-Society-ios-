#!/bin/bash
# Bump version, update manifest, tag, and append CHANGELOG.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
marvi_require_repo

VERSION="${1:-}"
SUMMARY="${2:-}"

if [[ -z "$VERSION" ]]; then
  marvi_err "Usage: npm run release -- <version> [summary]"
  echo "  Example: npm run release -- 0.3.0 'Venue media upload'"
  exit 1
fi

TAG="v$VERSION"
DATE=$(date -u +%Y-%m-%d)
HEAD=$(marvi_migration_head)

python3 - "$MARVI_MANIFEST" "$VERSION" "$DATE" "$HEAD" "$SUMMARY" <<'PY'
import json, sys
path, version, date, head, summary = sys.argv[1:6]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["version"] = version
data["releasedAt"] = f"{date}T00:00:00Z"
data.setdefault("components", {}).setdefault("web", {})["version"] = version
data.setdefault("components", {}).setdefault("ios", {})["marketingVersion"] = version.split("-")[0]
data["components"]["database"]["migrationHead"] = head
release = {"version": version, "tag": f"v{version}", "date": date, "summary": summary or "Release"}
data.setdefault("releases", []).insert(0, release)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

CHANGELOG="$REPO_ROOT/CHANGELOG.md"
if [[ ! -f "$CHANGELOG" ]]; then
  echo "# Changelog" > "$CHANGELOG"
  echo "" >> "$CHANGELOG"
fi

{
  echo "## [$VERSION] - $DATE"
  echo ""
  echo "${SUMMARY:-Release $VERSION}"
  echo ""
  echo "- Migration head: \`$HEAD\`"
  echo ""
} | cat - "$CHANGELOG" > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"

git -C "$REPO_ROOT" add "$MARVI_MANIFEST" "$CHANGELOG"
git -C "$REPO_ROOT" commit -m "release: v$VERSION" || true

if marvi_github_authenticated; then
  git -C "$REPO_ROOT" tag -a "$TAG" -m "${SUMMARY:-Release $VERSION}" 2>/dev/null || git -C "$REPO_ROOT" tag -f "$TAG"
  git -C "$REPO_ROOT" push origin "$TAG" 2>/dev/null || marvi_warn "Tag push failed — run: git push origin $TAG"
fi

marvi_ok "Release $TAG recorded"
marvi_append_sync_log "ok" "release $TAG"
