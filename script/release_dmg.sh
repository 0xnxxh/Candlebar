#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Candlebar"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/version.sh"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-v$APP_VERSION.dmg"
VOLUME_DIR="$DIST_DIR/dmg-volume"

cd "$ROOT_DIR"

"$ROOT_DIR/script/build_and_run.sh" --build-only

rm -rf "$VOLUME_DIR" "$DMG_PATH"
mkdir -p "$VOLUME_DIR"
cp -R "$APP_BUNDLE" "$VOLUME_DIR/"
ln -s /Applications "$VOLUME_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME $APP_VERSION" \
  -srcfolder "$VOLUME_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$VOLUME_DIR"

codesign --verify --deep --strict "$APP_BUNDLE"
spctl --assess --type execute "$APP_BUNDLE" || true

echo "$DMG_PATH"
