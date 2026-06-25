#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/version.sh"

APP_BUNDLE="$("$ROOT_DIR/script/build_and_run.sh" build | tail -n 1)"
DMG_PATH="$("$ROOT_DIR/script/release_dmg.sh" | tail -n 1)"
APPCAST_PATH="$("$ROOT_DIR/script/generate_appcast.sh" | tail -n 1)"

/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null

if ! grep -q "Candlebar-v$APP_VERSION.dmg" "$APPCAST_PATH"; then
  echo "appcast does not reference Candlebar-v$APP_VERSION.dmg" >&2
  exit 1
fi

if ! grep -q "https://github.com/0xnxxh/Candlebar/releases/download/v$APP_VERSION/Candlebar-v$APP_VERSION.dmg" "$APPCAST_PATH"; then
  echo "appcast does not reference the versioned GitHub Release asset URL" >&2
  exit 1
fi

echo "app=$APP_BUNDLE"
echo "dmg=$DMG_PATH"
echo "appcast=$APPCAST_PATH"
