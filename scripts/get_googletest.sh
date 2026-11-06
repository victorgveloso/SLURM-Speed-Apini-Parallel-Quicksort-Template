#!/usr/bin/env bash
# Downloads Google Test (pinned release) into third_party/googletest.
# Run it ONCE, on your laptop or a login node: compute nodes may have no
# internet access. The Makefile builds it from source (no CMake needed).
set -euo pipefail
VERSION=1.14.0
SHA256=8ad598c73ad796e0d8280b082cebd82a630d73e73cd3c70057938a6501bba5d7
URL=https://github.com/google/googletest/archive/refs/tags/v$VERSION.tar.gz

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=$ROOT/third_party/googletest
if [ -f "$DEST/googletest/src/gtest-all.cc" ]; then
    echo "googletest already present in $DEST"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "downloading googletest $VERSION ..."
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$TMP/gtest.tar.gz" "$URL"
else
    wget -q -O "$TMP/gtest.tar.gz" "$URL"
fi

# Check the archive is the one we expect (sha256sum on Linux, shasum on macOS).
if command -v sha256sum >/dev/null 2>&1; then
    got=$(sha256sum "$TMP/gtest.tar.gz" | cut -d' ' -f1)
else
    got=$(shasum -a 256 "$TMP/gtest.tar.gz" | cut -d' ' -f1)
fi
if [ "$got" != "$SHA256" ]; then
    echo "error: checksum mismatch for $URL" >&2
    echo "  expected $SHA256" >&2
    echo "  got      $got" >&2
    exit 1
fi

mkdir -p "$DEST"
tar xzf "$TMP/gtest.tar.gz" -C "$DEST" --strip-components=1
echo "googletest $VERSION installed in $DEST"
