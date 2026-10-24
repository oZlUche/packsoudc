## 245：系数假设实测 —— 一场的结果 → 一行（时长、受击、暴击率、对手 DPS、邻居频率、低血占比、平均层数……和日志里数出来的一致）；
## 写一行读一行；汇总表对三行样本出得来；战斗日志写完顺手追加一行；扫表多一张假设表
extends RefCounted

const B242 := preload("res://tests/battle/test_balance_242.gd")
const ROWS := "user://test_245_assumptions.jsonl"
const LOG_DIR := "user://test_245_battle_logs"


static func _f(sec: float) -> int:
	return StatMath.from_float(sec)


static func _ev(name: StringName, sec: float, side: int, payload: Dictionary) -> BattleEvent:
	return BattleEvent.make(name, _f(sec), side, payload)


static func _dmg(sec: float, victim: int, amount: float, direct: bool, crit: bool = false, cancelled: bool = false) -> BattleEvent:
	var p := {"type": "physical", "amount": _f(amount), "source_side": 1 - victim, "uid": 3, "crit": crit, "direct": direct}
	if cancelled:
		p["cancelled"] = true
	return _ev(BattleEvent.DAMAGE, sec, victim, p)


static func _hp(sec: float, current: float, mx: float) -> BattleEvent:
	return _ev(BattleEvent.RESOURCE_CHANGED, sec, 0, {"key": "hp", "delta": 0, "reason": "damage", "current": _f(current), "max": _f(mx)})


## 一场手搓的十秒：数都能心算
static func _sample() -> BattleResult:
	var r := BattleResult.new()
	r.winner = 0
	r.duration = _f(10.0)
	r.initial = {"time": 0, "sides": [
		{"side": 0, "resources": {&"hp": [100, 100], &"stamina": [50, 50]}, "buffs": {}, "axes": {}},
		{"side": 1, "resources": {&"hp": [80, 80], &"stamina": [50, 50]}, "buffs": {}, "axes": {}},
	]}
	r.log = [
		_dmg(1.0, 0, 10.0, true), _dmg(2.0, 0, 20.0, true), _dmg(3.0, 0, 10.0, false),
		_dmg(1.0, 1, 5.0, true, true), _dmg(2.0, 1, 5.0, true), _dmg(2.5, 1, 5.0, true, true, true),
		_ev(BattleEvent.ITEM_FIRED, 1.0, 0, {"uid": 3}), _ev(BattleEvent.ITEM_FIRED, 2.0, 0, {"uid": 3}), _ev(BattleEvent.ITEM_FIRED, 1.0, 0, {"uid": 4}),
		_ev(BattleEvent.ITEM_FIRED, 1.0, 1, {"uid": 9}),
		_hp(4.0, 25.0, 100.0), _hp(6.0, 50.0, 100.0), _hp(9.0, 20.0, 100.0),
		_ev(BattleEvent.STATUS_STACKED, 2.0, 1, {"buff": "bleed", "delta": 1, "stacks": 1}),
		_ev(BattleEvent.STATUS_STACKED, 4.0, 1, {"buff": "bleed", "delta": 2, "stacks": 3}),
		_ev(BattleEvent.STATUS_UNSTACKED, 6.0, 1, {"buff": "bleed", "delta": -3, "stacks": 0}),
		_ev(BattleEvent.STATUS_STACKED, 5.0, 0, {"buff": "ward", "delta": 1, "stacks": 1}),
	] as Array[BattleEvent]
	return r


static func run_of(t: TestCase) -> void:
	t.begin("245 · 一场 → 一行：手搓的十秒，每一项都和心算的一样；量不出来的不写键")
	var row := AssumptionStats.of(_sample(), {"rng_seed": 9, "tier": 2, "steps": 12, "enemy": "rat", "difficulty": "", "stamina_regen": 4.0}, "9.9.9")
	t.eq(String(row["version"]), "9.9.9", "带版本号")
	t.eq(int(row["seed"]), 9, "带种子")
	t.eq(int(row["tier"]), 2, "带档位")
	t.eq(int(row["steps"]), 12, "带步数")
	t.eq(int(row["winner"]), 0, "带胜负")
	var expect := {
		"fight_sec": 10.0, "horizon_sec": 10.0, "hit_rate": 0.2, "opponent_dps": 4.0, "crit_rate": 0.5, "neighbor_hz": 0.15,
		"low_hp_share": 0.3, "assumed_stacks": 2.0, "persist_share": 0.5, "status_applied_rate": 0.1, "status_removed_rate": 0.0,
		"stamina_regen": 4.0, "stamina_max": 50.0, "assumed_hp": 80.0,
	}
	for k in expect:
		t.check(row.has(k) and is_equal_approx(float(row[k]), float(expect[k])), "%s = %s（%s）" % [k, expect[k], row.get(k, "没有")])
	t.check(AssumptionStats.KEYS.all(func(k: String) -> bool: return row.has(k)), "量得出来的都在")

	var quiet := BattleResult.new()
	quiet.duration = _f(5.0)
	var q := AssumptionStats.of(quiet, {})
	t.check(not q.has("crit_rate") and not q.has("assumed_stacks") and not q.has("neighbor_hz") and not q.has("persist_share"), "没出过手、没上过 buff：这几项不写键")
	t.eq(float(q["hit_rate"]), 0.0, "没挨打：受击 0")
	t.check(not AssumptionStats.of(BattleResult.new(), {}).has("fight_sec"), "时长 0：不算频率")


static func run_real_battle(t: TestCase) -> void:
	t.begin("245 · 一场真仗（固定种子）：时长、受击次数、暴击率、对手 DPS 和日志逐条数的一致")
	var items := B242._items()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := B242._pool()
	var dummies := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var spec := DummyBuilder.compile(dummies[dummies.keys()[5]], items)
	var node := MapNode.new()
	node.type = &"battle"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var entry := EnemyPlacer.pick(pool, enemies, node, 1, rng)
	var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, items, 1, rng).get("content", {})
	var result := BattleSim.run(spec, EnemyKit.spec_of(content, enemies, pool, items), rng, 30.0)
	var row := AssumptionStats.of(result, {"stamina_regen": AssumptionStats.regen_of(spec)})
	var dur := result.duration_sec()
	var hits := 0
	var lost := 0
	var mine := 0
	var crits := 0
	for e in result.log:
		if e.name != BattleEvent.DAMAGE or e.payload.get("cancelled", false):
			continue
		if e.side == 0 and int(e.payload["source_side"]) == 1:
			lost += int(e.payload["amount"])
			hits += 1 if e.payload["direct"] else 0
		elif e.side == 1 and int(e.payload["source_side"]) == 0 and e.payload["direct"]:
			mine += 1
			crits += 1 if e.payload["crit"] else 0
	t.check(dur > 0.0 and is_equal_approx(float(row["fight_sec"]), dur), "时长 %.1f 秒" % dur)
	t.check(is_equal_approx(float(row["hit_rate"]), hits / dur), "受击 %d 次" % hits)
	t.check(is_equal_approx(float(row["opponent_dps"]), StatMath.to_float(lost) / dur), "对手 DPS")
	if mine > 0:
		t.check(is_equal_approx(float(row["crit_rate"]), float(crits) / mine), "暴击率 %d / %d" % [crits, mine])
	t.check(float(row["stamina_regen"]) > 0.0 and float(row["stamina_max"]) > 0.0, "耐力回复与上限抄了基线（%s / %s）" % [row["stamina_regen"], row["stamina_max"]])
	t.check(float(row["low_hp_share"]) >= 0.0 and float(row["low_hp_share"]) <= 1.0, "低血占比在 0～1")


static func run_file_and_report(t: TestCase) -> void:
	t.begin("245 · 写一行读一行；三行样本出得来汇总表（中位数、四分位、量不出来的两项、按段位）")
	if FileAccess.file_exists(ROWS):
		DirAccess.remove_absolute(ROWS)
	var rows: Array[Dictionary] = []
	for i in 3:
		var row := AssumptionStats.of(_sample(), {"steps": [0, 6, 30][i]})
		row["fight_sec"] = [8.0, 10.0, 15.0][i]
		rows.append(row)
		t.check(AssumptionStats.append(ROWS, row), "写第 %d 行" % (i + 1))
	var back := AssumptionStats.read_rows(ROWS)
	t.eq(back.size(), 3, "读回三行")
	t.check(not back.is_empty() and is_equal_approx(float(back[0]["hit_rate"]), 0.2), "数原样")
	t.check(is_equal_approx(AssumptionStats.quantile(AssumptionStats.values_of(back, "fight_sec"), 0.5), 10.0), "时长中位数 10")
	var md := AssumptionStats.markdown(back, PowerWeights.load_from(), "样本", ["三行"] as Array[String])
	t.check(md.contains("| `fight_sec` | 12.00 | 10.00 | 9.00 ～ 12.50 | 3 |"), "主表：现在 12、实测中位数 10、四分位、三场")
	t.check(md.contains("| `threshold_share` |") and md.contains("无法实测"), "量不出来的两项标出来")
	t.check(md.contains("## 按段位") and md.contains("段 0") and md.contains("段 20"), "按段位的小表")
	DirAccess.remove_absolute(ROWS)


static func run_trace_writer(t: TestCase) -> void:
	t.begin("245 · 战斗日志写完顺手追加一行假设（给了路径才写；不给不写）")
	if FileAccess.file_exists(ROWS):
		DirAccess.remove_absolute(ROWS)
	var trace := BattleTrace.new()
	BattleTraceWriter.write(trace, _sample(), {"run_seed": 1, "chapter": "t", "node": 0, "enemy": "rat", "tier": 3, "steps": 7}, LOG_DIR, 5)
	BattleTraceWriter.flush()
	t.check(not FileAccess.file_exists(ROWS) and not AssumptionStats.recorder("").is_valid(), "没给路径：不写")
	BattleTraceWriter.write(BattleTrace.new(), _sample(), {"run_seed": 1, "chapter": "t", "node": 0, "enemy": "rat", "tier": 3, "steps": 7}, LOG_DIR, 5,
		AssumptionStats.recorder(ROWS))
	BattleTraceWriter.flush()
	var rows := AssumptionStats.read_rows(ROWS)
	t.eq(rows.size(), 1, "给了路径：一行")
	if rows.size() == 1:
		t.eq(int(rows[0]["tier"]), 3, "日志头的档位进了这一行")
		t.eq(String(rows[0]["enemy"]), "rat", "对手 id")
		t.eq(String(rows[0]["version"]), CalibrationRecorder.version(), "版本号")
		t.check(is_equal_approx(float(rows[0]["hit_rate"]), 0.2), "受击频率")
	if FileAccess.file_exists(ROWS):
		DirAccess.remove_absolute(ROWS)
	B242._wipe_dir(LOG_DIR)
	t.eq(CalibrationRecorder.new().assumptions_path, AssumptionStats.PATH, "真实对局的记录器：写到 calibration/assumptions.jsonl（导出数据包整个目录带走）")
