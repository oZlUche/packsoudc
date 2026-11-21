#!/bin/bash
# v6.85：全量 + 铁匠铺打三把法杖、仓库卖碎晶
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-21-v685; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
COMBOS=${COMBOS:-zh_normal en_large zh_large}
cd $P; git log --oneline -1
[ -n "$NOSUITE" ] || SUITE=1 WALKS="" bash /tmp/claude-0/r645.sh
for LS in $COMBOS; do
  D=$B/walk-$LS; mkdir -p $D
  for W in smith735; do
    cl; cfg "$U" ${LS%_*} ${LS#*_}
    X $P --rendering-driver opengl3 --script $S/$W.gd -- $D > $D/run_$W.log 2>&1; echo "$W $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_$W.log)"
  done
done
cl
