#!/usr/bin/env bash
# 跑无头测试。新增带 class_name 的脚本后必须先 --import 重建全局类缓存，
# 否则测试会以 'Identifier "X" not declared' 失败。这里每次都做，省得记。
#
#   GODOT=/path/to/godot_console.exe ./tools/test.sh
set -u
GODOT="${GODOT:-/e/Godot/Godot_v4.7.1-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="${TMPDIR:-/tmp}/godot_tests.log"

if [ ! -x "$GODOT" ]; then
  echo "找不到 Godot：$GODOT   （用 GODOT=... 指定）" >&2
  exit 127
fi

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
timeout 120 "$GODOT" --headless --path "$ROOT" --script res://tests/run_tests.gd >"$LOG" 2>&1
code=$?

# 过滤引擎与插件的噪声，只留测试输出和脚本错误
grep -vE '^\[|Ziva|PluginUpdater|Unreferenced static string|RID allocations|PagedAllocator|Thread object is being destroyed|wait_to_finish' "$LOG" \
  | grep -vE '^\s*$' | tail -60
echo "EXIT=$code"
exit $code
