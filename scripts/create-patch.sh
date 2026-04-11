#!/usr/bin/env bash
set -euo pipefail

# Generate a patch from changes in .upstream/ against clean upstream.
# Usage: ./scripts/create-patch.sh <patch-name>
#   Example: ./scripts/create-patch.sh 0002-add-help-slash-command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

UPSTREAM_DIR="$REPO_ROOT/.upstream"
PATCHES_DIR="$REPO_ROOT/patches"
VERSION="$(cat "$REPO_ROOT/.upstream-version")"

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <patch-name>"
  echo "Example: $0 0002-add-help-slash-command"
  exit 1
fi

PATCH_NAME="$1"

if [ ! -d "$UPSTREAM_DIR" ]; then
  echo "Error: Upstream source not found at $UPSTREAM_DIR"
  echo "Run ./scripts/fetch-upstream.sh first"
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Fetching clean upstream v${VERSION} for diff..."
git clone --depth 1 --branch "v${VERSION}" \
  https://github.com/sipeed/picoclaw.git "$WORK_DIR"

cp -a "$UPSTREAM_DIR"/. "$WORK_DIR/" 2>/dev/null || cp -r "$UPSTREAM_DIR"/. "$WORK_DIR/"

mkdir -p "$PATCHES_DIR"
PATCH_FILE="$PATCHES_DIR/${PATCH_NAME}.patch"

git -C "$WORK_DIR" add -A
git -C "$WORK_DIR" diff --cached > "$PATCH_FILE"

if [ ! -s "$PATCH_FILE" ]; then
  echo "No differences found. Patch file not created."
  rm -f "$PATCH_FILE"
  exit 0
fi

echo "Patch created: $PATCH_FILE"
echo "Lines: $(wc -l < "$PATCH_FILE")"
