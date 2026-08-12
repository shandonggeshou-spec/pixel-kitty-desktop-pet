#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
MODULE_CACHE="$BUILD_DIR/swift-module-cache"
PET_DIR="$ROOT_DIR/optional-trae-custom-pet"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE"

xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT_DIR/source/validate_native_pet.swift" \
  -o "$BUILD_DIR/validate_native_pet"

"$BUILD_DIR/validate_native_pet" "$PET_DIR/spritesheet.png"
