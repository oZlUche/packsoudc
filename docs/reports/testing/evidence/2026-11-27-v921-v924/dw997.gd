extends SceneTree
## 测试 v9.24（PR #997）无头：日神【黎明】改成进入白昼时恢复生命上限 20% 的生命
const G := preload("res://tests/run/test_god_cards_388.gd")
const T := preload("res://tests/battle/test_faith_skill.gd")
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


func _run(cards: Dictionary, seed_: int) -> void:
	var run := G._start(77, &"sun")
	var lv := LevelModule.of(run)
	for b in [&"war_pack", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(b))
	for id in ["knife", "leather_armor"]: TestSupport.put(run.board, run.items.get_def(StringName(id)))
	for k in cards: lv.taken[k] = cards[k]
	var me := run.compile_player()
	me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(2000.0)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var br := BattleSim.run(me, _enemy(run, 3, seed_), rng, 40.0)
	var days := []; var heals := []; var big := 0
	var last_day := -100.0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.side != 0: continue
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("key", "")) == "sun_window":
			days.append("%.1f" % StatMath.to_float(e.time))
		if e.name == BattleEvent.RESOURCE_CHANGED and String(e.payload.get("key", "")) == String(BattleStats.RES_HP) and String(e.payload.get("reason", "")) == String(BattleEvent.REASON_HEAL):
			var dlt := StatMath.to_float(e.get_int(&"delta"))
			if dlt >= 50.0:
				heals.append("%.1fs +%d" % [StatMath.to_float(e.time), roundi(dlt)])
	print("DW997 %s 种子 %d：换边 %s；单次回血 ≥ 50 的：%s；最后生命 %s" % [str(cards.keys()), seed_, str(days), str(heals), str(br.final.get(0, {}))])
	run.dispose()

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	for s in [1, 2]:
		_run({"god_sun_dawnlight": 1}, s)
		_run({}, s)
	var run := G._start(5, &"sun")
	print("DW997 牌面：", LevelModule.of(run).card_text(&"god_sun_dawnlight"))
	UiText.lang = "en"
	print("DW997 牌面 en：", LevelModule.of(run).card_text(&"god_sun_dawnlight"))
	run.dispose()
	quit(0)
