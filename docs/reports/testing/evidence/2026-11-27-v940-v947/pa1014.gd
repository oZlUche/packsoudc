extends SceneTree
## 测试 v9.32（PR #1014）无头：技巧之神【招架】每 10 层连击固定回 2 点护甲，多张相加
const G := preload("res://tests/run/test_god_cards_388.gd")
var _amts := {}
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

func _sim(label: String, god: StringName, cards: Dictionary, items: Array, secs: float = 30.0) -> void:
	var run := G._start(75, god)
	var lv := LevelModule.of(run)
	for b in [&"war_pack", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(b))
	var placed := []
	for id in items:
		if TestSupport.put(run.board, run.items.get_def(StringName(id))) != null: placed.append(id)
	for k in cards: lv.taken[k] = cards[k]
	var me := run.compile_player()
	me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(5000.0)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
	var foe := _enemy(run, 2, 975)
	var rng := RandomNumberGenerator.new(); rng.seed = 975
	var br := BattleSim.run(me, foe, rng, secs)
	var armor_heal := 0.0; var armor_heal_n := 0; var armor_max := 0.0; var block := 0.0; var hits := 0
	var armor_dbg := []; var rejuv_max := 0; var rejuv_up := []; var day_night := []
	for raw in br.log:
		var e := raw as BattleEvent
		var t := StatMath.to_float(e.time)
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.get_name(&"key")) == "armor":
			if String(e.get_name(&"reason")) == "heal" and e.get_int(&"delta") > 0:
				armor_heal += StatMath.to_float(e.get_int(&"delta")); armor_heal_n += 1
			if String(e.get_name(&"reason")) == "heal" and e.get_int(&"delta") > 0: _amts[StatMath.to_float(e.get_int(&"delta"))] = int(_amts.get(StatMath.to_float(e.get_int(&"delta")), 0)) + 1
			if label.contains("招架") and armor_dbg.size() < 12: armor_dbg.append("%.1fs %s %+d" % [t, String(e.get_name(&"reason")), int(StatMath.to_float(e.get_int(&"delta")))])
			if "max" in e.payload: armor_max = maxf(armor_max, StatMath.to_float(int(e.payload["max"])))
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			block += StatMath.to_float(e.get_int(&"block")); hits += 1
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and String(e.payload.get("buff", "")).contains("rejuv"):
			rejuv_max = maxi(rejuv_max, e.get_int(&"stacks"))
			if e.get_int(&"delta") > 0 and rejuv_up.size() < 4: rejuv_up.append("%.0fs+%d" % [t, e.get_int(&"delta")])
		if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("key", "")) in ["sun_open", "sun_window"] and day_night.size() < 3:
			day_night.append("%.0fs %s" % [t, str(e.payload.get("day", e.payload.get("phase", "")))])
	if not armor_dbg.is_empty(): print("PA1014 　　护甲变化 %s" % str(armor_dbg))
	var regen := 0.0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.get_name(&"key")) == "hp" and String(e.get_name(&"reason")) == "regen" and e.get_int(&"delta") > 0: regen += StatMath.to_float(e.get_int(&"delta"))
	if label.contains("回春"): print("PA1014 　　生命回复共 %.0f；开战时回复轴 %s" % [regen, str(me.axes)])
	var gear := me.baseline.total_of(BattleStats.MAX_ARMOR) if me.baseline != null else 0
	print("PA1014 　　每次回的量 → 次数 %s；护甲上限 %.0f" % [str(_amts), armor_max])
	_amts = {}
	var combo := 0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.side == 0 and e.name == BattleEvent.STATUS_STACKED and String(e.payload.get("buff", "")).contains("momentum"): combo = maxi(combo, e.get_int(&"stacks"))
	print("PA1014 　　连击最高 %d" % combo)
	print("PA1014 %s：放下 %s；护甲回复 %d 次共 %.0f；受击 %d 下、被格挡共 %.0f；回春最多 %d 层，前几次 %s；%.1f 秒" % [label, str(placed), armor_heal_n, armor_heal, hits, block, rejuv_max, str(rejuv_up), br.duration_sec()])
	run.dispose()

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	for arm in [["knight_plate", "骑士板甲"], ["leather_armor", "皮甲"]]:
		_sim("技巧 对照（没招架），%s" % arm[1], &"skill", {}, ["knife", arm[0]])
		for n in [1, 2, 3]:
			_sim("技巧 招架 ×%d，%s" % [n, arm[1]], &"skill", {"god_skill_parry": n}, ["knife", arm[0]])
	_sim("技巧 招架 ×1，没穿防具", &"skill", {"god_skill_parry": 1}, ["knife"])
	_sim("技巧 招架 ×2，钢大剑 + 骑士板甲", &"skill", {"god_skill_parry": 2}, ["steel_greatsword", "knight_plate"])
	var run := G._start(75, &"skill")
	var lv := LevelModule.of(run)
	for lang in ["zh", "en"]:
		UiText.lang = lang
		for k in [0, 1, 2]:
			lv.taken[&"god_skill_parry"] = k
			print("PA1014 牌面 %s 已拿 %d 张：%s" % [lang, k, lv.card_text(&"god_skill_parry")])
	run.dispose()
	print("PA1014 完")
	quit(0)
