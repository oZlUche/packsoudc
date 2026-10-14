#!/usr/bin/env bash
# 173 §3.4：只读检查本机存档 —— 每个存档位跑一遍读档 + 内容对账，打印会折钱 / 挪位 / 作废的道具，不写文件。
#
#   bash tools/check_saves.sh              # 查游戏自己的 user://slots
#   bash tools/check_saves.sh /some/dir    # 查别的目录（结构同 slots/<n>/meta.json）
set -u
if [ -z "${GODOT:-}" ]; then
  for candidate in godot godot4 Godot; do
    if command -v "$candidate" >/dev/null 2>&1; then
      GODOT="$(command -v "$candidate")"
      break
    fi
  done
fi
GODOT="${GODOT:-/e/Godot/Godot_v4.7.1-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$GODOT" --headless --path "$ROOT" --script res://tools/check_saves.gd -- "$@" 2>&1 | grep -E '^内容版本|^第 |^    '
exit "${PIPESTATUS[0]}"
