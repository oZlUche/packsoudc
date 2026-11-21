#!/bin/bash
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; O=/tmp/claude-0/old671; B=/mnt/project-files/testing/2026-11-20-v674; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
[ -d $O/.godot ] || { timeout 1200 godot --headless --path $O --import > /tmp/claude-0/imp671.log 2>&1; echo "old import=$?"; }

for LS in ${COMBOS:-zh_normal en_large zh_large}; do
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/gate672.gd -- $D new > $D/run_new.log 2>&1; echo "new $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_new.log)"; grep "G672\|SCRIPT ERROR" $D/run_new.log
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/staff671.gd -- $D > $D/run_staff.log 2>&1; echo "staff $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_staff.log)"; grep "S671\|SCRIPT ERROR" $D/run_staff.log
done
if [ -z "$NOFIELD" ]; then D=$B/walk-zh_normal; cl; cfg "$U" zh normal
  timeout 1500 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/field674.gd -- $D 21 > $D/run_field.log 2>&1; echo "field=$? err=$(grep -c "SCRIPT ERROR" $D/run_field.log)"; grep "F674\|SCRIPT ERROR" $D/run_field.log | grep -v "页上的字"
fi
cl
