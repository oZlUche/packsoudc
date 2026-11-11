## 难度候选实验（报告 303，材料与难度方案 §7.2 D1 / D3）：基线和每个改数用同一批种子各跑一遍，逐场配对出候选表。只出表，不改数。
##
##     godot --headless --path . --script res://tools/difficulty_candidates.gd -- --exp=D1|D3 [--fights=100] [--maps=20] [--seed=1] [--pool=standard_ruins] [--difficulty=ascension_3] [--out=路径.md]
extends CliTool


func run() -> void:
	var opts: Dictionary = split_args(OS.get_cmdline_user_args())["opts"]
	var exp_id := String(opts.get("exp", "D1"))
	if not DifficultyCandidates.EXPERIMENTS.has(exp_id):
		print("不认识的实验 %s（有 %s）" % [exp_id, ", ".join(DifficultyCandidates.EXPERIMENTS.keys())])
		finish(1)
		return
	var pool_id := String(opts.get("pool", "standard_ruins"))
	var difficulty_id := String(opts.get("difficulty", "ascension_3"))
	var fights := int(opts.get("fights", "100"))
	var seed_ := int(opts.get("seed", "1"))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var pool := ContentPaths.load_asset("enemy_pools", pool_id) as EnemyPool
	var dummies := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var rules := ContentPaths.load_asset("node_rules", "standard") as NodeRules
	var ctx := {"pool": pool, "enemies": enemies, "items": items, "fights": fights, "seed": seed_,
		"time_limit": rules.battle_time_limit, "overtime": rules.overtime, "chapter": BalanceExperiment.chapter_for_pool(pool_id),
		"maps": int(opts.get("maps", "20")), "difficulty": ContentPaths.load_asset("difficulties", difficulty_id), "sets": sets}
	var started := Time.get_ticks_msec()
	var runs := DifficultyCandidates.run_all(exp_id, dummies, ctx)
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	var header: Array[String] = [
		"日期 %s；木桩 `%s`（%d 份）；敌人池 `%s`，难度 `%s`；%s 抽样，每格 %d 场，种子 %d%s；共用 %.0f 秒。" % [
			Time.get_date_string_from_system(), ArchetypeBuilder.DEFAULT_PATH, dummies.size(), pool_id, difficulty_id,
			DifficultyCandidates.EXPERIMENTS[exp_id]["mode"], fights, seed_,
			"，%d 张图" % ctx["maps"] if DifficultyCandidates.EXPERIMENTS[exp_id]["mode"] == "frequency" else "", secs],
		"改数：%s" % JSON.stringify(DifficultyCandidates.EXPERIMENTS[exp_id]["variants"]),
	]
	var md := DifficultyCandidates.markdown(exp_id, runs, header)
	var out := String(opts.get("out", ""))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		if not write_text(out, md):
			return
		print("写好了 " + out)
	else:
		print(md)
	finish(0)
