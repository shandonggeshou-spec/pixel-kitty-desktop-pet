#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
MODULE_CACHE="$BUILD_DIR/swift-module-cache"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE"

xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT_DIR/source/make_native_pet.swift" \
  -o "$BUILD_DIR/make_native_pet"

xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT_DIR/source/native_contact_sheet.swift" \
  -o "$BUILD_DIR/native_contact_sheet"

"$BUILD_DIR/make_native_pet" "$ROOT_DIR/spritesheet.png"
"$BUILD_DIR/native_contact_sheet" "$ROOT_DIR/spritesheet.png" "$ROOT_DIR/contact-sheet.png"

echo "Built spritesheet.png and contact-sheet.png"
