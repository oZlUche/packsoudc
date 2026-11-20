#!/bin/bash
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-20-v664b; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
for LS in ${COMBOS:-zh_normal en_large zh_large}; do
  cl; cfg "$U" ${LS%_*} ${LS#*_}; D=$B/popup-$LS; rm -rf $D; mkdir -p $D
  timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/popup662.gd -- $D > $D/run.log 2>&1; echo "popup $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run.log)"; grep "P662\|SCRIPT ERROR" $D/run.log
done
cl
