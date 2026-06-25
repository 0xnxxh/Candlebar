#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Candlebar"
BUNDLE_ID="com.hoon.Candlebar"
FEED_URL="https://github.com/0xnxxh/Candlebar/releases/latest/download/appcast.xml"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/version.sh"
SPARKLE_DIR="$("$ROOT_DIR/script/ensure_sparkle.sh")"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SOURCE_INFO_PLIST="$ROOT_DIR/Config/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Config/Candlebar.entitlements"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
SPARKLE_PUBLIC_KEY_FILE="$ROOT_DIR/sparkle_public_ed_key.txt"
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

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ -n "$XCODE_DEVELOPER_DIR" ]]; then
  if DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" /usr/bin/xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
    export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
  else
    echo "warning: Xcode is installed but unavailable; using active developer directory: $(xcode-select -p)" >&2
    echo "warning: run 'sudo xcodebuild -license' in Terminal to enable the full Xcode toolchain." >&2
  fi
fi

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
"$ROOT_DIR/script/make_icon.sh" >/dev/null

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_FRAMEWORKS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
/usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY" 2>/dev/null || true
cp -R "$SPARKLE_DIR/Sparkle.framework" "$APP_FRAMEWORKS/"
cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"
cp "$SOURCE_INFO_PLIST" "$INFO_PLIST"

if [[ ! -s "$SPARKLE_PUBLIC_KEY_FILE" ]]; then
  echo "missing Sparkle public key; run script/generate_sparkle_keys.sh" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL $FEED_URL" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $(tr -d '[:space:]' < "$SPARKLE_PUBLIC_KEY_FILE")" "$INFO_PLIST"

codesign --force --sign - "$APP_FRAMEWORKS/Sparkle.framework" >/dev/null
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --build-only|build-only|build)
    echo "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--build-only]" >&2
    exit 2
    ;;
esac
