extends SceneTree
## 测试 v9.06（PR #977）无头：真实伤害在真战斗里 —— 原值落血、不被护甲 / 格挡吸收、不暴击
const G := preload("res://tests/run/test_god_cards_388.gd")
const T := preload("res://tests/battle/test_faith_skill.gd")
var pool: EnemyPool
var enemies: EnemyDatabase
var tot := {"pure": 0, "bad": 0}

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

func _scan(label: String, br: BattleResult) -> void:
	var pure := [0, 0]; var bad := []; var crit := 0; var other_abs := [0, 0]; var other_block := [0, 0]; var sample := ""
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name != BattleEvent.DAMAGE: continue
		var s := e.side
		if bool(e.payload.get("pure", false)):
			pure[s] += 1
			var r := e.get_int(&"raw"); var a := e.get_int(&"amount"); var ab := e.get_int(&"absorbed"); var bl := e.get_int(&"block")
			if sample == "": sample = str(e.payload)
			if bool(e.payload.get("crit", false)): crit += 1
			if (a + ab != r or bl != 0 or ab != 0) and not bool(e.payload.get("cancelled", false)):
				if bad.size() < 3: bad.append(str(e.payload))
		else:
			if e.get_int(&"absorbed") > 0: other_abs[s] += 1
			if e.get_int(&"block") > 0: other_block[s] += 1
	tot["pure"] += pure[0] + pure[1]; tot["bad"] += bad.size()
	print("TD977 %s：真实伤害 打对手 %d 下、打我 %d 下；其中暴击 %d；不是原值落血的 %d %s；同一场普通伤害被护甲吸收 对手 %d / 我 %d 次、被格挡 对手 %d / 我 %d 次；样例 %s" % [label, pure[1], pure[0], crit, bad.size(), str(bad), other_abs[1], other_abs[0], other_block[1], other_block[0], sample.left(220)])

func _kit(label: String, god: StringName, cards: Dictionary, items: Array, strength: int, seed_: int) -> void:
	var run := G._start(77, god)
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
	_scan("%s %s（对手档 %d）" % [label, str(placed), strength], BattleSim.run(me, foe, rng, 30.0))
	run.dispose()

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	# 技巧之神【大巧若拙】：用套件里的试验武器逼出清零
	var rng := RandomNumberGenerator.new(); rng.seed = 977
	_scan("技巧之神 大巧若拙 50% + 残心（试验武器，每下 40 耐力，对木桩）", BattleSim.run(T._me({"zanshin": 1, "clumsy_pct": 50.0}, 40.0), T._dummy(), rng, 20.0))
	for s in [1, 2, 3]:
		_kit("技巧之神 大巧若拙", &"skill", {"god_skill_clumsy": 1}, ["heavy_crossbow", "knight_plate", "kite_shield"], 3, s)
	for s in [1, 2, 3]:
		_kit("无信者 带真实伤害的武器", &"", {}, ["steel_greatsword", "spiked_club", "knight_plate", "kite_shield"], 3, s)
	for s in [4, 5]:
		_kit("蛮神 带真实伤害的武器", &"brute", {"god_brute_damage": 2, "god_brute_cornered": 1}, ["bonesteel_greatsword", "knight_plate", "kite_shield"], 3, s)
	print("TD977 合计：真实伤害 %d 下，不是原值落血的 %d 下" % [tot["pure"], tot["bad"]])
	print("TD977 完")
	quit(0)
