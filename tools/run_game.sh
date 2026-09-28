#!/usr/bin/env bash
# 启动正式游戏。先 --import 重建全局类缓存（新加 class_name 后不做这一步会灰屏，见 091）。
#   GODOT=/path/to/godot tools/run_game.sh
set -u
GODOT="${GODOT:-/e/Godot/Godot_v4.7.1-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
exec "$GODOT" --path "$ROOT"
