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

# --import 会把整个项目的脚本解析一遍。它的输出以前直接丢掉了，
# 于是 ui/ 里的解析错误只能靠「跑起来才发现」。现在留下来一起检查。
IMPORTLOG="${TMPDIR:-/tmp}/godot_import.log"
"$GODOT" --headless --path "$ROOT" --import >"$IMPORTLOG" 2>&1
timeout 480 "$GODOT" --headless --path "$ROOT" --script res://tests/run_tests.gd >"$LOG" 2>&1
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

# 单元测试只加载 run_tests 够得着的脚本；ui/ 与 tools/ 下的东西改接口时最容易漏。
# 这一步把全项目的 .gd 都 load 一遍，一次 Godot 启动搞定。
CHECKLOG="${TMPDIR:-/tmp}/godot_check_scripts.log"
"$GODOT" --headless --path "$ROOT" --script res://tools/check_scripts.gd \
  >"$CHECKLOG" 2>&1
if grep -qE '加载失败|Failed to load script|Parse Error' "$CHECKLOG"; then
  echo ""
  echo "!! 有脚本加载失败"
  grep -E 'Failed to load script|Parse Error|SCRIPT ERROR' "$CHECKLOG" | head -12
  code=1
fi

echo "EXIT=$code"
exit $code
