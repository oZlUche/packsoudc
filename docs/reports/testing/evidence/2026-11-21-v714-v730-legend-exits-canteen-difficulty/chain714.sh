#!/bin/bash
# v7.14 + v7.17 + v7.18：全量 + 图例卷轴 + 撤离点关闭 / 再打开 + 出征页背景
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-21-v714; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
COMBOS=${COMBOS:-zh_normal en_large zh_large}
cd $P; git log --oneline -1
sed -i "s#^B=.*#B=$B; T=/mnt/project-files/testing#" /tmp/claude-0/r645.sh
[ -n "$NOSUITE" ] || SUITE=1 WALKS="" bash /tmp/claude-0/r645.sh
for LS in $COMBOS; do
  D=$B/walk-$LS; mkdir -p $D; rm -f "${D:?}"/*.png
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/legend714.gd -- $D first > $D/run_legend.log 2>&1; echo "legend first $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_legend.log)"
  rm -rf "${U:?}/slots" "${U:?}"/meta.json* "${U:?}"/run*.json*
  X $P --rendering-driver opengl3 --script $S/legend714.gd -- $D again > $D/run_legend_again.log 2>&1; echo "legend again $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_legend_again.log)"
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/smith368.gd -- $D > $D/run_smith368.log 2>&1; echo "smith368 $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_smith368.log)"
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/canteen371.gd -- $D > $D/run_canteen.log 2>&1; echo "canteen371 $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_canteen.log)"
done
timeout 1500 godot --headless --path $P --script $S/d360.gd > $B/d360.log 2>&1; echo "d360=$?"
timeout 300 godot --headless --path $P --script $S/g368.gd > $B/g368.log 2>&1; echo "g368=$?"
cl
