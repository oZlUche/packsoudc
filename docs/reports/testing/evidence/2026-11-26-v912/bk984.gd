extends SceneTree
## 测试 v9.06（PR #977）无头：v9.12（PR #984）格挡 = 固定减伤，只对直接、非真实伤害，不同来源只取最高
const G := preload("res://tests/run/test_god_cards_388.gd")
const T := preload("res://tests/battle/test_faith_skill.gd")
var pool: EnemyPool
var enemies: EnemyDatabase
var tot := {"bad": 0}

func _enemy(run: RunState, strength: int, seed_: int) -> CombatantSpec:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var node := MapNode.new(); node.id = 0; node.type = &"battle"
	for _t in 30:
		var entry := EnemyPlacer.pick(pool, enemies, node, strength, rng)
		if entry == null: continue
		var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, run.items, strength, rng).get("content", {})
		var e := EnemyKit.spec_of(content, enemies, pool, run.items)
		if e != null:
			e.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); e.max_hp = e.baseline.total_of(BattleStats.MAX_HP)
			return e
	return null


const K := 10000

func _scan(label: String, br: BattleResult, cap: int) -> void:
	var vals := {}; var direct := 0; var blocked := 0; var over := 0; var dot_blk := 0; var dot := 0; var pure := 0; var pure_blk := 0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name != BattleEvent.DAMAGE or e.side != 0: continue
		if e.get_int(&"raw") <= 0 or bool(e.payload.get("cancelled", false)): continue
		var bl := e.get_int(&"block")
		if bool(e.payload.get("pure", false)):
			pure += 1
			if bl != 0: pure_blk += 1
		elif not bool(e.payload.get("direct", false)):
			dot += 1
			if bl != 0: dot_blk += 1
		else:
			direct += 1
			if bl > 0: blocked += 1
			vals[bl / K] = int(vals.get(bl / K, 0)) + 1
			if bl > cap * K: over += 1
	var keys := vals.keys(); keys.sort()
	var dist := []
	for k in keys: dist.append("%d×%d" % [k, vals[k]])
	var cb: Array = T._combo(br)
	var bad := over + dot_blk + pure_blk
	tot["bad"] += bad
	print("BK984 %s：直接伤害 %d 下，被格挡 %d 下，格挡值分布 [%s]，最高 %d（应 ≤ %d，超出 %d 下）；持续伤害 %d 下被格挡 %d；真实伤害 %d 下被格挡 %d；最高连击 %d" % [label, direct, blocked, ", ".join(dist), (keys.max() if not keys.is_empty() else 0), cap, over, dot, dot_blk, pure, pure_blk, cb[0]])

func _kit(label: String, god: StringName, cards: Dictionary, items: Array, cap: int, strength: int, seed_: int, secs: float = 30.0, drop_anchor: bool = false) -> void:
	var run := G._start(77, god)
	if drop_anchor:
		for it in run.board.items():
			if it.def.is_anchor(): run.board.remove(it.uid)
	var lv := LevelModule.of(run)
	for b in [&"war_pack", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(b))
	var placed := []
	for id in items:
		if TestSupport.put(run.board, run.items.get_def(StringName(id))) != null: placed.append(id)
	for k in cards: lv.taken[k] = cards[k]
	var me := run.compile_player()
	me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(5000.0)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
	var foe := _enemy(run, strength, seed_)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	_scan("%s %s（对手档 %d，种子 %d）" % [label, str(placed), strength, seed_], BattleSim.run(me, foe, rng, secs), cap)
	run.dispose()

## 技巧之神的连击机制 + 自选的盾，对一个每秒打 20 点直接伤害的木桩（伤害够大，格挡不被伤害截断）
func _guard() -> void:
	var run := G._start(77, &"")
	var cases := [
		["J1 以攻待守 10（30 层）+ 鸢盾 9", 10.0, "kite_shield", 10],
		["J2 以攻待守 10（30 层），没盾", 10.0, "", 10],
		["J3 以攻待守 10（30 层）+ 赐福盾 15（开场弹开 +8）", 10.0, "blessed_shield", 23],
		["J4 以攻待守 5（30 层）+ 鸢盾 9（应一直 9，不是 14）", 5.0, "kite_shield", 9],
		["J5 以攻待守 10（30 层）+ 鸢盾 9 + 钢圆盾 7", 10.0, "kite_shield,steel_round_shield", 10],
	]
	for c in cases:
		var b := GridInventory.new(Vector2i(6, 6), 1, false)
		b.place(ItemInstance.create(T._weapon("t_w", 10.0, 0.5)), Vector2i(0, 0), 0)
		b.place(ItemInstance.create(T._weapon("t_w2", 10.0, 0.6)), Vector2i(1, 0), 0)
		var y := 1
		for sid in String(c[2]).split(",", false):
			var at := Vector2i(0, y)
			for yy in range(1, 6):
				for xx in range(0, 6):
					if b.place(ItemInstance.create(run.items.get_def(StringName(sid))), Vector2i(xx, yy), 0) != null:
						at = Vector2i(-1, -1); break
				if at.x < 0: break
			if at.x >= 0: print("BK984 放不下 ", sid)
		var rule := SkillMomentumPerk.new().rule_for(null)
		var e := rule.effects[0] as SkillMomentum
		e.guard_flat = c[1]; e.guard_at = 30
		var rules: Array[AbilityRule] = [rule]
		var me := BattleCompiler.compile_board(b, CombatantBaseline.with_hp(5000.0), [] as Array[StatModifier], rules)
		var rng := RandomNumberGenerator.new(); rng.seed = 984
		var br := BattleSim.run(me, T._hitter(20.0, 0.5), rng, 30.0)
		_scan(String(c[0]), br, int(c[3]))
		# 按时间看：第几下开始到以攻待守
		var first := -1.0; var n := 0
		for raw in br.log:
			var ev := raw as BattleEvent
			if ev.name == BattleEvent.DAMAGE and ev.side == 0 and bool(ev.payload.get("direct", false)):
				n += 1
				if first < 0.0 and ev.get_int(&"block") == int(c[1]) * K and int(c[1]) > 9: first = float(n)
		print("BK984   ", c[0], "：第一次按以攻待守挡的是挨的第 ", first, " 下")
	run.dispose()

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	for s in [1, 2, 3]:
		_kit("A 单盾 鸢盾 9", &"", {}, ["knife", "knight_plate", "kite_shield"], 9, 3, s)
	for s in [1, 2, 3]:
		_kit("B 双盾 鸢盾 9 + 钢圆盾 7", &"", {}, ["knife", "knight_plate", "kite_shield", "steel_round_shield"], 9, 3, s)
	for s in [1, 2, 3]:
		_kit("C 双盾 圆盾 5 + 钢圆盾 7", &"", {}, ["knife", "knight_plate", "round_shield", "steel_round_shield"], 7, 3, s)
	_guard()
	for s in [1]:
		_kit("I 技巧之神 以攻待守 10 + 赐福盾 15（开场弹开 +8 → 23）", &"skill", {"god_skill_guard": 1}, ["knife", "knife", "knight_plate"], 23, 3, s, 60.0)
	for s in [1, 2]:
		_kit("F 无信者 鸢盾 9，对手带真实伤害（档 3）", &"", {}, ["knife", "knight_plate", "kite_shield"], 9, 3, s + 10)
	for s in [1, 2]:
		_kit("G 日神 夜幕 + 鸢盾 9（黑夜 9 + 2 = 11）", &"sun", {"god_sun_veil": 1}, ["knife", "knight_plate", "kite_shield"], 11, 3, s)
	print("BK984 合计：不合规的 %d 下" % tot["bad"])
	print("BK984 完")
	quit(0)
