## 平衡检测方案（2026-11-10）§7：参考配装（木桩表）的合法性检测 —— 道具都在、摆得回去、独一的不重复、核心件都放进去了、
## 生成器丢掉的件报出来、超没超声明的预算和角色的负重。再把流派木桩按同样的种子重造一遍，看是不是一模一样。
##
##     godot --headless --path . --script res://tools/check_balance_scenarios.gd -- [木桩=res://data/authoring/calibration/archetypes.json]
##         [--pool=standard_ruins] [--difficulty=ascension_3] [--character=marcus] [--allow-dropped] [--out=<报告 .md>]
##
## 退出码：0 全部合法；1 用法或读写错误；2 有不合法的（生成器丢件默认也算，加 --allow-dropped 降为提示）
extends CliTool


func run() -> void:
	var split := split_args(OS.get_cmdline_user_args())
	var pos: Array[String] = split["pos"]
	var opts: Dictionary = split["opts"]
	var path: String = pos[0] if pos.size() > 0 else ArchetypeBuilder.DEFAULT_PATH
	var dummies := DummyBuilder.load_file(path)
	if dummies.is_empty():
		print("读不到木桩：" + path)
		finish(1)
		return
	var items := ItemDatabase.new()
	items.load_dir()
	var character := ContentPaths.load_asset("characters", String(opts.get("character", ArchetypeBuilder.CHARACTER))) as CharacterDef
	var cap := character.weight_capacity if character != null else 0
	var res := ScenarioCheck.check_all(dummies, items, cap)
	var allow_dropped := opts.has("allow-dropped")
	var hard := 0
	var lines: Array[String] = ["# 参考配装检测", "", "- 木桩 `%s`，%d 份；角色 `%s`（负重 %d）" % [path, dummies.size(), opts.get("character", ArchetypeBuilder.CHARACTER), cap], ""]
	lines.append("| 木桩 | 件数 | 包 | 占格 / 棋盘 | 重量 | 价值 | 问题 |")
	lines.append("|---|---:|---:|---|---:|---:|---|")
	for k in res["rows"]:
		var row: Dictionary = res["rows"][k]
		var b: Dictionary = row["budget"]
		var probs: Array[String] = row["problems"]
		var blocking := probs.filter(func(p: String) -> bool: return not (allow_dropped and p.begins_with(ScenarioCheck.DROPPED)))
		if not blocking.is_empty():
			hard += 1
		lines.append("| %s | %d | %d | %d / %d | %d | %d | %s |" % [k, b["items"], b["bags"], b["cells"], b["board_cells"], b["weight"], b["value"],
			"，".join(probs) if not probs.is_empty() else "—"])
	lines.append("")
	var same := _rebuild(dummies, opts, items, character)
	lines.append("重造：%s" % same["text"])
	lines.append("")
	lines.append("合法 %d 份，有问题 %d 份（其中挡住的 %d 份）。" % [res["legal"], res["illegal"], hard])
	var md := "\n".join(lines) + "\n"
	print(md)
	if opts.has("out"):
		var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
		if f == null:
			print("写不了 " + String(opts["out"]))
			finish(1)
			return
		f.store_string(md)
		f.close()
	finish(2 if hard > 0 or not bool(same["ok"]) else 0)


## 流派木桩（五路，键是「流派/段/种子」）按同样的池、段位、种子重造一份，和表里的逐份比；兵刃变体与真实木桩不重造（另有来路）
func _rebuild(dummies: Dictionary, opts: Dictionary, items: ItemDatabase, character: CharacterDef) -> Dictionary:
	var pool := ContentPaths.load_asset("enemy_pools", String(opts.get("pool", "standard_ruins"))) as EnemyPool
	if pool == null:
		return {"ok": false, "text": "没有敌人池 %s" % opts.get("pool", "standard_ruins")}
	var brackets := BalanceMatrix.brackets_of(String(opts.get("difficulty", "ascension_3")))
	var fresh := ArchetypeBuilder.build(pool, items, brackets, character)
	var checked := 0
	var differ: Array[String] = []
	for k in fresh:
		if not dummies.has(k):
			continue
		checked += 1
		var a: Dictionary = (dummies[k] as Dictionary).duplicate(true)
		var b: Dictionary = JSON.parse_string(JSON.stringify(fresh[k]))     # 读回的表里整数都成了浮点：新造的也过一遍 JSON 再比
		for drop in ["hp", "dps"]:     # 读数跟着战斗规则走，规则改了会变；比的是配装本身
			a.erase(drop)
			b.erase(drop)
		if ExperimentManifest.canonical_hash(a) != ExperimentManifest.canonical_hash(b):
			differ.append(String(k))
	if checked == 0:
		return {"ok": true, "text": "表里没有五路流派木桩，没有重造"}
	if differ.is_empty():
		return {"ok": true, "text": "%d 份流派木桩按同样的种子重造，和表里一模一样" % checked}
	return {"ok": false, "text": "%d 份里 %d 份重造出来不一样：%s（内容改过就该重跑 tools/build_archetypes.gd）" % [checked, differ.size(), "，".join(differ.slice(0, 8))]}
