#!/bin/bash
# v6.99：全量 + 炼金走查（A 版排版、红字同名合并）
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-21-v699; S=/tmp/claude-0/scripts; K=/tmp/claude-0/old685
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
COMBOS=${COMBOS:-zh_normal en_large zh_large}
cd $P; git log --oneline -1
sed -i "s#^B=.*#B=$B; T=/mnt/project-files/testing#" /tmp/claude-0/r645.sh
[ -n "$NOSUITE" ] || SUITE=1 WALKS="" bash /tmp/claude-0/r645.sh
for LS in $COMBOS; do
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/alch699.gd -- $D new > $D/run_alch_new.log 2>&1; echo "alch new $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_alch_new.log)"
  cl; cp -r "$K/$LS"/. "$U"/
  X $P --rendering-driver opengl3 --script $S/alch699.gd -- $D old > $D/run_alch_old.log 2>&1; echo "alch old $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_alch_old.log)"
done
cl
