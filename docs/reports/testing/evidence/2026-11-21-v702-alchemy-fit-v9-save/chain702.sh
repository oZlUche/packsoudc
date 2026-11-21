#!/bin/bash
# v7.01/v7.02：全量 + 炼金页（英文大字不截）+ v8 老档升 v9 用尘补 + 《照抄》悬停
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-21-v702; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
COMBOS=${COMBOS:-zh_normal en_large zh_large}
cd $P; git log --oneline -1
sed -i "s#^B=.*#B=$B; T=/mnt/project-files/testing#" /tmp/claude-0/r645.sh
[ -n "$NOSUITE" ] || SUITE=1 WALKS="" bash /tmp/claude-0/r645.sh
for LS in $COMBOS; do
  [ -n "$ONLYV8" ] && { D=$B/walk-$LS; mkdir -p $D; cl; cfg "$U" ${LS%_*} ${LS#*_}; mkdir -p "$U/slots/1"; cp $P/tests/fixtures/meta_v8.json "$U/slots/1/meta.json"; X $P --rendering-driver opengl3 --script $S/alch702.gd -- $D v8 > $D/run_alch_v8.log 2>&1; echo "v8 $LS=$?"; continue; }
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/alch702.gd -- $D new > $D/run_alch_new.log 2>&1; echo "alch new $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_alch_new.log)"
  cl; cfg "$U" ${LS%_*} ${LS#*_}; mkdir -p "$U/slots/1"; cp $P/tests/fixtures/meta_v8.json "$U/slots/1/meta.json"
  X $P --rendering-driver opengl3 --script $S/alch702.gd -- $D v8 > $D/run_alch_v8.log 2>&1; echo "alch v8 $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_alch_v8.log)"
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/copy682.gd -- $D > $D/run_copy682.log 2>&1; echo "copy682 $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_copy682.log)"
done
cl
