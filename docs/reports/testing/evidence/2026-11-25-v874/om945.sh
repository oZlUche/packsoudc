#!/bin/bash
# 用法：os896.sh <mode> <outdir> [stash]   mode=make_free|make_tut 在跑完后把 user 目录存到 stash；check 先从 stash 还原
U=~/.local/share/godot/app_userdata/背包搜打撤; P=/home/user/packsoudc; S=/tmp/claude-0/scripts
M=$1; D=$2; ST=$3; LS=${LS:-zh_normal}; mkdir -p $D
rm -rf "${U:?}"; mkdir -p "$U"
if [ "$M" = check ]; then cp -a "$ST/." "$U/"; else echo "{\"version\":1,\"language\":\"${LS%_*}\",\"text_size\":\"${LS#*_}\"}" > "$U/settings.json"; fi
timeout 900 xvfb-run -a -s "-screen 0 1920x1200x24" godot --path $P --rendering-driver opengl3 --script $S/om945.gd -- $D $M $REP $WAS > $D/om945-$M-$TAGX.log 2>&1; echo "$M=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' $D/om945-$M-$TAGX.log)"
if [ "$M" != check ]; then rm -rf "$ST"; mkdir -p "$ST"; cp -a "$U/." "$ST/"; fi
