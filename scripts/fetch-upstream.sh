#!/usr/bin/env bash
set -euo pipefail

# Fetch upstream picoclaw source for local development and patch creation.
# Usage: ./scripts/fetch-upstream.sh [version]
#   version defaults to the value in .upstream-version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-$(cat "$REPO_ROOT/.upstream-version")}"
UPSTREAM_DIR="$REPO_ROOT/.upstream"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching picoclaw v${VERSION}..."

git clone --depth 1 --branch "v${VERSION}" \
  https://github.com/sipeed/picoclaw.git "$TMPDIR/picoclaw"

rm -rf "$TMPDIR/picoclaw/.git"

rm -rf "$UPSTREAM_DIR"
mv "$TMPDIR/picoclaw" "$UPSTREAM_DIR"

echo "Upstream source available at: $UPSTREAM_DIR"
echo "To create patches:"
echo "  1. Make changes in $UPSTREAM_DIR"
echo "  2. Run: ./scripts/create-patch.sh"
