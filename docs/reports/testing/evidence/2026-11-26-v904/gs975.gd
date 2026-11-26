extends SceneTree
## 测试 v9.04（PR #975）无头：四张保命牌随道具成长 —— 黎明、夜幕、招架、回春
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
			if label.contains("招架") and armor_dbg.size() < 12: armor_dbg.append("%.1fs %s %+d" % [t, String(e.get_name(&"reason")), int(StatMath.to_float(e.get_int(&"delta")))])
			if "max" in e.payload: armor_max = maxf(armor_max, StatMath.to_float(int(e.payload["max"])))
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			block += StatMath.to_float(e.get_int(&"block")); hits += 1
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and String(e.payload.get("buff", "")).contains("rejuv"):
			rejuv_max = maxi(rejuv_max, e.get_int(&"stacks"))
			if e.get_int(&"delta") > 0 and rejuv_up.size() < 4: rejuv_up.append("%.0fs+%d" % [t, e.get_int(&"delta")])
		if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("key", "")) in ["sun_open", "sun_window"] and day_night.size() < 3:
			day_night.append("%.0fs %s" % [t, str(e.payload.get("day", e.payload.get("phase", "")))])
	if not armor_dbg.is_empty(): print("GS975 　　护甲变化 %s" % str(armor_dbg))
	var regen := 0.0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.get_name(&"key")) == "hp" and String(e.get_name(&"reason")) == "regen" and e.get_int(&"delta") > 0: regen += StatMath.to_float(e.get_int(&"delta"))
	if label.contains("回春"): print("GS975 　　生命回复共 %.0f；开战时回复轴 %s" % [regen, str(me.axes)])
	var gear := me.baseline.total_of(BattleStats.MAX_ARMOR) if me.baseline != null else 0
	print("GS975 %s：放下 %s；护甲回复 %d 次共 %.0f；受击 %d 下、被格挡共 %.0f；回春最多 %d 层，前几次 %s；%.1f 秒" % [label, str(placed), armor_heal_n, armor_heal, hits, block, rejuv_max, str(rejuv_up), br.duration_sec()])
	run.dispose()

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	# 黎明
	_sim("日神 黎明 ×1，穿骑士板甲", &"sun", {"god_sun_dawnlight": 1}, ["knife", "knight_plate"])
	_sim("日神 黎明 ×2，穿骑士板甲", &"sun", {"god_sun_dawnlight": 2}, ["knife", "knight_plate"])
	_sim("日神 黎明 ×1，穿皮甲", &"sun", {"god_sun_dawnlight": 1}, ["knife", "leather_armor"])
	_sim("日神 黎明 ×1，没穿防具", &"sun", {"god_sun_dawnlight": 1}, ["knife"])
	_sim("日神 对照（没黎明），穿骑士板甲", &"sun", {}, ["knife", "knight_plate"])
	# 夜幕
	_sim("日神 夜幕 ×1，鸢盾", &"sun", {"god_sun_veil": 1}, ["knife", "kite_shield"])
	_sim("日神 夜幕 ×2，鸢盾", &"sun", {"god_sun_veil": 2}, ["knife", "kite_shield"])
	_sim("日神 对照（没夜幕），鸢盾", &"sun", {}, ["knife", "kite_shield"])
	_sim("日神 夜幕 ×1，没盾", &"sun", {"god_sun_veil": 1}, ["knife"])
	# 招架
	_sim("技巧 招架 ×1，骑士板甲", &"skill", {"god_skill_parry": 1}, ["knife", "knight_plate"])
	_sim("技巧 招架 ×2，骑士板甲", &"skill", {"god_skill_parry": 2}, ["knife", "knight_plate"])
	_sim("技巧 招架 ×1，没穿防具", &"skill", {"god_skill_parry": 1}, ["knife"])
	_sim("技巧 对照（没招架），骑士板甲", &"skill", {}, ["knife", "knight_plate"])
	# 回春
	_sim("自然 回春 ×1，没药", &"nature", {"god_nature_rejuv": 1}, ["knife"])
	_sim("自然 回春 ×1，绷带 4 卷", &"nature", {"god_nature_rejuv": 1}, ["knife", "bandage", "bandage", "bandage", "bandage"])
	_sim("自然 回春 ×1，绷带 8 卷", &"nature", {"god_nature_rejuv": 1}, ["knife", "bandage", "bandage", "bandage", "bandage", "bandage", "bandage", "bandage", "bandage"])
	_sim("自然 回春 ×1，干草药 4 束", &"nature", {"god_nature_rejuv": 1}, ["knife", "dried_herbs", "dried_herbs", "dried_herbs", "dried_herbs"])
	_sim("自然 回春 ×2，绷带 8 卷", &"nature", {"god_nature_rejuv": 2}, ["knife", "bandage", "bandage", "bandage", "bandage", "bandage", "bandage", "bandage", "bandage"])
	var run := G._start(75, &"sun")
	var lv := LevelModule.of(run)
	for lang in ["zh", "en"]:
		UiText.lang = lang
		for cid in ["god_sun_dawnlight", "god_sun_veil", "god_skill_parry", "god_nature_rejuv", "god_brute_blood"]:
			print("GS975 牌面 %s %s：%s" % [lang, cid, lv.card_text(StringName(cid))])
	run.dispose()
	print("GS975 完")
	quit(0)
