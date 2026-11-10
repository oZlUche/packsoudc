#!/usr/bin/env bash
# 173 §3.3：改了道具 / 标签 / 信仰 / 章节 / 敌人之后重生成内容快照。有没交代的改动（删了、改了形状却没进 IdAliases 的表）就不写，列出来。
#
#   bash tools/snapshot_content.sh
set -u
. "$(dirname "${BASH_SOURCE[0]}")/_godot.sh"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$GODOT" --headless --path "$ROOT" --script res://tools/snapshot_content.gd 2>&1 | grep -E '✗|快照|写不了'
exit "${PIPESTATUS[0]}"
