## 平衡检测方案（2026-11-10）§6.2～§6.4、§7：统计模块对手算的小样本；全胜、全负、全平、单样本、零样本、长尾、缺失事件、重复样本、
## 生成失败各一份夹具；逐场指标；扫表实验（三种抽样）一次落一个目录，CSV / Markdown 来自同一份 summary；参考配装合法性检测
extends RefCounted

const DIR := "user://test_balance_experiment"


static func _near(t: TestCase, got: Variant, want: float, what: String, tol: float = 0.0005) -> void:
	t.check(got != null and absf(float(got) - want) <= tol, "%s：%s ≈ %s" % [what, str(got), str(want)])


static func run_wilson_quantiles(t: TestCase) -> void:
	t.begin("统计：Wilson 区间与分位数（R-7）对手算")
	var w: Dictionary = BalanceStatistics.wilson(8, 10)
	_near(t, w["p"], 0.8, "8/10 点估计")
	_near(t, w["lo"], 0.4902, "8/10 下限")
	_near(t, w["hi"], 0.9433, "8/10 上限")
	var w0: Dictionary = BalanceStatistics.wilson(0, 5)
	_near(t, w0["lo"], 0.0, "0/5 下限")
	_near(t, w0["hi"], 0.4345, "0/5 上限")
	var w5: Dictionary = BalanceStatistics.wilson(5, 5)
	_near(t, w5["lo"], 0.5655, "5/5 下限")
	_near(t, w5["hi"], 1.0, "5/5 上限")
	t.is_null(BalanceStatistics.wilson(0, 0), "零样本：没有比例（不是 0%）")
	var q := BalanceStatistics.quantiles([10, 1, 3, 2, 4])
	t.eq(q["n"], 5, "五个数")
	_near(t, q["p10"], 1.4, "p10")
	_near(t, q["p50"], 3.0, "p50")
	_near(t, q["p90"], 7.6, "p90")
	var one := BalanceStatistics.quantiles([5.0])
	t.check(one["p10"] == 5.0 and one["p50"] == 5.0 and one["p90"] == 5.0, "单样本：三个分位都是它自己")
	var none := BalanceStatistics.quantiles([null, null])
	t.check(none["n"] == 0 and none["p50"] == null, "全是缺失：n 0、分位 null")
	var tail := BalanceStatistics.quantiles([1, 1, 1, 1, 1, 1, 1, 1, 1, 1000])
	_near(t, tail["p50"], 1.0, "长尾：中位数不被拉走")
	_near(t, tail["p90"], 100.9, "长尾：p90 插值")
	t.is_null(BalanceStatistics.mean([]), "空的平均：null")


static func run_bootstrap(t: TestCase) -> void:
	t.begin("统计：配对自助法与按局聚类的自助法")
	var same := BalanceStatistics.paired_bootstrap([[1, 0], [1, 0], [1, 0]])
	t.check(same["n"] == 3 and same["diff"] == 1.0 and same["lo"] == 1.0 and same["hi"] == 1.0, "三对全是 +1：差 1，区间 [1, 1]")
	var mixed := BalanceStatistics.paired_bootstrap([[1, 0], [0, 1], [1, 1], [null, 1]])
	t.eq(mixed["n"], 3, "缺一边的整对丢掉")
	_near(t, mixed["diff"], 0.0, "差值的平均")
	t.check(float(mixed["lo"]) < 0.0 and float(mixed["hi"]) > 0.0, "区间跨过 0")
	t.eq(BalanceStatistics.paired_bootstrap([[1, 0], [0, 1], [1, 1]]), mixed, "同样的对、同样的种子：结果一样")
	t.is_null(BalanceStatistics.paired_bootstrap([])["diff"], "没有对：差值 null")
	var c := BalanceStatistics.cluster_bootstrap([1, 1, 1, 1, 0], ["a", "a", "a", "a", "b"])
	t.check(c["n"] == 5 and c["clusters"] == 2, "五步两局")
	_near(t, c["mean"], 0.8, "全部步的平均")
	t.check(c["lo"] == 0.0 and c["hi"] == 1.0, "按局抽：两局都抽到 b 时是 0，都抽到 a 时是 1（不当五个独立样本）")


static func _row(id: String, outcome: String, dur: float, hp: Array, metrics: Dictionary = {}) -> Dictionary:
	return {"case_id": id, "stage": "", "error": "", "simulated": true, "valid": true, "outcome": outcome, "duration": dur, "hp_end": hp, "metrics": metrics}


static func _fail(id: String, why: String) -> Dictionary:
	return {"case_id": id, "stage": "generate", "error": why, "simulated": false, "valid": false}


static func run_summaries(t: TestCase) -> void:
	t.begin("统计：九份夹具的汇总（全胜、全负、全平、单样本、零样本、长尾、缺失事件、重复、生成失败）")
	var win := BalanceStatistics.summarize([_row("a", "win", 2.0, [0.5, 0.0]), _row("b", "win", 4.0, [0.7, 0.0]), _row("c", "win", 6.0, [0.9, 0.0])])
	t.eq(win["outcomes"]["win"], 3, "全胜：三胜")
	_near(t, win["win_rate"]["p"], 1.0, "全胜：胜率 1")
	_near(t, win["win_rate"]["lo"], 0.4385, "全胜：3/3 的下限")
	_near(t, win["hp_end"][0]["win"]["p50"], 0.7, "全胜：赢时余血中位")
	t.eq(win["hp_end"][0]["loss"]["n"], 0, "全胜：没有输的余血")
	var loss := BalanceStatistics.summarize([_row("a", "loss", 3.0, [0.0, 0.4]), _row("b", "loss", 5.0, [0.0, 0.6])])
	_near(t, loss["win_rate"]["p"], 0.0, "全负：胜率 0（有效场 2）")
	_near(t, loss["hp_end"][1]["loss"]["p50"], 0.5, "全负：输时对方余血中位")
	var draw := BalanceStatistics.summarize([_row("a", "draw", 3.0, [0.0, 0.0]), _row("b", "timeout", 30.0, [0.4, 0.4])])
	t.check(draw["outcomes"]["draw"] == 1 and draw["outcomes"]["timeout"] == 1, "平局和超时分开数")
	_near(t, draw["win_rate"]["p"], 0.0, "全平：胜率 0，平局另列")
	_near(t, draw["draw_rate"]["p"], 0.5, "平局率")
	_near(t, draw["duration"]["timeout"]["p50"], 30.0, "超时的时长单列")
	var single := BalanceStatistics.summarize([_row("a", "win", 7.5, [1.0, 0.0])])
	t.check(single["duration"]["all"]["p10"] == 7.5 and single["duration"]["all"]["p90"] == 7.5, "单样本：分位都是它")
	var zero := BalanceStatistics.summarize([])
	t.check(zero["requested"] == 0 and zero["valid"] == 0 and zero["win_rate"] == null and zero["duration"]["all"]["p50"] == null, "零样本：没有胜率，没有时长")
	var tail_rows: Array = []
	for i in 9:
		tail_rows.append(_row("t%d" % i, "win", 1.0, [1.0, 0.0]))
	tail_rows.append(_row("t9", "timeout", 1000.0, [0.5, 0.5]))
	var tail := BalanceStatistics.summarize(tail_rows)
	_near(t, tail["duration"]["all"]["p50"], 1.0, "长尾：时长中位")
	_near(t, tail["duration"]["all"]["p90"], 100.9, "长尾：时长 p90")
	var miss := BalanceStatistics.summarize([_row("a", "win", 2.0, [0.5, 0.0], {"first_damage": [null, 1.0], "min_hp": [null, null]}),
		_row("b", "win", 2.0, [0.5, 0.0], {"first_damage": [0.5, 1.0], "min_hp": [0.4, 0.0]})])
	_near(t, miss["no_hit"][0]["p"], 0.5, "缺失事件：一场没打出伤害")
	t.eq(miss["first_damage"][0]["n"], 1, "缺失事件：首伤时刻只有一场量得出")
	t.eq(miss["min_hp"][0]["n"], 1, "缺失事件：最低血只有一场量得出（null 不当 0）")
	_near(t, miss["min_hp"][0]["p50"], 0.4, "缺失事件：最低血中位")
	var dup := BalanceStatistics.summarize([_row("a", "win", 2.0, [0.5, 0.0]), _row("a", "win", 2.0, [0.5, 0.0]), _row("b", "loss", 2.0, [0.0, 0.5])])
	t.check(dup["requested"] == 2 and dup["duplicates"] == 1, "重复样本：同一 case 只算一次，另记重复")
	_near(t, dup["win_rate"]["p"], 0.5, "重复样本：胜率 1/2，不是 2/3")
	var bad := BalanceStatistics.summarize([_fail("a", "no_candidate"), _fail("b", "no_candidate"), _fail("c", "enemy_build_failed")])
	t.check(bad["requested"] == 3 and bad["generated"] == 0 and bad["valid"] == 0 and bad["failed"] == 3, "生成失败：请求 3、造出 0、有效 0、失败 3")
	t.is_null(bad["win_rate"], "全失败：没有有效结果（不是 0% 胜率）")
	t.eq(bad["errors"], {"no_candidate": 2, "enemy_build_failed": 1}, "失败原因分开数")
	var part := BalanceStatistics.summarize([_fail("a", "no_candidate"), _row("b", "win", 2.0, [0.5, 0.0])])
	_near(t, part["win_rate"]["p"], 1.0, "失败的不算输：1 胜 1 失败 → 胜率 1/1")


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _spec(ids: Array, hp: float, db: ItemDatabase) -> CombatantSpec:
	var typed: Array[StringName] = []
	for i in ids:
		typed.append(StringName(i))
	return BattleCompiler.compile_board(LootPacker.board_of(typed, Vector2i(5, 5), db), CombatantBaseline.with_hp(hp))


static func run_battle_metrics(t: TestCase) -> void:
	t.begin("逐场指标：手造的事件、真打的一场")
	var r := BattleResult.new()
	r.winner = -1
	r.duration = StatMath.from_float(10.0)
	var m := BattleMetrics.of(r, 10.0)
	t.eq(m["outcome"], BattleMetrics.TIMEOUT, "时限到了都活着：超时")
	t.check(m["first_damage"] == [null, null] and m["min_hp"] == [null, null] and m["hp_end"] == [null, null], "没有事件：量不出来的都是 null")
	t.eq(BattleMetrics.outcome_of(r, 30.0), BattleMetrics.DRAW, "没到时限、没有胜方：平局")
	r.final = {"sides": [{"resources": {"hp": [0, 0]}}, {"resources": {"hp": [50, 100]}}]}
	t.eq(BattleMetrics.of(r, 10.0)["hp_end"], [0.0, 0.5], "生命上限被压到 0（衰竭）：余血记 0，不是量不出来")
	r.final = {}
	var mx := StatMath.from_float(100.0)
	r.log.append(BattleEvent.make(BattleEvent.ITEM_FIRED, StatMath.from_float(1.0), 0, {"uid": 7}))
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, StatMath.from_float(1.0), 1, {"amount": -StatMath.from_float(12.0), "source_side": 0, "uid": 7, "direct": true}))
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, StatMath.from_float(2.0), 1, {"amount": -StatMath.from_float(3.0), "source_side": 0, "uid": 7, "direct": false}))
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, StatMath.from_float(2.0), 1, {"amount": -StatMath.from_float(5.0), "source_side": 0, "uid": 7, "direct": true, "cancelled": true}))
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, StatMath.from_float(3.0), 0, {"amount": -StatMath.from_float(4.0), "source_side": 1, "uid": 0, "direct": true}))
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, StatMath.from_float(4.0), 1, {"amount": -StatMath.from_float(2.0), "source_side": 0, "uid": 9, "pure": true, "direct": true}))
	r.log.append(BattleEvent.make(BattleEvent.RESOURCE_CHANGED, StatMath.from_float(3.0), 0, {"key": "hp", "current": StatMath.from_float(20.0), "max": mx}))
	r.log.append(BattleEvent.make(BattleEvent.RESOURCE_CHANGED, StatMath.from_float(7.0), 0, {"key": "hp", "current": StatMath.from_float(50.0), "max": mx}))
	m = BattleMetrics.of(r, 10.0)
	t.eq(m["fires"], [1, 0], "出手：我方一次")
	_near(t, m["first_damage"][0], 1.0, "我方首伤 1 秒")
	_near(t, m["first_damage"][1], 3.0, "对方首伤 3 秒")
	_near(t, m["damage"][0]["direct"], 12.0, "直接伤害（被取消的不算）")
	_near(t, m["damage"][0]["indirect"], 3.0, "非直接伤害")
	_near(t, m["damage"][0]["true"], 2.0, "真实伤害")
	_near(t, m["damage"][1]["unknown"], 4.0, "来源 uid 0：unknown")
	_near(t, m["damage_by_item"][0]["7"], 15.0, "按道具：7 号 15")
	_near(t, m["min_hp"][0], 0.2, "最低血 20%")
	_near(t, m["first_low_hp"][0], 3.0, "第一次低血 3 秒")
	_near(t, m["low_hp_time"][0], 4.0, "低血 3～7 秒，共 4 秒")
	var db := _items()
	var me := _spec(["longsword", "shortsword"], 100.0, db)
	var foe := _spec(["knife", "salve"], 120.0, db)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var real := BattleSim.run(me, foe, rng, 30.0, null)
	var rm := BattleMetrics.of(real, 30.0)
	t.eq(rm["outcome"] == BattleMetrics.WIN, real.winner == 0, "真打：胜负和结果一样")
	t.check(int(rm["fires"][0]) > 0 and rm["first_damage"][0] != null, "真打：我方出过手、打出过伤害")


static func _cleanup(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_cleanup(dir.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


static func _ctx(mode: String, db: ItemDatabase) -> Dictionary:
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	return {"pool": ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool, "enemies": enemies, "items": db, "mode": mode,
		"fights": 3, "seed": 1, "time_limit": 30.0, "chapter": load(ContentPaths.asset_file("chapters", "free_mode")), "maps": 2, "sets": sets}


static func _dummies() -> Dictionary:
	var all := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var out := {}
	for k in all:
		var d: Dictionary = all[k]
		if int(d.get("bracket", -1)) == 0 and String(d.get("archetype", "")) in ["burst", "blade", "blade+sun"]:
			out[k] = d
	return out


static func run_experiment(t: TestCase) -> void:
	t.begin("扫表实验：三种抽样各跑一小份，逐场一行、失败也一行，目录里的 CSV / Markdown 和 summary 对得上")
	var db := _items()
	var dummies := _dummies()
	t.check(dummies.size() >= 3, "木桩表里有段 0 的 burst / blade / blade+sun（%d 份）" % dummies.size())
	for mode in BalanceExperiment.MODES:
		var ctx := _ctx(mode, db)
		var use := dummies
		if mode == BalanceExperiment.COVERAGE:     # 覆盖测试格子多：一路一场
			ctx["fights"] = 1
			use = {}
			for k in dummies:
				if String(dummies[k]["archetype"]) == "burst":
					use[k] = dummies[k]
		var a := BalanceExperiment.run(use, ctx)
		var cases: Array = a["cases"]
		t.check(not cases.is_empty(), "%s：有场次（%d）" % [mode, cases.size()])
		if mode != BalanceExperiment.COVERAGE:
			var b := BalanceExperiment.run(use, ctx)
			t.eq(JSON.stringify(cases, "", true).sha256_text(), JSON.stringify(b["cases"], "", true).sha256_text(), "%s：同样的种子跑两遍逐场一样" % mode)
		var s := BalanceExperiment.summarize(a)
		var total: Dictionary = s["total"]
		t.eq(int(total["requested"]), cases.size(), "%s：请求 = 行数" % mode)
		t.eq(int(total["requested"]), int(total["valid"]) + int(total["failed"]), "%s：请求 = 有效 + 失败" % mode)
		var bad := 0
		for row in cases:
			var r := row as Dictionary
			if r["source"] != ExperimentManifest.SYNTHETIC or not r.has("rng") or not r.has("pair_id") or not r.has("budget"):
				bad += 1
		t.eq(bad, 0, "%s：每行都标 synthetic，带种子、配对标识、预算" % mode)
		if mode == BalanceExperiment.FREQUENCY:
			t.check(int(s["population"].get("nodes", 0)) > 0, "频率测试：从真生成的地图上取到了点（%d 个）" % int(s["population"].get("nodes", 0)))
			var with_node := cases.filter(func(r: Dictionary) -> bool: return r["valid"] and r["node"] is Dictionary and r["node"].has("map_seed"))
			t.check(not with_node.is_empty(), "频率测试：有效的场记着是哪张图的哪个点")
			var missing := cases.filter(func(r: Dictionary) -> bool: return r["error"] == BalanceExperiment.E_NO_NODE)
			t.check(missing.size() + with_node.size() == cases.size(), "频率测试：图上没有那一档的点就写一行失败，不悄悄丢")
		if mode == BalanceExperiment.COVERAGE:
			var ids := {}
			for row in cases:
				ids[(row as Dictionary)["cell"].get_slice("/", 3)] = true
			t.eq(ids.size(), BalanceExperiment.coverage_targets(ctx["pool"], ctx["enemies"]).size(), "覆盖测试：池里每个敌人都有格")
		if mode == BalanceExperiment.BARE_NODE:
			var specs: Array[CombatantSpec] = []
			var keys: Array = dummies.keys()
			keys.sort()
			for k in keys:
				if String(dummies[k]["archetype"]) == "burst":
					specs.append(DummyBuilder.compile(dummies[k], db))
			var old_cell := BalanceMatrix.cell(specs, ctx["pool"], ctx["enemies"], db, MapNode.new(), 2, 3, 1, 30.0)
			var mine: Dictionary = s["cells"]["burst/0/t2"]
			t.check(int(old_cell["wins"]) == int(mine["outcomes"]["win"]) and int(old_cell["fights"]) == int(mine["valid"]),
				"假节点和旧扫表同一格逐场一样：%d 胜 / %d 场（敌人造一次各路共用不改结果）" % [mine["outcomes"]["win"], mine["valid"]])
			t.check(not (s["pairs"] as Array).is_empty(), "假节点：兵刃变体有配对差")
			var p: Dictionary = (s["pairs"] as Array)[0]
			t.check(int(p["win_diff"]["n"]) > 0, "配对差有对数")
			_cleanup(DIR)
			var manifest := ExperimentManifest.make(ExperimentManifest.SYNTHETIC, {"mode": mode, "fights": 3, "seed": 1, "time_limit": 30.0})
			var files := BalanceExperiment.write(DIR.path_join(String(manifest["experiment_id"])), manifest, a, s, "测试")
			var names := files.map(func(f: String) -> String: return f.get_file())
			for want in ["manifest.json", "seeds.json", "cases.jsonl", "summary.json", "summary.csv", "report.md"]:
				t.check(names.has(want), "目录里有 %s" % want)
			var dir := DIR.path_join(String(manifest["experiment_id"]))
			var lines := FileAccess.get_file_as_string(dir.path_join("cases.jsonl")).strip_edges().split("\n")
			t.eq(lines.size(), cases.size(), "cases.jsonl 一场一行")
			var back = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("summary.json")))
			t.eq(BalanceReport.csv(back), FileAccess.get_file_as_string(dir.path_join("summary.csv")), "summary.csv 就是 summary.json 印出来的")
			t.eq(BalanceReport.markdown(back, manifest, "测试"), FileAccess.get_file_as_string(dir.path_join("report.md")), "report.md 就是 summary.json 印出来的")
			var seeds = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("seeds.json")))
			t.eq((seeds["cases"] as Dictionary).size(), cases.size(), "seeds.json 每场一条")
			_cleanup(DIR)


static func run_scenario_check(t: TestCase) -> void:
	t.begin("参考配装：合法的过、违规的明确拒绝；同样的场景和种子生成一样")
	var db := _items()
	var all := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var key: String = all.keys()[0]
	var good: Dictionary = all[key]
	var ok := ScenarioCheck.problems(good, db)
	t.eq(ok.filter(func(p: String) -> bool: return not p.begins_with(ScenarioCheck.DROPPED)), [] as Array[String], "木桩表第一份：摆得回去、核心件都在")
	var b := ScenarioCheck.budget_of(good, db)
	t.check(int(b["items"]) > 0 and int(b["cells"]) > 0 and int(b["board_cells"]) > 0, "预算记了件数、格子、棋盘格数（重量 %d，价值 %d）" % [b["weight"], b["value"]])
	var unknown := good.duplicate(true)
	(unknown["layout"] as Array).append({"id": "no_such_item", "origin": [0, 0], "rot": 0})
	t.check(ScenarioCheck.problems(unknown, db).has("%s:no_such_item" % ScenarioCheck.UNKNOWN), "不认得的道具")
	var overlap := good.duplicate(true)
	var lay: Array = overlap["layout"]
	lay.append((lay[lay.size() - 1] as Dictionary).duplicate(true))
	t.check(ScenarioCheck.problems(overlap, db).has(ScenarioCheck.ILLEGAL), "两件叠在同一处：摆不回去")
	var core := good.duplicate(true)
	core["core"] = ["longsword", "longsword", "longsword", "longsword"]
	t.check(ScenarioCheck.problems(core, db).has("%s:longsword" % ScenarioCheck.CORE_MISSING), "声明的核心件没放够")
	var dropped := good.duplicate(true)
	dropped["left"] = ["warhammer"]
	t.check(ScenarioCheck.problems(dropped, db).has("%s:warhammer" % ScenarioCheck.DROPPED), "生成器丢掉的件报出来")
	var probs: Array[String] = ["%s:warhammer" % ScenarioCheck.CORE_MISSING, "%s:warhammer" % ScenarioCheck.DROPPED, "%s:longsword" % ScenarioCheck.CORE_MISSING]
	t.eq(ScenarioCheck.blocking(probs, false), probs, "不放过丢件：三条都挡")
	t.eq(ScenarioCheck.blocking(probs, true), ["%s:longsword" % ScenarioCheck.CORE_MISSING] as Array[String], "放过丢件：丢的那件连带的核心件也不挡，别的核心件照挡")
	var cap := good.duplicate(true)
	cap["budget"] = {"cells": 1}
	t.check(ScenarioCheck.problems(cap, db).has("%s:cells" % ScenarioCheck.OVER_BUDGET), "超出声明的格子预算")
	t.check(ScenarioCheck.problems(good, db, 1).any(func(p: String) -> bool: return p.begins_with(ScenarioCheck.OVERWEIGHT)), "超重")
	var uniq := ""
	for id in db.all_ids():
		if db.get_def(id).is_unique() and not db.get_def(id).is_bag:
			uniq = String(id)
			break
	if uniq != "":
		var twice := {"board_size": [8, 6], "requires_bag": false, "layout": [{"id": uniq, "origin": [0, 0], "rot": 0}, {"id": uniq, "origin": [4, 3], "rot": 0}]}
		t.check(ScenarioCheck.problems(twice, db).has("%s:%s" % [ScenarioCheck.UNIQUE_REPEAT, uniq]), "独一的放了两件")
	var pool := ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var hero: CharacterDef = ContentPaths.load_asset("characters", String(ArchetypeBuilder.CHARACTER)) as CharacterDef
	var one := ArchetypeBuilder.one(&"burst", 1, 0, pool, db, hero, false)
	var two := ArchetypeBuilder.one(&"burst", 1, 0, pool, db, hero, false)
	t.eq(ExperimentManifest.canonical_hash(one), ExperimentManifest.canonical_hash(two), "同样的流派、段、种子：生成一样")
