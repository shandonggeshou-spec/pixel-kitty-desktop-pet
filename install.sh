#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${TRAE_PETS_DIR:-$HOME/.trae/cli/pets}/pixel-kitty"

mkdir -p "$TARGET_DIR"
cp "$ROOT_DIR/pet.json" "$TARGET_DIR/pet.json"
cp "$ROOT_DIR/spritesheet.png" "$TARGET_DIR/spritesheet.png"
cp "$ROOT_DIR/contact-sheet.png" "$TARGET_DIR/contact-sheet.png"

echo "Installed Pixel Kitty to $TARGET_DIR"
echo "Open TRAE settings, refresh custom pets if needed, then select Pixel Kitty."
