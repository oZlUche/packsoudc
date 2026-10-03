#!/usr/bin/env bash
# 启动正式游戏，先 --import 重建全局类缓存。可选（115）：直接用 Godot 跑项目也行 —— 缓存过期时游戏自己重导、自己重开，
# 这个脚本只是省掉那一次重启。
#   GODOT=/path/to/godot tools/run_game.sh
set -u
GODOT="${GODOT:-/e/Godot/Godot_v4.7.1-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
exec "$GODOT" --path "$ROOT"
