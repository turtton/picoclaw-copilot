#!/usr/bin/env bash
set -euo pipefail

# Apply all patches to the upstream source in .upstream/
# Usage: ./scripts/apply-patches.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

UPSTREAM_DIR="$REPO_ROOT/.upstream"
PATCHES_DIR="$REPO_ROOT/patches"

if [ ! -d "$UPSTREAM_DIR" ]; then
  echo "Error: Upstream source not found at $UPSTREAM_DIR"
  echo "Run ./scripts/fetch-upstream.sh first"
  exit 1
fi

if [ ! -d "$PATCHES_DIR" ] || [ -z "$(ls -A "$PATCHES_DIR"/*.patch 2>/dev/null)" ]; then
  echo "No patches found in $PATCHES_DIR"
  exit 0
fi

echo "Applying patches to $UPSTREAM_DIR..."

for patchfile in "$PATCHES_DIR"/*.patch; do
  echo "  Applying: $(basename "$patchfile")"
  if ! patch -d "$UPSTREAM_DIR" -p1 < "$patchfile"; then
    echo ""
    echo "Error: Failed to apply $(basename "$patchfile")"
    echo "The .upstream/ directory may be in a partially patched state."
    echo "To recover, re-run: ./scripts/fetch-upstream.sh && ./scripts/apply-patches.sh"
    exit 1
  fi
done

echo "All patches applied successfully."
