extends SceneTree
## 测试 v9.38（PR #1018）无头：放血刀第二条 —— 出手时对手流血 ≥ 6 层，每层 3 点，流血保留。对照旧版（满 6 层打一次、清空流血）和去掉第二条的版本
const G := preload("res://tests/run/test_god_cards_388.gd")
var pool: EnemyPool
var enemies: EnemyDatabase
var _old: ItemDef
var _plain: ItemDef


func _enemy(run: RunState, strength: int, seed_: int, dummy: bool) -> CombatantSpec:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var node := MapNode.new(); node.id = 0; node.type = &"battle"
	for _t in 30:
		var entry := EnemyPlacer.pick(pool, enemies, node, strength, rng)
		if entry == null: continue
		var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, run.items, strength, rng).get("content", {})
		var e := EnemyKit.spec_of(content, enemies, pool, run.items)
		if e != null:
			if dummy:
				e.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); e.max_hp = e.baseline.total_of(BattleStats.MAX_HP)
			return e
	return null


func _sim(label: String, items: Array, variant: String, seed_: int, dummy: bool, inf: bool = false) -> Dictionary:
	var run := G._start(seed_, &"brute")
	for b in [&"war_pack", &"bag_leather", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(b))
	var bl_uid := -1
	for id in items:
		var inst: ItemInstance = TestSupport.put(run.board, run.items.get_def(StringName(id)))
		if inst == null: print("BL1018 （放不下 %s）" % id); continue
		if id == "bloodletter":
			bl_uid = inst.uid
			if variant == "old": inst.def = _old
			elif variant == "plain": inst.def = _plain
	var me := run.compile_player()
	me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(5000.0)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
	if inf: me.baseline.set_base(BattleStats.REGEN_STAMINA, StatMath.from_float(300.0))
	var foe := _enemy(run, 3, 1018 + seed_, dummy)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var br := BattleSim.run(me, foe, rng, 30.0)
	var total := 0.0; var bl_dmg := 0.0; var bl_hits := 0; var bl_big := 0.0; var bleed_max := 0; var bleed_dot := 0.0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1:
			var a := -StatMath.to_float(e.get_int(&"amount"))
			if a < 0: a = -a
			total += a
			if int(e.payload.get("uid", 0)) == bl_uid and bl_uid >= 0:
				bl_dmg += a; bl_hits += 1; bl_big = maxf(bl_big, a)
			if String(e.payload.get("type", "")) == "bleed": bleed_dot += a
		if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and String(e.payload.get("buff", "")) == "bleed":
			bleed_max = maxi(bleed_max, e.get_int(&"stacks"))
	run.dispose()
	return {"total": total, "bl": bl_dmg, "hits": bl_hits, "big": bl_big, "bleed_max": bleed_max, "dot": bleed_dot, "dur": br.duration_sec(), "won": br.winner == 0 if "winner" in br else -1}


func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	_old = (load("res://tools/_bl_old.tres") as ItemDef).duplicate(true)
	var cur := load("res://data/items/bloodletter.tres") as ItemDef
	_plain = cur.duplicate(true)
	_plain.combat = cur.combat.duplicate(true)
	_plain.combat.rules = [_plain.combat.rules[0]] as Array[AbilityRule]
	print("BL1018 新版规则 %d 条，旧版 %d 条，对照 %d 条" % [cur.combat.rules.size(), _old.combat.rules.size(), _plain.combat.rules.size()])
	var builds := [
		["只有放血刀", ["bloodletter", "knight_plate"]],
		["放血刀 + 骨牙匕首 + 剁刀", ["bloodletter", "bonefang_dagger", "cleaver", "knight_plate"]],
		["放血刀 + 骨牙匕首 ×2 + 剁刀 + 蛮族弯刀", ["bloodletter", "bonefang_dagger", "bonefang_dagger", "cleaver", "barbarian_scimitar", "knight_plate"]],
	]
	for b in builds:
		for mode in [0, 1, 2]:
			var dummy: bool = mode != 1
			var inf: bool = mode == 2
			var line := []
			for v in ["new", "old", "plain"]:
				var acc := {"total": 0.0, "bl": 0.0, "hits": 0, "big": 0.0, "bleed_max": 0, "dot": 0.0, "dur": 0.0}
				for s in [1, 2, 3]:
					var r := _sim(b[0], b[1], v, s, dummy, inf)
					for k in ["total", "bl", "dot", "dur"]: acc[k] += float(r[k]) / 3.0
					acc["hits"] += int(r["hits"]); acc["big"] = maxf(acc["big"], r["big"]); acc["bleed_max"] = maxi(acc["bleed_max"], r["bleed_max"])
				line.append("%s：总伤 %.0f（每秒 %.0f），放血刀 %.0f（每秒 %.0f，单下最大 %.0f），流血跳 %.0f，对手流血最多 %d 层，打了 %.1f 秒" % [{"new": "新版", "old": "旧版", "plain": "去掉第二条"}[v], acc["total"], acc["total"] / maxf(0.1, acc["dur"]), acc["bl"], acc["bl"] / maxf(0.1, acc["dur"]), acc["big"], acc["dot"], acc["bleed_max"], acc["dur"]])
			print("BL1018 【%s】对%s（3 个种子平均）" % [b[0], ("木桩，耐力回复每秒 300（不缺耐力）" if inf else "木桩（生命 99999，30 秒）") if dummy else "第 3 档真实对手"])
			for l in line: print("BL1018 　　" + l)
	print("BL1018 完")
	quit(0)
