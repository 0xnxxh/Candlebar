#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG_PATH="$ROOT_DIR/Resources/Logo/candlebar-logo.svg"
ICONSET_DIR="$ROOT_DIR/Resources/AppIcon.iconset"
ICNS_PATH="$ROOT_DIR/Resources/AppIcon.icns"
TMP_DIR="$ROOT_DIR/dist/icon-build"
BASE_PNG="$TMP_DIR/AppIcon-1024.png"

if [[ ! -f "$SVG_PATH" ]]; then
  echo "missing logo svg: $SVG_PATH" >&2
  exit 1
fi

rm -rf "$TMP_DIR" "$ICONSET_DIR"
mkdir -p "$TMP_DIR" "$ICONSET_DIR"

/usr/bin/qlmanage -t -s 1024 -o "$TMP_DIR" "$SVG_PATH" >/dev/null 2>&1
GENERATED_PNG="$TMP_DIR/$(basename "$SVG_PATH").png"
if [[ ! -f "$GENERATED_PNG" ]]; then
  echo "failed to render svg with qlmanage" >&2
  exit 1
fi
mv "$GENERATED_PNG" "$BASE_PNG"

make_png() {
  local size="$1"
  local name="$2"
  /usr/bin/sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET_DIR/$name" >/dev/null
}

make_png 16 icon_16x16.png
make_png 32 icon_16x16@2x.png
make_png 32 icon_32x32.png
make_png 64 icon_32x32@2x.png
make_png 128 icon_128x128.png
make_png 256 icon_128x128@2x.png
make_png 256 icon_256x256.png
make_png 512 icon_256x256@2x.png
make_png 512 icon_512x512.png
make_png 1024 icon_512x512@2x.png

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
rm -rf "$TMP_DIR" "$ICONSET_DIR"

echo "$ICNS_PATH"
