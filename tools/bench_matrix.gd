## 扫表（242 §8.1 第 2 项）：木桩 × 敌人池每一档，每格 N 场，四张表写成 markdown。
##
##     godot --headless --path . --script res://tools/bench_matrix.gd -- [木桩=res://data/authoring/calibration/archetypes.json] [池=standard_ruins] [难度=ascension_3] [每格场数=300] [种子=1] [输出=docs/reports/balance/<日期>-<池>.md]
##
## 时限与加时按 standard 节点规则（和一局里的战斗一样）。难度只定段位表的表头（木桩自己带段号；敌人强度按档扫全）。
##
## 加 `--out-dir=<目录>` 改出逐场实验目录（[BalanceExperiment]：manifest、seeds、cases.jsonl、summary.json / csv、report.md、异常场的诊断包），
## 不再写旧的四张表；`--mode=coverage|frequency|bare_node`（默认 bare_node），频率测试另有 `--maps=<几张图，默认 20>`、`--chapter=<章节 id>`
## （默认用这个池的那一章）。这时难度会用来开局（频率测试的地图按这个难度放敌人）。
## 只打印，不改数：作者对着表改敌人 / 档位表 / 道具的 json，再跑一遍。
extends CliTool

const NODE_RULES := "standard"


func run() -> void:
	var split := split_args(OS.get_cmdline_user_args())
	var args: Array[String] = split["pos"]
	var opts: Dictionary = split["opts"]
	var dummies_path: String = args[0] if args.size() > 0 else ArchetypeBuilder.DEFAULT_PATH
	var pool_id: String = args[1] if args.size() > 1 else "standard_ruins"
	var difficulty_id: String = args[2] if args.size() > 2 else "ascension_3"
	var fights := int(args[3]) if args.size() > 3 else 300
	var seed_ := int(args[4]) if args.size() > 4 else 1
	var date := Time.get_date_string_from_system()
	var out_path: String = args[5] if args.size() > 5 else "%s/%s-%s.md" % [BalanceMatrix.OUT_DIR, date, pool_id]

	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := ContentPaths.load_asset("enemy_pools", pool_id) as EnemyPool
	if pool == null:
		print("没有敌人池 %s" % pool_id)
		finish(1)
		return
	var dummies := DummyBuilder.load_file(dummies_path)
	if dummies.is_empty():
		print("没有木桩（%s）：先跑 tools/build_archetypes.gd" % dummies_path)
		finish(1)
		return
	var rules := ContentPaths.load_asset("node_rules", NODE_RULES) as NodeRules
	var limit := rules.battle_time_limit if rules != null else BattleSim.DEFAULT_TIME_LIMIT
	var started := Time.get_ticks_msec()
	if opts.has("out-dir"):
		finish(_experiment(opts, dummies, dummies_path, pool, pool_id, difficulty_id, enemies, items, fights, seed_, limit, rules.overtime if rules != null else null, date))
		return
	var result := BalanceMatrix.run(dummies, pool, enemies, items, fights, seed_, limit, rules.overtime if rules != null else null)
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	var header: Array[String] = [
		"日期 %s，git %s" % [date, _git_hash()],
		"木桩 `%s`（%d 份）" % [dummies_path, dummies.size()],
		"敌人池 `%s`，难度 `%s`（段位表 %s），节点规则 `%s`（时限 %.0f 秒）" % [pool_id, difficulty_id, str(BalanceMatrix.brackets_of(difficulty_id)), NODE_RULES, limit],
		"每格 %d 场，种子 %d，共用 %.0f 秒" % [fights, seed_, secs],
	]
	var md := BalanceMatrix.markdown(result, "扫表 %s · %s" % [date, pool_id], header)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if not write_text(out_path, md):
		return
	print(md)
	print("写入 %s" % out_path)
	finish(0)


func _experiment(opts: Dictionary, dummies: Dictionary, dummies_path: String, pool: EnemyPool, pool_id: String, difficulty_id: String,
		enemies: EnemyDatabase, items: ItemDatabase, fights: int, seed_: int, limit: float, overtime: OvertimeRules, date: String) -> int:
	var mode := String(opts.get("mode", BalanceExperiment.BARE_NODE))
	if not BalanceExperiment.MODES.has(mode):
		print("不认识的抽样：%s（有 %s）" % [mode, ", ".join(BalanceExperiment.MODES)])
		return 1
	var chapter_id := String(opts.get("chapter", ""))
	var chapter: ChapterDef = ContentPaths.load_asset("chapters", chapter_id) as ChapterDef if chapter_id != "" else BalanceExperiment.chapter_for_pool(pool_id)
	if mode == BalanceExperiment.FREQUENCY and chapter == null:
		print("频率测试要一章（池 %s 没有对应的章节；用 --chapter=）" % pool_id)
		return 1
	var sets := SetDatabase.new()
	sets.load_dir()
	var ctx := {"pool": pool, "enemies": enemies, "items": items, "mode": mode, "fights": fights, "seed": seed_, "time_limit": limit, "overtime": overtime,
		"chapter": chapter, "maps": int(opts.get("maps", 20)), "difficulty": ContentPaths.load_asset("difficulties", difficulty_id), "sets": sets}
	var config := {"tool": "bench_matrix", "mode": mode, "dummies": dummies_path, "pool": pool_id, "difficulty": difficulty_id,
		"chapter": String(chapter.id) if chapter != null else "", "maps": ctx["maps"] if mode == BalanceExperiment.FREQUENCY else null,
		"fights": fights, "seed": seed_, "time_limit": limit, "node_rules": NODE_RULES}
	var started := Time.get_ticks_msec()
	var done := BalanceExperiment.execute(dummies, ctx, config, String(opts["out-dir"]), "扫表实验 %s · %s · %s" % [date, pool_id, mode])
	if (done["files"] as Array).is_empty():
		print("写不了 " + String(done["dir"]))
		return 1
	var t: Dictionary = done["summary"]["total"]
	print("%s：请求 %d、有效 %d、失败 %d，%.0f 秒 → %s" % [mode, t["requested"], t["valid"], t["failed"], (Time.get_ticks_msec() - started) / 1000.0, done["dir"]])
	return 0


static func _git_hash() -> String:
	var out: Array = []
	if OS.execute("git", ["rev-parse", "--short", "HEAD"], out) != 0 or out.is_empty():
		return "?"
	return String(out[0]).strip_edges()
