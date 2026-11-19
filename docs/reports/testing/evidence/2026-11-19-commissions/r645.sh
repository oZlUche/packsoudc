#!/bin/bash
P=/home/user/packsoudc; cd $P; git log --oneline -1
[ "$NOIMPORT" = 1 ] || { timeout 900 godot --headless --path $P --import > /tmp/claude-0/import557.log 2>&1; echo import=$?; }
B=/mnt/project-files/testing/2026-11-19-v659; T=/mnt/project-files/testing
mkdir -p $B; U=~/.local/share/godot/app_userdata/背包搜打撤
clean(){ rm -rf "${U:?}/slots" "${U:?}"/settings.json* "${U:?}"/meta.json* "${U:?}"/run*.json* "${U:?}/diagnostics" "${U:?}/calibration" "${U:?}/battle_logs"; }
cfg(){ mkdir -p "$U"; echo "{\"version\":1,\"language\":\"$1\",\"text_size\":\"$2\"}" > "$U/settings.json"; }
run1(){ LS=$1; K=$2; shift 2; clean; cfg ${LS%_*} ${LS#*_}; D=$B/$LS/$K; mkdir -p $D; timeout 1500 /tmp/claude-0/xr.sh $P $T/${K%%-*}.gd $D "$@" > $D/run.log 2>&1; echo "$K $LS=$? err=$(grep -c 'SCRIPT ERROR' $D/run.log) ERROR=$(grep -E '^(USER )?ERROR:' $D/run.log | grep -v 'audio_driver\|status < 0\|leaked\|RenderingServer::get_singleton\|resources still in use\|RID allocations\|never freed\|PagedAllocator' | wc -l) WARN=$(grep -c '^WARNING' $D/run.log)"; }
for w in $WALKS; do run1 ${w%%:*} $(echo ${w#*:} | tr ',' ' '); done; clean
[ "$SUITE" = 1 ] || exit 0
timeout 900 godot --headless --path $P --script res://tools/check_balance_scenarios.gd -- --out=$B/scenarios.md > $B/scenarios.log 2>&1; echo scen=$?; tail -2 $B/scenarios.log
timeout 900 godot --headless --path $P --script res://tools/check_balance_scenarios.gd -- --allow-dropped > $B/scenarios_allow.log 2>&1; echo scen_allow=$?
(time bash tools/test.sh) > /tmp/claude-0/suite557.log 2>&1; echo EXIT=$?; grep "通过" /tmp/claude-0/suite557.log; echo "SCRIPT ERROR $(grep -c 'SCRIPT ERROR' /tmp/claude-0/suite557.log)"; grep -n "意料之外" -A6 /tmp/claude-0/suite557.log | head -8
TMPDIR=/tmp/claude-0 timeout 900 bash tools/warnings.sh /tmp/claude-0/warn557.jsonl > /tmp/claude-0/warn557.txt 2>&1; grep "共" /tmp/claude-0/warn557.txt
