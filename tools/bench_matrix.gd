## 扫表（242 §8.1 第 2 项）：木桩 × 敌人池每一档，每格 N 场，四张表写成 markdown。
##
##     godot --headless --path . --script res://tools/bench_matrix.gd -- [木桩=res://data/authoring/calibration/archetypes.json] [池=standard_ruins] [难度=ascension_3] [每格场数=300] [种子=1] [输出=docs/reports/balance/<日期>-<池>.md]
##
## 时限与加时按 standard 节点规则（和一局里的战斗一样）。难度只定段位表的表头（木桩自己带段号；敌人强度按档扫全）。
## 只打印，不改数：作者对着表改敌人 / 档位表 / 道具的 json，再跑一遍。
extends CliTool

const NODE_RULES := "standard"


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var dummies_path: String = args[0] if args.size() > 0 else ArchetypeBuilder.DEFAULT_PATH
	var pool_id: String = args[1] if args.size() > 1 else "standard_ruins"
	var difficulty_id: String = args[2] if args.size() > 2 else "ascension_3"
	var fights := int(args[3]) if args.size() > 3 else 300
	var seed := int(args[4]) if args.size() > 4 else 1
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
	var result := BalanceMatrix.run(dummies, pool, enemies, items, fights, seed, limit, rules.overtime if rules != null else null)
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	var header: Array[String] = [
		"日期 %s，git %s" % [date, _git_hash()],
		"木桩 `%s`（%d 份）" % [dummies_path, dummies.size()],
		"敌人池 `%s`，难度 `%s`（段位表 %s），节点规则 `%s`（时限 %.0f 秒）" % [pool_id, difficulty_id, str(BalanceMatrix.brackets_of(difficulty_id)), NODE_RULES, limit],
		"每格 %d 场，种子 %d，共用 %.0f 秒" % [fights, seed, secs],
	]
	var md := BalanceMatrix.markdown(result, "扫表 %s · %s" % [date, pool_id], header)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		print("写不了 " + out_path)
		finish(1)
		return
	f.store_string(md)
	f.close()
	print(md)
	print("写入 %s" % out_path)
	finish(0)


static func _git_hash() -> String:
	var out: Array = []
	if OS.execute("git", ["rev-parse", "--short", "HEAD"], out) != 0 or out.is_empty():
		return "?"
	return String(out[0]).strip_edges()
