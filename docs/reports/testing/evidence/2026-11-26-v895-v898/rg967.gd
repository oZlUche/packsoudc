extends SceneTree
## 测试 v8.96（PR #967）无头：【怒气】每失去 2 点生命一层、持续伤害也算；【困兽犹斗】「所有属性」含暴击
const G := preload("res://tests/run/test_god_cards_388.gd")
var pool: EnemyPool
var enemies: EnemyDatabase

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

func _sim(label: String, cards: Dictionary, strength: int, seed_: int, hp: float = 0.0) -> void:
	var run := G._start(67, &"brute")
	var lv := LevelModule.of(run)
	TestSupport.put(run.board, run.items.get_def(&"knife"))
	for k in cards: lv.taken[k] = cards[k]
	var me := run.compile_player()
	if hp > 0.0:
		me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(hp)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
	var foe := _enemy(run, strength, seed_)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var br := BattleSim.run(me, foe, rng, 20.0)
	var lost_direct := 0.0; var lost_dot := 0.0; var gained := 0; var mx := 0; var crit := 0; var hits := 0; var kinds := {}
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			var a := StatMath.to_float(e.get_int(&"amount"))
			if bool(e.payload.get("direct", false)): lost_direct += a
			else: lost_dot += a; kinds[String(e.payload.get("type", ""))] = int(kinds.get(String(e.payload.get("type", "")), 0)) + 1
		if e.name == BattleEvent.DAMAGE and e.side == 1:
			hits += 1
			if bool(e.payload.get("crit", false)): crit += 1
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and String(e.payload.get("buff", "")) == "brute_rage":
			if e.get_int(&"delta") > 0: gained += e.get_int(&"delta")
			mx = maxi(mx, e.get_int(&"stacks"))
	print("RG967 %s：结果 %s %.1f 秒；我失去生命 直接 %.0f + 持续 %.0f（%s）= %.0f → 按 2 点一层应 %d 层；实际积了 %d 层，最多同时 %d 层；我打中 %d 下、暴击 %d" % [
		label, "胜" if br.winner == 0 else ("负" if br.winner == 1 else "平"), br.duration_sec(), lost_direct, lost_dot, str(kinds), lost_direct + lost_dot, int((lost_direct + lost_dot) / 2.0), gained, mx, hits, crit])
	run.dispose()

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	for s in [1, 2, 3, 4, 5, 6]:
		_sim("只有核心，对手档 2 种子 %d" % s, {}, 2, s)
	for s in [1, 2, 3]:
		_sim("困兽犹斗，生命 300，种子 %d" % s, {"god_brute_cornered": 1}, 3, s, 300.0)
		_sim("对照（没有困兽），生命 300，种子 %d" % s, {}, 3, s, 300.0)
	var run := G._start(67, &"brute")
	var lv := LevelModule.of(run)
	for cid in ["god_brute_cornered", "god_brute_pain", "god_brute_irate"]:
		print("RG967 牌面 %s：%s" % [cid, lv.card_text(StringName(cid))])
	UiText.lang = "en"
	for cid in ["god_brute_cornered", "god_brute_pain"]:
		print("RG967 en %s：%s" % [cid, lv.card_text(StringName(cid))])
	var bd := BruteRage.new()
	print("RG967 核心说明：%s" % bd.describe() if bd.has_method("describe") else "RG967 （核心没有 describe）")
	run.dispose()
	print("RG967 完")
	quit(0)
