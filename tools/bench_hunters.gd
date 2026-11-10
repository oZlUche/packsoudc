## 猎手校准：木桩对着猎手的每一档打几百场，打印胜率与「规则会给哪一档 / 最接近 50% 的哪一档」（报告 073）。
##
##     godot --headless --path . --script res://tools/bench_hunters.gd -- [猎手 id=hunter_1] [每档场数=200] [木桩=res://data/authoring/calibration/dummies.json] [章节=free_mode] [难度=ascension_3（取它的段位表；241 后猎手在难度Ⅲ）]
##
## 工具只做统计，不改数：作者对着表改猎手的强度规则或池的档位表。
## 加 `--out-dir=<目录>` 改出逐场实验目录（和扫表同一种格式，[BalanceExperiment] 的假节点抽样），summary 里多一节每段的 wanted / best。
extends CliTool


func run() -> void:
	var split := split_args(OS.get_cmdline_user_args())
	var args: Array[String] = split["pos"]
	var opts: Dictionary = split["opts"]
	var hunter_id := StringName(args[0]) if args.size() > 0 else &"hunter_1"
	var fights := int(args[1]) if args.size() > 1 else 200
	var dummies_path: String = args[2] if args.size() > 2 else DummyBuilder.DEFAULT_PATH
	var chapter_id := String(args[3]) if args.size() > 3 else "free_mode"
	var difficulty_id := String(args[4]) if args.size() > 4 else "ascension_3"

	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var hunters := HunterSystem.load_all()
	var hunter: HunterDef = hunters.get(hunter_id, null)
	if hunter == null:
		print("找不到猎手 %s（有：%s）" % [hunter_id, ", ".join(hunters.keys())])
		finish(1)
		return
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", chapter_id))
	var pool_id: StringName = hunter.enemy_pool if hunter.enemy_pool != &"" else (chapter.enemy_pool if chapter != null else &"")
	var pool: EnemyPool = load(ContentPaths.asset_file("enemy_pools", String(pool_id))) if pool_id != &"" else null
	if pool == null:
		print("没有敌人池")
		finish(1)
		return
	var dummies := DummyBuilder.load_file(dummies_path)
	if dummies.is_empty():
		print("没有木桩（%s）：先跑 tools/build_dummies.gd" % dummies_path)
		finish(1)
		return
	var brackets: Array[int] = []
	var dpath := ContentPaths.asset_file("difficulties", difficulty_id)
	if ResourceLoader.exists(dpath):
		brackets = (load(dpath) as DifficultyDef).hunter_bracket_steps()
	if not brackets.is_empty():
		print("段位表（难度 %s）：%s；猎手按段位的档位表：%s" % [difficulty_id, str(brackets), str(hunter.strength_by_bracket)])
	if opts.has("out-dir"):
		var node := MapNode.new()
		node.type = &"battle"
		var wanted := {}
		for k in dummies:
			var d: Dictionary = dummies[k]
			wanted[str(int(d.get("bracket", int(String(k)))))] = HunterBench.wanted_of(d, hunter, pool, node, chapter.difficulty if chapter != null else 0, &"", 0.0, brackets)
		var ctx := {"pool": pool, "enemies": enemies, "items": items, "mode": BalanceExperiment.BARE_NODE, "fights": fights, "seed": 1,
			"time_limit": BattleSim.DEFAULT_TIME_LIMIT}
		var config := {"tool": "bench_hunters", "mode": BalanceExperiment.BARE_NODE, "hunter": String(hunter_id), "pool": String(pool_id),
			"dummies": dummies_path, "chapter": chapter_id, "difficulty": difficulty_id, "fights": fights, "seed": 1, "time_limit": BattleSim.DEFAULT_TIME_LIMIT}
		var done := BalanceExperiment.execute(dummies, ctx, config, String(opts["out-dir"]), "猎手实验 %s · %s" % [hunter_id, pool_id],
			func(sm: Dictionary) -> void: HunterBench.decorate(sm, wanted))
		if (done["files"] as Array).is_empty():
			print("写不了 " + String(done["dir"]))
			finish(1)
			return
		print("请求 %d、有效 %d、失败 %d → %s" % [done["summary"]["total"]["requested"], done["summary"]["total"]["valid"], done["summary"]["total"]["failed"], done["dir"]])
		finish(0)
		return
	var result := HunterBench.run(dummies, hunter, pool, enemies, items, fights, 1, chapter.difficulty if chapter != null else 0, &"", 0.0, brackets)
	print(HunterBench.report_text(result, hunter_id))
	finish(0)
