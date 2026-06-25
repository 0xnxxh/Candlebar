#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_DEVELOPER_DIR=""

for candidate in \
  "/Applications/Xcode.app/Contents/Developer" \
  "/Applications/Xcode-beta.app/Contents/Developer"
do
  if [[ -d "$candidate" ]]; then
    XCODE_DEVELOPER_DIR="$candidate"
    break
  fi
done

cd "$ROOT_DIR"

if [[ -n "$XCODE_DEVELOPER_DIR" ]]; then
  if DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" /usr/bin/xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
    export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
  else
    echo "warning: Xcode is installed but unavailable; using active developer directory: $(xcode-select -p)" >&2
  fi
fi

swift build --build-tests
BUILD_DIR="$(swift build --show-bin-path)"
mkdir -p "$BUILD_DIR/PackageFrameworks"
rm -rf "$BUILD_DIR/PackageFrameworks/Sparkle.framework"
cp -R "$BUILD_DIR/Sparkle.framework" "$BUILD_DIR/PackageFrameworks/"
swift test --skip-build
