#!/bin/bash
P=/home/user/packsoudc; T=/mnt/project-files/testing; B=$T/2026-11-18-v644-F
U=~/.local/share/godot/app_userdata/背包搜打撤
cd $P; git log --oneline -1
cl(){ rm -rf "${U:?}/slice" "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/battle_logs" "${U:?}/diagnostics" "${U:?}/calibration"; }
for LS in ${COMBOS:-zh_normal zh_large en_normal en_large}; do
 for PR in ${PROFILES:-normal slice}; do
  for M in ${MODES:-tutA tutB tutC}; do
   cl
   if [ $PR = slice ]; then SD="$U/slice"; EXTRA=--profile=slice; else SD="$U"; EXTRA=; fi
   mkdir -p "$SD"; echo "{\"version\":1,\"language\":\"${LS%_*}\",\"text_size\":\"${LS#*_}\"}" > "$SD/settings.json"
   if [ $M = tutL ]; then mkdir -p "$SD/slots/1"; python3 -c "import json;d=json.load(open('$P/tests/fixtures/meta_v4.json'));d.update(runs=3,extractions=2,deaths=1,funds=300);json.dump(d,open('$SD/slots/1/meta.json','w'))"; fi
   D=$B/$LS/$PR-$M; rm -rf $D; mkdir -p $D
   timeout 2400 /tmp/claude-0/xr.sh $P $T/s3.gd $D/probe.csv 1 $M $EXTRA > $D/run.log 2>&1
   echo "$LS $PR $M rc=$? err=$(grep -c 'SCRIPT ERROR' $D/run.log) shots=$(ls $D/*.png 2>/dev/null | wc -l) end=$(grep -c 'F643 三段都通了\|F643 走完\|F644 暂停菜单没有' $D/run.log)"
   ffmpeg -loglevel error -y -framerate 12 -i $D/frames/%06d.jpg -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p -crf 30 $D/$M.mp4 && rm -rf $D/frames
  done
 done
done
cl
