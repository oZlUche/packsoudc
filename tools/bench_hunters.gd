## 猎手校准：木桩对着猎手的每一档打几百场，打印胜率与「规则会给哪一档 / 最接近 50% 的哪一档」（报告 073）。
##
##     godot --headless --path . --script res://tools/bench_hunters.gd -- [猎手 id=hunter_1] [每档场数=200] [木桩=res://data/authoring/calibration/dummies.json] [章节=free_mode] [难度=ascension_1（取它的段位表）]
##
## 工具只做统计，不改数：作者对着表改猎手的强度规则或池的档位表。
extends CliTool


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var hunter_id := StringName(args[0]) if args.size() > 0 else &"hunter_1"
	var fights := int(args[1]) if args.size() > 1 else 200
	var dummies_path: String = args[2] if args.size() > 2 else DummyBuilder.DEFAULT_PATH
	var chapter_id := String(args[3]) if args.size() > 3 else "free_mode"
	var difficulty_id := String(args[4]) if args.size() > 4 else "ascension_1"

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
		for m in (load(dpath) as DifficultyDef).mechanics:
			if m is HunterMechanic:
				brackets = (m as HunterMechanic).bracket_steps.duplicate()
	if not brackets.is_empty():
		print("段位表（难度 %s）：%s；猎手按段位的档位表：%s" % [difficulty_id, str(brackets), str(hunter.strength_by_bracket)])
	var result := HunterBench.run(dummies, hunter, pool, enemies, items, fights, 1, chapter.difficulty if chapter != null else 0, &"", 0.0, brackets)
	print(HunterBench.report_text(result, hunter_id))
	finish(0)
