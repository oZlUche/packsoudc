#!/bin/bash
SUITE=1 WALKS="" bash /tmp/claude-0/r645.sh > /tmp/claude-0/suite650.out 2>&1
echo "== suite"; grep "EXIT\|通过\|SCRIPT ERROR\|共 \|scen" /tmp/claude-0/suite650.out
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; T=/mnt/project-files/testing; B=$T/2026-11-19-v650; S=/tmp/claude-0/scripts
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
for LS in zh_normal en_large; do for M in setup gods ui; do
  cl; cfg "$U" ${LS%_*} ${LS#*_}; D=$B/$M-$LS; rm -rf $D; mkdir -p $D
  timeout 1500 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/faith645.gd -- $D $M > $D/run.log 2>&1; echo "$M $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run.log)"; grep "F645\|SCRIPT ERROR" $D/run.log | grep -v "屏 META"
done; done
V=644; O=/tmp/claude-0/old644; cl; cfg "$U" zh normal; D=$B/old644-normal; mkdir -p $D
timeout 600 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $O --rendering-driver opengl3 --script $S/oldmake645.gd -- "" > $D/make.log 2>&1; grep OLD $D/make.log
timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/faith645.gd -- $D old > $D/run.log 2>&1; echo "old=$?"; grep "F645" $D/run.log | grep -v "屏 META"
cl
COMBOS=zh_normal PROFILES="normal slice" MODES=tutA /tmp/claude-0/tutF45.sh 2>&1 | grep "rc="
COMBOS=en_large PROFILES=normal MODES=tutA /tmp/claude-0/tutF45.sh 2>&1 | grep "rc="
for d in $B/*/*-tutA; do echo "== $d"; grep -h "F645\|神坛\|献祭\|特殊操作\|三段都通\|perf_probe 结束\|SCRIPT ERROR" $d/run.log | grep -v "时：选" | cut -c1-330; done
