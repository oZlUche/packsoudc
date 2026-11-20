#!/bin/bash
# 用法：SEEDS="zh_normal:7 en_large:9 zh_large:9" bash chain670.sh
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-20-v674; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
for PAIR in $SEEDS; do
  LS=${PAIR%:*}; SD=${PAIR#*:}; D=$B/walk-$LS; mkdir -p $D
  if [ -z "$SKIPTABS" ]; then
    cl; cfg "$U" ${LS%_*} ${LS#*_}
    timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/b668.gd -- $D normal > $D/run_tabs.log 2>&1; echo "tabs $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_tabs.log)"; grep "B668\|SCRIPT ERROR" $D/run_tabs.log | grep -v "页签 \(expedition\|warehouse\|commissions\|logistics\)「"
  fi
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  timeout 1200 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/alt670.gd -- $D ${SD/,/ } > $D/run_alt.log 2>&1; echo "alt $LS seed $SD=$? err=$(grep -c 'SCRIPT ERROR' $D/run_alt.log)"; grep "A670\|SCRIPT ERROR" $D/run_alt.log
done
cl
