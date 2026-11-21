#!/bin/bash
# v7.31–v7.43 走查：委托【完成】/【交货】/【前往】、食堂收藏、苗圃作物 + 食材炼金、新武器 / 护甲进仓库；无头：新道具、难度第二批
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=${B:-/tmp/claude-0/walk741}; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
COMBOS=${COMBOS:-zh_normal en_large zh_large}
WALKS=${WALKS:-comm788 canteen786 nurs805 a11 e798}
mkdir -p $B; cd $P; git log --oneline -1; timeout 600 godot --headless --path $P --import > $B/import.log 2>&1; echo "import=$?"
for LS in $COMBOS; do
  D=$B/walk-$LS; mkdir -p $D
  for W in $WALKS; do
    cl; cfg "$U" ${LS%_*} ${LS#*_}
    X $P --rendering-driver opengl3 --script $S/$W.gd -- $D > $D/$W.log 2>&1; echo "$W $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/$W.log)"
  done
done
if [ -n "$HEADLESS" ]; then
  timeout 1500 godot --headless --path $P --script $S/i784.gd > $B/i784.log 2>&1; echo "i784=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $B/i784.log)"
  timeout 1500 godot --headless --path $P --script $S/d794.gd > $B/d794.log 2>&1; echo "d794=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $B/d794.log)"
fi
cl
