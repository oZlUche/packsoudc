#!/bin/bash
# 用法：matrix.sh <输出根> <组合...>  组合 = lang:text:WxH
cd ${WT:-/home/user/wt_base}
R=$1; shift
for c in "$@"; do
  IFS=: read l t r <<< "$c"
  o="$R/${l}_${t}_${r}"
  rm -rf "$o"; mkdir -p "$o"
  timeout 600 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 --script res://_probe/u0_probe.gd -- "$o" $l $t $r --calib-source=auto > "$o/run.log" 2>&1
  echo "$c exit $? $(grep -c 'SCRIPT ERROR' $o/run.log) errs; $(grep '^U0 结束' $o/run.log)"
done
