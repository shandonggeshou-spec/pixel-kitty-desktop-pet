#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
MODULE_CACHE="$BUILD_DIR/swift-module-cache"
PET_DIR="$ROOT_DIR/optional-trae-custom-pet"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE" "$PET_DIR"

xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT_DIR/source/make_native_pet.swift" \
  -o "$BUILD_DIR/make_native_pet"

xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT_DIR/source/native_contact_sheet.swift" \
  -o "$BUILD_DIR/native_contact_sheet"

"$BUILD_DIR/make_native_pet" "$PET_DIR/spritesheet.png"
"$BUILD_DIR/native_contact_sheet" "$PET_DIR/spritesheet.png" "$PET_DIR/contact-sheet.png"

echo "Built optional-trae-custom-pet/spritesheet.png and optional-trae-custom-pet/contact-sheet.png"
