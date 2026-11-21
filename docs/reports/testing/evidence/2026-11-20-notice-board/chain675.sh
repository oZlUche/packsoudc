#!/bin/bash
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; O=/tmp/claude-0/old671; B=/mnt/project-files/testing/2026-11-20-v675; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
for LS in ${COMBOS:-zh_normal en_large zh_large}; do
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/board675.gd -- $D ${SEED:-31} > $D/run_board.log 2>&1; echo "board $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_board.log)"; grep "B675\|SCRIPT ERROR" $D/run_board.log
  [ -n "$NOGATE" ] && continue
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $O --rendering-driver opengl3 --script $S/make672.gd -- $D > $D/make_old.log 2>&1; echo "make $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/make_old.log)"
  X $P --rendering-driver opengl3 --script $S/gate672.gd -- $D old > $D/run_old.log 2>&1; echo "old $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_old.log)"; grep "G672\|SCRIPT ERROR" $D/run_old.log | grep -v "页上\|剧情页最后\|委托页·"
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/gate672.gd -- $D new > $D/run_new.log 2>&1; echo "new $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_new.log)"; grep "G672\|SCRIPT ERROR" $D/run_new.log | grep -v "交货\|真点后\|委托页·"
done
cl
