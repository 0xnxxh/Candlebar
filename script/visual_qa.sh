#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/qa-artifacts"
APP_NAME="Candlebar"
SCREENSHOT="$ARTIFACT_DIR/candlebar-desktop.png"
REPORT="$ARTIFACT_DIR/visual-qa.txt"

mkdir -p "$ARTIFACT_DIR"

"$ROOT_DIR/script/build_and_run.sh" --build-only
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
CANDLEBAR_QA_WINDOW=1 "$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 &
APP_PID="$!"
sleep 2

SCREENSHOT_STATUS="created"
if /usr/sbin/screencapture -x "$SCREENSHOT" 2>/dev/null; then
  IMAGE_INFO="$(/usr/bin/sips -g pixelWidth -g pixelHeight "$SCREENSHOT" 2>/dev/null)"
else
  SCREENSHOT_STATUS="unavailable: screencapture could not create an image from the current display/session"
  IMAGE_INFO="pixelWidth: unavailable
pixelHeight: unavailable"
fi
PROCESS_ID="$(pgrep -x "$APP_NAME" | head -1)"

{
  echo "Candlebar Visual QA"
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "App process: ${PROCESS_ID:-missing}"
  echo "QA launch process: $APP_PID"
  echo "Screenshot: $SCREENSHOT"
  echo "Screenshot status: $SCREENSHOT_STATUS"
  echo "$IMAGE_INFO"
  echo
  echo "Manual QA checklist:"
  echo "- Inspect the QA main panel window at 400x620; it renders the same MainPanelView as the MenuBarExtra popover."
  echo "- Verify watchlist rows do not overlap with long symbols or extreme prices."
  echo "- Verify account metrics show -- instead of fake values when unavailable."
  echo "- Verify Reduce Motion disables price flash while preserving color/status."
  echo "- Verify dark/light appearances remain readable."
} > "$REPORT"

cat "$REPORT"
