#!/usr/bin/env bash
# 启动正式游戏。可选：直接用 Godot 跑项目（普通快捷方式）完全一样 ——
# 158 起不再先 --import：类缓存过期时游戏自己不到一秒重写、重开；有没导入的新素材才在后台导，不挡游戏。
#   GODOT=/path/to/godot tools/run_game.sh
set -u
GODOT="${GODOT:-/e/Godot/Godot_v4.7.1-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$GODOT" --path "$ROOT"
