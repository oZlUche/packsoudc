#!/bin/bash
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-20-v680; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
for LS in ${COMBOS:-zh_normal en_large zh_large}; do
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/nurs680.gd -- $D 51 > $D/run_nursery.log 2>&1; echo "nursery $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_nursery.log)"; grep "N680\|SCRIPT ERROR" $D/run_nursery.log | head -60
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/prep678.gd -- $D new 41 > $D/run_prep.log 2>&1; echo "prep $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_prep.log)"; grep "P678\|SCRIPT ERROR" $D/run_prep.log | grep -v "地图协会剧情页" | head -40
done
cl
