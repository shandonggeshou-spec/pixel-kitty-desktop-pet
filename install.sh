#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${PIXEL_KITTY_APP_DIR:-$HOME/Applications}"
TARGET_APP="$TARGET_DIR/PixelKitty.app"

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_APP"
ditto "$ROOT_DIR/dist/PixelKitty.app" "$TARGET_APP"

echo "Installed Pixel Kitty to $TARGET_APP"
if [[ ! -x "$TARGET_APP/Contents/MacOS/PixelKitty" ]]; then
  echo "Install failed: app executable is missing." >&2
  exit 1
fi

if [[ "${PIXEL_KITTY_SKIP_OPEN:-0}" == "1" ]]; then
  echo "Skipped opening Pixel Kitty."
  exit 0
fi

echo "Opening Pixel Kitty..."
if ! open "$TARGET_APP"; then
  echo "Pixel Kitty is installed. If macOS blocks opening it, right-click PixelKitty.app and choose Open."
fi
