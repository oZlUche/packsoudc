## 常规事件分布（报告 303）：两张图各开 N 局（种子 1..N），数各事件出现几处、几张图有、一张图最多几处。
##
##     godot --headless --path . --script res://tools/event_distribution.gd -- [--n=100] [--out=路径.md]
##
## 有上限的事件（节点规则 event_max_per_map）超了、地图专属的串到别的图，就退出 1
extends CliTool

const CHAPTERS := ["free_mode", "clockwork_hourglass"]


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var n := int(opts.get("n", "100"))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var seeds: Array = []
	for i in n:
		seeds.append(i + 1)
	var md := "# 常规事件分布\n\n每章种子 1..%d，只数生成时定进节点的事件（随机点揭开时现配的不算）。\n\n" % n
	var bad: Array[String] = []
	var own := {}
	for ch_id in CHAPTERS:
		var ch := ContentPaths.load_asset("chapters", ch_id) as ChapterDef
		for type in ch.chapter_events:
			for eid in ch.chapter_events[type]:
				own[String(eid)] = ch_id
	for ch_id in CHAPTERS:
		var ch := ContentPaths.load_asset("chapters", ch_id) as ChapterDef
		var rules := (ContentPaths.load_asset("node_rules", String(ch.node_rules)) as NodeRules)
		var r := EventDistribution.survey(ch, items, enemies, seeds)
		md += EventDistribution.markdown(ch_id, r) + "\n"
		for eid in r["events"]:
			var cap := int(rules.event_max_per_map.get(String(eid), -1))
			if cap >= 0 and int(r["events"][eid]["max"]) > cap:
				bad.append("%s：%s 一张图 %d 处，上限 %d" % [ch_id, eid, r["events"][eid]["max"], cap])
			if own.has(String(eid)) and own[String(eid)] != ch_id:
				bad.append("%s：出现了 %s 专属的 %s" % [ch_id, own[String(eid)], eid])
	var out := String(opts.get("out", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
			f.close()
			print("写好了 " + out)
	else:
		print(md)
	for line in bad:
		print("!! " + line)
	finish(1 if not bad.is_empty() else 0)
