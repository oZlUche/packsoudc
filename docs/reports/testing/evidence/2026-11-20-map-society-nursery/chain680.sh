#!/bin/bash
# v6.80：拉最新 main，全量 + 苗圃走查 + 旧档（v6.77 写的局外 v6 / 局内 v6）再读一次 + 第四页走查
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-20-v680; S=/tmp/claude-0/scripts; K=/tmp/claude-0/oldrun678
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
COMBOS=${COMBOS:-zh_normal en_large zh_large}
O=/tmp/claude-0/old671
for LS in $COMBOS; do
  D=$B/walk-$LS; mkdir -p $D "$K/$LS"
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $O --rendering-driver opengl3 --script $S/makerun.gd -- $D 41 > $D/make_oldrun.log 2>&1; echo "make $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/make_oldrun.log)"; grep "MAKE\|SCRIPT ERROR" $D/make_oldrun.log
  rm -rf "${K:?}/$LS"; mkdir -p "$K/$LS"; cp -r "$U/slots" "$U/settings.json" "$K/$LS"/
done
cd $P; git fetch -q origin main; git merge -q --ff-only origin/main; git log --oneline -1
mkdir -p $B
sed -i "s#^B=.*#B=$B; T=/mnt/project-files/testing#" /tmp/claude-0/r645.sh
[ -n "$NOSUITE" ] || SUITE=1 WALKS="" bash /tmp/claude-0/r645.sh
timeout 900 godot --headless --path $P --script $S/bias678.gd > $B/bias_sample.log 2>&1; echo "bias=$? err=$(grep -c 'SCRIPT ERROR' $B/bias_sample.log)"; grep "B678\|SCRIPT ERROR" $B/bias_sample.log
for LS in $COMBOS; do
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/nurs680.gd -- $D 51 > $D/run_nursery.log 2>&1; echo "nursery $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_nursery.log)"; grep "N680\|SCRIPT ERROR" $D/run_nursery.log
  cl; cp -r "$K/$LS"/. "$U"/
  X $P --rendering-driver opengl3 --script $S/prep678.gd -- $D old > $D/run_oldrun.log 2>&1; echo "oldrun $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_oldrun.log)"; grep "P678\|SCRIPT ERROR" $D/run_oldrun.log | grep -v "等地图"
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/prep678.gd -- $D new 41 > $D/run_prep.log 2>&1; echo "prep $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_prep.log)"; grep "P678\|SCRIPT ERROR" $D/run_prep.log | grep -v "地图协会剧情页"
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/board675.gd -- $D 31 > $D/run_board.log 2>&1; echo "board $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_board.log)"; grep "B675.*排版\|B675.*手头满\|B675.*放弃后\|B675.*办理】后\|SCRIPT ERROR" $D/run_board.log
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/gate672.gd -- $D new > $D/run_new.log 2>&1; echo "new $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run_new.log)"; grep "G672.*排版\|G672.*右列\|SCRIPT ERROR" $D/run_new.log
done
cl
