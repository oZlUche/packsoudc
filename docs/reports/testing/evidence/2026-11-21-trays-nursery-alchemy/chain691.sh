#!/bin/bash
# v6.91：v6.85 写旧档 → 拉 main → 全量 + 炼金走查（new）+ 旧档读（old）
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; B=/mnt/project-files/testing/2026-11-21-v691; S=/tmp/claude-0/scripts; K=/tmp/claude-0/old685
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
cfg(){ mkdir -p "$1"; echo "{\"version\":1,\"language\":\"$2\",\"text_size\":\"$3\"}" > "$1/settings.json"; }
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path "$@"; }
COMBOS=${COMBOS:-zh_normal en_large zh_large}
cd $P; git log --oneline -1
[ -n "$NOMAKE" ] || for LS in ${MAKECOMBOS:-$COMBOS}; do
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X /tmp/claude-0/v685 --rendering-driver opengl3 --script $S/smith735.gd -- $D/make_old > $D/make_old685.log 2>&1; echo "make $LS=$?"
  rm -rf "${K:?}/$LS"; mkdir -p "$K/$LS"; cp -r "$U/slots" "$U/settings.json" "$K/$LS"/
  grep -rho '"version": *[0-9]*' "$K/$LS/slots" | sort | uniq -c | head -3
done
git fetch -q origin main; git merge -q --ff-only origin/main; git log --oneline -1
timeout 900 godot --headless --path $P --import > /dev/null 2>&1; echo "import=$?"
sed -i "s#^B=.*#B=$B; T=/mnt/project-files/testing#" /tmp/claude-0/r645.sh
[ -n "$NOSUITE" ] || SUITE=1 WALKS="" bash /tmp/claude-0/r645.sh
for LS in $COMBOS; do
  D=$B/walk-$LS; mkdir -p $D
  cl; cfg "$U" ${LS%_*} ${LS#*_}
  X $P --rendering-driver opengl3 --script $S/alch691.gd -- $D new > $D/run_alch_new.log 2>&1; echo "alch new $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_alch_new.log)"
  cl; cp -r "$K/$LS"/. "$U"/
  X $P --rendering-driver opengl3 --script $S/alch691.gd -- $D old > $D/run_alch_old.log 2>&1; echo "alch old $LS=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/run_alch_old.log)"
  grep -rho '"version": *[0-9]*' "$U/slots" | sort | uniq -c | head -3
done
cl
