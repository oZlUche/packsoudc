#!/bin/bash
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-19-v655; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
for LS in ${COMBOS:-zh_normal en_large zh_large}; do for M in ${MODES:-layout}; do
  cl; cfg "$U" ${LS%_*} ${LS#*_}; D=$B/$M-$LS; rm -rf $D; mkdir -p $D
  timeout 1500 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/faith645.gd -- $D $M > $D/run.log 2>&1; echo "$M $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run.log)"; grep "F645\|SCRIPT ERROR" $D/run.log | grep -v "屏 META"
done; done
