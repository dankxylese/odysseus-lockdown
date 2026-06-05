#!/usr/bin/env bash
# Pin current HEAD as a rollback point, then pull upstream.
# Tags are local-only — never pushed. Roll back: git checkout pin-YYYY-MM-DD
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

TAG="pin-$(date +%Y-%m-%d)"

# Multiple pulls on the same day get a counter suffix
if git tag -l "$TAG" | grep -q .; then
    n=2
    while git tag -l "${TAG}-${n}" | grep -q .; do
        (( n++ ))
    done
    TAG="${TAG}-${n}"
fi

PREV=$(git rev-parse --short HEAD)
echo "pinned  $TAG  →  $PREV"

git tag "$TAG"
git pull

NEW=$(git rev-parse --short HEAD)
if [ "$PREV" = "$NEW" ]; then
    echo "already up to date"
else
    echo ""
    echo "new commits since $TAG:"
    git log "${TAG}..HEAD" --oneline
fi
