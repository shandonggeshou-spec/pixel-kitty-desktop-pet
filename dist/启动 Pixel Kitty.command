#!/bin/zsh
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$APP_DIR/PixelKitty.app"

open -n "$APP"
if [[ $? -ne 0 ]]; then
  osascript -e 'display dialog "Pixel Kitty 启动失败，请右键 PixelKitty.app → 打开，再确认一次。" buttons {"好"} default button "好" with icon caution'
fi
