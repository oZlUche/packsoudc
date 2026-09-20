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
# 脚本运行时错误会中断所在的套件函数，剩下的断言静默消失，而退出码仍是 0 ——
# 那样覆盖率会悄悄缩水。凡日志里出现 SCRIPT ERROR 一律判失败。
if grep -q 'SCRIPT ERROR' "$LOG"; then
  echo ""
  echo "!! 日志中存在 SCRIPT ERROR，断言可能被静默跳过，判为失败"
  grep -n 'SCRIPT ERROR' "$LOG" | head -10
  code=1
fi

# tests/ 之外的脚本不会被 run_tests 加载，改接口时最容易漏。
# 逐个 --check-only 解析一遍：它不设退出码，只往 stderr 打字，所以看输出。
TOOLLOG="${TMPDIR:-/tmp}/godot_tools_check.log"
: >"$TOOLLOG"
for f in "$ROOT"/tools/*.gd; do
  [ -e "$f" ] || continue
  "$GODOT" --headless --path "$ROOT" --check-only     --script "res://tools/$(basename "$f")" >>"$TOOLLOG" 2>&1
done
if grep -qE 'Parse error|SCRIPT ERROR' "$TOOLLOG"; then
  echo ""
  echo "!! tools/ 下有脚本解析失败"
  grep -E 'Parse Error|Parse error|Failed to load script' "$TOOLLOG" | head -10
  code=1
fi

echo "EXIT=$code"
exit $code
