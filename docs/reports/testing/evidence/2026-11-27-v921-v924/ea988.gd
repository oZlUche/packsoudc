extends SceneTree
## 测试 v9.21（PR #988）无头：大地之神 —— 真实开局里的天地分层、选牌、穿行、扎营、压缩、结晶堆叠、神殿开放、开战效果
const G := preload("res://tests/run/test_god_cards_388.gd")
var pool: EnemyPool
var enemies: EnemyDatabase
var bad := 0

func _bad(m: String) -> void:
	bad += 1
	print("EA988 不对：", m)

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

func _layout(run: RunState) -> String:
	var b := run.board
	var deep: Dictionary = EarthHeaven.depths(b)
	var roles: Dictionary = EarthHeaven.roles(b)
	var rows := []
	for y in b.size.y:
		var s := ""
		for x in b.size.x:
			var c := Vector2i(x, y)
			if b.is_blocked(c): s += "#"; continue
			var it: ItemInstance = null
			var ch := str(int(deep.get(c, -1)))
			if it != null and roles.has(it.uid):
				ch = {EarthHeaven.GROUND: "G", EarthHeaven.DOME: "D", EarthHeaven.PILLAR: "P"}[roles[it.uid]]
			s += ch
		rows.append(s)
	return "\n".join(rows)

func _layers() -> void:
	var run := G._start(3, &"earth")
	for bg in [&"war_pack", &"bag_leather", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(bg))
	for id in ["knife", "knife", "knife", "earth_crystal", "earth_crystal", "earth_crystal", "earth_crystal", "knight_plate", "kite_shield"]:
		TestSupport.put(run.board, run.items.get_def(StringName(id)))
	var roles: Dictionary = EarthHeaven.roles(run.board)
	var deep: Dictionary = EarthHeaven.depths(run.board)
	var top := 0
	for c in deep: top = maxi(top, int(deep[c]))
	print("EA988 分层 真实开局棋盘 %s，离边界最多 %d 圈；大地 %d、穹顶 %d、支柱 %d" % [str(run.board.size), top, EarthHeaven.count_of(roles, EarthHeaven.GROUND), EarthHeaven.count_of(roles, EarthHeaven.DOME), EarthHeaven.count_of(roles, EarthHeaven.PILLAR)])
	for uid in roles:
		var it := run.board.get_item(uid)
		var cells: Array = it.absolute_cells(it.cells())
		var mn := 99; var mx := -1
		for c in cells:
			mn = mini(mn, int(deep.get(c, 0))); mx = maxi(mx, int(deep.get(c, 0)))
		var want := EarthHeaven.GROUND if mn == 0 else (EarthHeaven.DOME if mx == top and top > 0 else EarthHeaven.PILLAR)
		print("EA988   %s 占 %s，圈数 %d～%d → %s" % [it.def.id, str(cells), mn, mx, roles[uid]])
		if want != roles[uid]: _bad("分层：%s 应是 %s" % [it.def.id, want])
		if run.board.acts_as_bag(it.def): _bad("包也分了层 %s" % it.def.id)
	# 挪一件小刀到中央，看会不会变成穹顶
	run.dispose()

func _pool() -> void:
	var tally := {}
	var r := LevelRules.load_rules()
	for s in 30:
		var run := G._start(700 + s, &"earth")
		var lv := LevelModule.of(run)
		var rng := RandomNumberGenerator.new(); rng.seed = s
		lv.gain(1000000.0, LevelModule.SRC_EVENT, "test")
		var guard := 0
		while lv.pending() > 0 and guard < 200:
			guard += 1
			var cp := lv.current_pick()
			var cards := lv.offer()
			if cards.is_empty(): break
			if EarthHeavenPerk.select_offer(lv):
				tally["select_offers"] = int(tally.get("select_offers", 0)) + 1
				lv.pick(0); continue
			for c in cards:
				var g := r.god_of(c)
				tally["seen:" + String(c)] = int(tally.get("seen:" + String(c), 0)) + 1
				if g != &"" and g != &"earth": _bad("大地局里出了 %s" % c)
				if bool(r.card(c).get("hidden", false)): _bad("普通选牌出了隐藏牌 %s" % c)
				if String(c) == "god_earth_refine" and lv.count_of(&"god_earth_compress") <= 0: _bad("没拿压缩就出了提炼")
				if bool(r.card(c).get("once", false)) and lv.count_of(c) > 0: _bad("专属牌又出了 %s" % c)
			var got := lv.pick(rng.randi() % cards.size())
			tally["took:" + String(got)] = int(tally.get("took:" + String(got), 0)) + 1
		if lv.pending() > 0: _bad("种子 %d 选不完（还欠 %d）" % [700 + s, lv.pending()])
		run.dispose()
	var ids := []
	for cid in r.card_ids():
		if r.god_of(cid) == &"earth" and not bool(r.card(cid).get("hidden", false)): ids.append(String(cid))
	var never := []
	for c in ids:
		if int(tally.get("seen:" + c, 0)) == 0: never.append(c)
	var parts := []
	for c in ["god_earth_jade", "god_earth_gem", "god_earth_compress", "god_earth_refine", "god_earth_tunnel", "god_earth_camp", "god_earth_select"]:
		parts.append("%s 出现 %d / 拿 %d" % [c, int(tally.get("seen:" + c, 0)), int(tally.get("took:" + c, 0))])
	print("EA988 选牌 大地之神 30 局：可出的牌 %d 张，一次都没出过的 %s；甄选窗 %d 次；%s" % [ids.size(), str(never), int(tally.get("select_offers", 0)), "；".join(parts)])

func _walk_camp() -> void:
	var walked := 0; var camped := 0; var blocked := {}
	for s in 6:
		var run := G._start(800 + s, &"earth")
		var belt := BeltModule.of(run)
		belt.add(&"earth_walk", 1)
		belt.add(&"earth_camp", 1)
		var here := run.travel.current_id
		var why0 := belt.can_use(&"earth_camp")
		blocked["开局点 " + String(NodeEvents.effective_type(run.current_node()))] = why0
		var w := belt.use(&"earth_walk")
		if w != "": _bad("穿行用不了：%s" % w); run.dispose(); continue
		var targets: Array[int] = EarthHeavenPerk.walk_targets(run)
		var again := belt.can_use(&"earth_walk")
		var dist_ok := true
		var far := -1; var far_d := -1
		for id in targets:
			var d: bool = MapNavigator.within_steps(run.map, here, 3).has(id)
			if not d: dist_ok = false
		# 挑一个休息点 / 搜索点以外最远的
		var within2: Dictionary = MapNavigator.within_steps(run.map, here, 2)
		for id in targets:
			if not within2.has(id): far = id
		if far < 0 and not targets.is_empty(): far = targets[targets.size() - 1]
		var clock0 := run.travel.clock.total if run.travel.clock != null else -1
		var ok := EarthHeavenPerk.walk_to(run, far)
		var clock1 := run.travel.clock.total if run.travel.clock != null else -1
		var node := run.current_node()
		print("EA988 穿行 种子 %d：3 步内能去 %d 个点（都在 3 步内 %s），用了之后再用「%s」；传到 %d（%s，不在 2 步内 %s），成功 %s，步数 %d → %d，还攒着 %s" % [800 + s, targets.size(), str(dist_ok), again, far, NodeEvents.effective_type(node) if node != null else "?", str(not within2.has(far)), str(ok), clock0, clock1, str(EarthHeavenPerk.walk_armed(run))])
		if ok: walked += 1
		if not ok or run.travel.current_id != far or clock1 - clock0 != 1 or EarthHeavenPerk.walk_armed(run): _bad("穿行结果不对（种子 %d）" % (800 + s))
		# 扎营：把落地点的事办完（开战的就判赢不了，直接看原因）
		var why := belt.can_use(&"earth_camp")
		var t0 := String(NodeEvents.effective_type(run.current_node()))
		if why == "":
			var u := belt.use(&"earth_camp")
			var t1 := String(NodeEvents.effective_type(run.current_node()))
			print("EA988 扎营 种子 %d：%s → %s（%s）" % [800 + s, t0, t1, u])
			if t1 != "rest": _bad("扎营后不是休息点")
			camped += 1
		else:
			blocked[t0] = why
			print("EA988 扎营 种子 %d：在 %s 上用不了：%s" % [800 + s, t0, why])
		run.dispose()
	print("EA988 穿行成功 %d 次，扎营成功 %d 次；用不了的原因 %s" % [walked, camped, str(blocked)])

func _compress() -> void:
	var run := G._start(9, &"earth")
	var lv := LevelModule.of(run)
	for bg in [&"war_pack", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(bg))
	print("EA988 压缩 没拿牌：can_compress_any %s" % str(EarthHeavenPerk.can_compress_any(run)))
	if EarthHeavenPerk.can_compress_any(run): _bad("没拿压缩就能压")
	lv.taken["god_earth_compress"] = 1
	var lines := []
	var total := 0
	var insts := []
	for id in ["knife", "knight_plate", "steel_greatsword", "kite_shield"]:
		var it := ItemInstance.create(run.items.get_def(StringName(id)))
		var n := EarthHeavenPerk.crystals_for(it)
		total += n
		insts.append(it)
		lines.append("%s 值 %d → %d 个" % [id, ItemValue.of_instance(it), n])
		if n != maxi(1, roundi(ItemValue.of_instance(it) / 5.0)): _bad("压缩个数 %s" % id)
	var bag := ItemInstance.create(run.items.get_def(&"bag_leather"))
	var cr := ItemInstance.create(run.items.get_def(&"earth_crystal"))
	print("EA988 压缩：%s；包能压 %s，结晶能压 %s" % ["，".join(lines), str(EarthHeavenPerk.can_compress(run, bag)), str(EarthHeavenPerk.can_compress(run, cr))])
	if EarthHeavenPerk.can_compress(run, bag) or EarthHeavenPerk.can_compress(run, cr): _bad("包 / 结晶也能压")
	var st := EarthHeavenPerk.compress(run, insts)
	var w := ItemWeight.of_in(st, run.board if run.board.has_item(st.uid) else run.storage)
	print("EA988 压缩 4 件 → 一摞 %d 个（应 %d），价值 %d、重量 %s，在背包里 %s" % [st.stack_count(), total, ItemValue.of_instance(st), str(w), str(run.board.has_item(st.uid))])
	if st.stack_count() != total or ItemValue.of_instance(st) != total * 5: _bad("一摞的个数 / 价值")
	# 叠：再压一件小刀，拖到一起
	var st2 := EarthHeavenPerk.compress(run, [ItemInstance.create(run.items.get_def(&"knife"))])
	var home2: ItemContainer = run.board if run.board.has_item(st2.uid) else run.storage
	var home1: ItemContainer = run.board if run.board.has_item(st.uid) else run.storage
	var n1 := st.stack_count(); var n2 := st2.stack_count()
	var merged := ItemStack.merge(st2, home2, st, home1)
	print("EA988 堆叠：%d 个那摞拖到 %d 个那摞上 → %s，现在 %d 个，原来那摞还在 %s" % [n2, n1, str(merged), st.stack_count(), str(home2.has_item(st2.uid))])
	if not merged or st.stack_count() != n1 + n2 or home2.has_item(st2.uid): _bad("堆叠")
	# 提炼：已有的结晶跟着涨；涨过的和新压的能不能叠
	lv.taken["god_earth_refine"] = 1
	EarthHeavenPerk.on_pick(lv, &"god_earth_refine")
	var v1 := ItemValue.of_instance(st)
	var st3 := EarthHeavenPerk.compress(run, [ItemInstance.create(run.items.get_def(&"knife"))])
	print("EA988 提炼 1 张：那一摞 %d 个，价值 %d（每个 %d）；新压的一摞每个 %d，能和旧的叠 %s" % [st.stack_count(), v1, v1 / maxi(1, st.stack_count()), ItemValue.of_instance(st3) / maxi(1, st3.stack_count()), str(ItemStack.can_merge(st3, st))])
	if v1 != st.stack_count() * 6: _bad("提炼后价值")
	if not ItemStack.can_merge(st3, st): _bad("提炼后新旧结晶叠不上")
	var knife := ItemInstance.create(run.items.get_def(&"knife"))
	print("EA988 不能叠：小刀叠到结晶上 %s" % str(ItemStack.can_merge(knife, st)))
	run.dispose()

func _fight() -> void:
	for s in [1, 2]:
		var run := G._start(77, &"earth")
		var lv := LevelModule.of(run)
		for bg in [&"war_pack", &"bag_leather", &"bag_leather"]: TestSupport.put(run.board, run.items.get_def(bg))
		for id in ["knife", "knife", "knight_plate", "kite_shield", "earth_crystal", "earth_crystal"]: TestSupport.put(run.board, run.items.get_def(StringName(id)))
		for k in ["god_earth_rock", "god_earth_sky", "god_earth_ram", "god_earth_heavy", "god_earth_thick", "god_earth_quake", "god_earth_ranges", "god_earth_pillar_sky"]: lv.taken[k] = 1
		var roles: Dictionary = EarthHeaven.roles(run.board, true)
		var me := run.compile_player()
		me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(5000.0)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
		var rng := RandomNumberGenerator.new(); rng.seed = s
		var br := BattleSim.run(me, _enemy(run, 2, s), rng, 30.0)
		var keys := {}
		var opening := []
		for raw in br.log:
			var e := raw as BattleEvent
			if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("key", "")).begins_with("earth_"):
				var k := String(e.payload["key"]); keys[k] = int(keys.get(k, 0)) + 1
			if e.name == BattleEvent.DAMAGE and e.side == 1 and e.time == 0:
				opening.append("%d%s" % [e.get_int(&"amount") / 10000, "真" if e.get_bool(&"pure") else ""])
		print("EA988 开战 种子 %d：大地 %d、穹顶 %d、支柱 %d；战记 %s；开战打到敌人的 %s" % [s, EarthHeaven.count_of(roles, EarthHeaven.GROUND), EarthHeaven.count_of(roles, EarthHeaven.DOME), EarthHeaven.count_of(roles, EarthHeaven.PILLAR), str(keys), str(opening)])
		run.dispose()

func _temple() -> void:
	var line := []
	for g in [&"brute", &"sun", &"nature", &"skill", &"earth", &"hunt"]:
		line.append("%s %s" % [g, str(Pantheon.temple_ready(g))])
	print("EA988 神殿开放：%s" % "，".join(line))
	if not Pantheon.temple_ready(&"earth"): _bad("大地神殿没开")

func _init() -> void:
	enemies = EnemyDatabase.new(); enemies.load_all()
	pool = ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	_temple()
	_layers()
	_pool()
	_walk_camp()
	_compress()
	_fight()
	print("EA988 合计不对 %d 处" % bad)
	print("EA988 完")
	quit(0)
