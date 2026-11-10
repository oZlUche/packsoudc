#!/usr/bin/env bash
# 收齐全项目的 GDScript 静态警告（引擎只在连着调试器时才报，无头跑测试看不到）。
#
#   bash tools/warnings.sh [out.jsonl]
#
# 开一个假调试器（tools/warnings_collector.gd），再用 --remote-debug 把全项目脚本加载一遍（tools/check_scripts.gd），
# 警告一行一条 JSON 落到 out.jsonl（默认 /tmp/godot_warnings.jsonl），末尾按类别汇总。
# 临时写一份 override.cfg 放开调试器的每秒上限（默认 400 条 / 秒，超了会丢），跑完就删。
set -u
OUT="${1:-${TMPDIR:-/tmp}/godot_warnings.jsonl}"
PORT="${WARN_PORT:-6009}"
. "$(dirname "${BASH_SOURCE[0]}")/_godot.sh"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -e "$ROOT/override.cfg" ]; then
  echo "已有 override.cfg，不覆盖；先挪开再跑" >&2
  exit 2
fi
printf '[network]\nlimits/debugger/max_warnings_per_second=100000\nlimits/debugger/max_errors_per_second=100000\nlimits/debugger/max_chars_per_second=10000000\n' > "$ROOT/override.cfg"
WARN_OUT="$OUT" WARN_PORT="$PORT" "$GODOT" --headless --path "$ROOT" --script res://tools/warnings_collector.gd >"$OUT.collector.log" 2>&1 &
CPID=$!
sleep 3
"$GODOT" --headless --path "$ROOT" --remote-debug "tcp://127.0.0.1:$PORT" --script res://tools/check_scripts.gd >"$OUT.client.log" 2>&1
wait $CPID
rm -f "$ROOT/override.cfg"
python3 - "$OUT" <<'PY'
import json, sys, collections
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
by = collections.Counter(r[7] for r in rows)
print("共 %d 条" % len(rows))
for code, n in by.most_common():
    print("%5d  %s" % (n, code))
for r in sorted(rows, key=lambda r: (r[4], r[6])):
    print("%s:%d  %s  %s" % (r[4], r[6], r[7], r[8]))
PY
