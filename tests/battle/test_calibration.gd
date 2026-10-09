## 校准工具（069 第 4 步，报告 073）：记录快照、按段生成木桩、木桩对猎手各档打的胜率表。
## 断言只针对机制：读回来的等于记进去的、段号按段长、木桩是段里离平均最近的那份、胜率在 0～1、best 是离 50% 最近的档。
extends RefCounted

const SNAPS := "user://test_calibration_snapshots.jsonl"
const DUMMIES := "user://test_calibration_dummies.json"


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["loadouts", "hunter_defs"])


static func _cleanup() -> void:
	for p in [SNAPS, DUMMIES]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _start(c: TestSupport.Content, kit: Array[StringName]) -> RunState:
	for seed in range(1, 40):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func run_record_and_build(t: TestCase) -> void:
	t.begin("校准 · 每步记一份快照，读回来一样；按段长分段，每段一个木桩 = 离平均最近的那份")
	_cleanup()
	var c := _content()
	var kit: Array[StringName] = c.loadouts[0].items if not c.loadouts.is_empty() else [&"bag_leather", &"pistol"] as Array[StringName]
	var s := _start(c, kit)
	t.not_null(s, "开局")
	if s == null:
		return
	var rec := CalibrationRecorder.new(SNAPS)
	var snap := CalibrationRecorder.snapshot(s)
	t.eq(int(snap["steps"]), 0, "第 0 步")
	t.eq((snap["layout"] as Array).size(), s.board.item_count(), "快照记了棋盘上的每一件")
	t.eq(snap["board_size"], [s.board.size.x, s.board.size.y], "记了尺寸")
	var back := CalibrationRecorder.board_of(snap, c.items)
	t.eq(RunState.layout_of(back), RunState.layout_of(s.board), "按快照摆回来的棋盘逐件相同")
	var spec := CalibrationRecorder.compile(snap, c.items)
	t.eq(spec.max_hp, s.compile_player().max_hp, "编译出来的生命和一局里的一样（没有套装 / buff 时）")

	var steps := 0
	for i in 6:
		if s.is_over():
			break
		var moves := s.travel.available_moves()
		if moves.is_empty():
			break
		if s.step_to(moves[0]):
			steps += 1
			t.check(rec.record(s), "第 %d 步记了" % steps)
			s.close_sessions()
	var all := CalibrationRecorder.read_all(SNAPS)
	t.eq(all.size(), steps, "读回来 %d 份" % steps)
	t.eq(rec.written, steps, "记数一致")
	if all.size() > 0:
		t.eq(int(all[all.size() - 1]["steps"]), s.travel.clock.total, "最后一份的步数 = 现在的行动点总数")

	# 分段：段长 2 → 段号 = steps ÷ 2
	var dummies := DummyBuilder.build(all, c.items, 2)
	var expected_keys := {}
	for snap2 in all:
		expected_keys[str(int(snap2["steps"]) / 2)] = true
	t.eq(dummies.size(), expected_keys.size(), "段数 = 出现过的段号数")
	for k in dummies:
		var d: Dictionary = dummies[k]
		t.eq(d["steps"], [int(k) * 2, int(k) * 2 + 1], "第 %s 段的步数范围" % k)
		t.check(int(d["samples"]) >= 1, "有样本")
		# 木桩 = 段里离平均最近的那份：它的读数和平均的距离 ≤ 段里任何一份
		var best_d := INF
		var picked_d := -1.0
		for snap3 in all:
			if str(int(snap3["steps"]) / 2) != k:
				continue
			var m := DummyBuilder.metrics(snap3, c.items)
			var dh := (float(m["hp"]) - float(d["avg_hp"])) / maxf(1.0, float(d["avg_hp"]))
			var dd := (float(m["dps"]) - float(d["avg_dps"])) / maxf(0.01, float(d["avg_dps"]))
			var dist := dh * dh + dd * dd
			best_d = minf(best_d, dist)
			if absf(float(m["hp"]) - float(d["hp"])) < 1e-6 and absf(float(m["dps"]) - float(d["dps"])) < 1e-6:
				picked_d = dist
		t.check(picked_d >= 0.0 and picked_d <= best_d + 1e-9, "第 %s 段的木桩离平均最近" % k)
	t.eq(DummyBuilder.save(dummies, DUMMIES), OK, "存得了")
	var loaded := DummyBuilder.load_file(DUMMIES)
	t.eq(loaded.size(), dummies.size(), "读回来段数一样")

	# 没有快照：开局装备当第 0 段
	var fallback := DummyBuilder.from_loadouts(c.loadouts, c.items, CombatantBaseline.with_hp(60.0))
	t.eq(fallback.size(), c.loadouts.size(), "每套开局装备一份")
	var d0 := DummyBuilder.build(fallback, c.items, 5)
	t.eq(d0.keys(), ["0"], "全在第 0 段")
	t.eq(int((d0["0"] as Dictionary)["samples"]), c.loadouts.size(), "样本数 = 装备数")
	_cleanup()


static func run_bench(t: TestCase) -> void:
	t.begin("校准 · 木桩对猎手各档的胜率：每档都在 0～1，best 是离 50% 最近的档，wanted 是规则给的档，表能打印")
	var c := _content()
	var ids: Array = c.hunter_defs.keys()
	ids.sort()
	if ids.is_empty() or c.chapter == null or c.chapter.enemy_pool == &"":
		t.check(false, "缺猎手或敌人池")
		return
	var hunter: HunterDef = c.hunter_defs[ids[0]]
	var pool: EnemyPool = load(ContentPaths.asset_file("enemy_pools", String(c.chapter.enemy_pool)))
	t.not_null(pool, "有敌人池")
	var dummies := DummyBuilder.build(DummyBuilder.from_loadouts(c.loadouts, c.items, CombatantBaseline.with_hp(60.0)), c.items, 5)
	var result := HunterBench.run(dummies, hunter, pool, c.enemies, c.items, 12, 7, c.chapter.difficulty)
	t.eq(result.size(), dummies.size(), "每段一行")
	for k in result:
		var row: Dictionary = result[k]
		var rates: Dictionary = row["rates"]
		t.eq(rates.size(), pool.strengths().size(), "每个档位一个胜率")
		var best_gap := INF
		for tier in rates:
			var r: Dictionary = rates[tier]
			t.check(float(r["rate"]) >= 0.0 and float(r["rate"]) <= 1.0, "档 %s 胜率在 0～1（%.2f）" % [tier, float(r["rate"])])
			t.check(int(r["fights"]) > 0, "档 %s 打了 %d 场" % [tier, int(r["fights"])])
			best_gap = minf(best_gap, absf(float(r["rate"]) - 0.5))
		var best_rate := float((rates[str(int(row["best"]))] as Dictionary)["rate"])
		t.check(absf(absf(best_rate - 0.5) - best_gap) < 1e-9, "best 档是离 50%% 最近的（%.2f）" % best_rate)
		t.check(pool.strengths().has(int(row["wanted"])), "wanted 是池里有的档")
	# 同一个种子可复现
	var again := HunterBench.run(dummies, hunter, pool, c.enemies, c.items, 12, 7, c.chapter.difficulty)
	t.eq(JSON.stringify(again), JSON.stringify(result), "同种子结果逐字相同")
	var text := HunterBench.report_text(result, hunter.id)
	t.check(text.contains(String(hunter.id)) and text.contains("best"), "表里有猎手 id 与 best 列")


static func run_brackets(t: TestCase) -> void:
	t.begin("校准 · 木桩按段位表分段（开区间的最后一段）；胜率表的 wanted = 猎手按段位的档位")
	var c := _content()
	var snaps: Array[Dictionary] = []
	for steps in [0, 1, 4, 5, 9, 10, 30]:
		for snap in DummyBuilder.from_loadouts(c.loadouts, c.items, CombatantBaseline.with_hp(60.0)):
			var s2: Dictionary = snap.duplicate(true)
			s2["steps"] = steps
			snaps.append(s2)
	var thresholds: Array[int] = [0, 5, 10]
	var dummies := DummyBuilder.build_by_brackets(snaps, c.items, thresholds)
	t.eq(dummies.keys(), ["0", "1", "2"], "三段")
	t.eq((dummies["0"] as Dictionary)["steps"], [0, 4], "第 0 段 0～4")
	t.eq((dummies["1"] as Dictionary)["steps"], [5, 9], "第 1 段 5～9")
	t.eq((dummies["2"] as Dictionary)["steps"], [10, -1], "最后一段开区间")
	t.eq(int((dummies["0"] as Dictionary)["samples"]), 3 * c.loadouts.size(), "第 0 段的样本数（步数 0、1、4）")
	var ids: Array = c.hunter_defs.keys()
	ids.sort()
	if ids.is_empty():
		return
	var hunter: HunterDef = c.hunter_defs[ids[0]]
	var pool: EnemyPool = load(ContentPaths.asset_file("enemy_pools", String(hunter.enemy_pool if hunter.enemy_pool != &"" else c.chapter.enemy_pool)))
	var result := HunterBench.run(dummies, hunter, pool, c.enemies, c.items, 6, 3, 0, &"", 0.0, thresholds)
	for k in result:
		var want := pool.clamp_strength(hunter.strength_for_bracket(int(k))) if not hunter.strength_by_bracket.is_empty() else int((result[k] as Dictionary)["wanted"])
		t.eq(int((result[k] as Dictionary)["wanted"]), want, "第 %s 段的 wanted = 猎手表里那一档" % k)
	var text := HunterBench.report_text(result, hunter.id)
	t.check(text.contains("∞"), "开区间的最后一段打印成 ∞")
