## 136（作者定，五项待定按推荐）：三个角色各一套 —— 初始面板 + 技能（修订：没有身份这一层，科技对谁都生效）。
## 256 定稿：安德烈乌斯 = 偷袭 / 求饶；布鲁图斯没有技能；马库斯 = 操练 + 军功牌。删掉的那些（熟门熟路、溜得掉、脱身、野地里长大、
## 咬牙、军功、突击）构件还在，用副本测。期望从角色文件推：文件里写多少就断言多少。
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _skill_of(ch: CharacterDef, script: Script) -> RunSkill:
	for s in ch.skills:
		if s != null and s.get_script() == script:
			return s
	return null


static func _effect_of(ch: CharacterDef, script: Script) -> RunEffect:
	for e in ch.run_effects():
		if e.get_script() == script:
			return e
	return null


## 256：脱身从安德烈乌斯身上删了（类留着，猎手事件屏那一项跟着）—— 测构件用一个只带脱身的副本
## 256：一个只带这几条一局被动的副本（构件测试用）
static func _with_passive(base: CharacterDef, effects: Array[Effect]) -> CharacterDef:
	var ch := base.duplicate(true) as CharacterDef
	var p := PassiveSkill.new()
	p.id = &"probe"
	p.display_name = "probe"
	p.passive = effects
	ch.skills = [p] as Array[RunSkill]
	return ch


static func _slipper(base: CharacterDef) -> CharacterDef:
	var ch := base.duplicate(true) as CharacterDef
	var sl := SlipSkill.new()
	sl.id = &"slip"
	sl.display_name = "脱身"
	sl.uses = 2
	sl.cooldown_steps = 4
	ch.skills = [sl] as Array[RunSkill]
	return ch


## 一个可以来回走的点：current 的某个邻居，那个邻居能走回来
static func _ping_pong(travel: MapTravel) -> int:
	for id in travel.available_moves():
		if MapNavigator.available_moves(travel.graph, id).has(travel.current_id):
			return id
	return -1


static func run_travel_discount(t: TestCase) -> void:
	t.begin("136 · 熟门熟路（构件；256 从安德烈乌斯身上删了）：付过 N 步之后的那一步不花行动点（预览也是 0），之后重新数；计数跟着存档；没有它的角色不免")
	var c := CS._content()
	var marcus := CS._character(c, &"marcus")
	var probe := _with_passive(CS._character(c, &"andreus"), [TravelDiscount.new()] as Array[Effect])
	var fx := _effect_of(probe, TravelDiscount) as TravelDiscount
	t.is_null(_effect_of(CS._character(c, &"andreus"), TravelDiscount), "256：安德烈乌斯没有熟门熟路了")
	var s := CS._start(c, probe)
	t.eq(s.travel.free_step_every, fx.every, "旅程读到每 %d 步" % fx.every)
	t.eq(CS._start(c, marcus).travel.free_step_every, 0, "马库斯没有")
	# 只测旅程：节点的事与猎手闸门摘掉，来回走两点
	var tr := s.travel
	tr.on_node_event = Callable()
	tr.arrival_gate = Callable()
	tr.erosion = null
	var a := tr.current_id
	var b := _ping_pong(tr)
	t.check(b >= 0, "有能来回走的一对点")
	if b < 0:
		return
	var costs: Array[int] = []
	var previews: Array[int] = []
	for i in fx.every * 2 + 2:
		var to := b if tr.current_id == a else a
		var intent := MapNavigator.resolve_step(tr.graph, tr.current_id, to)
		previews.append(tr.cost_of(intent))
		var before := tr.clock.total
		var ok := tr.step_to(to)
		if not ok:
			t.check(false, "第 %d 步走不动" % (i + 1))
			return
		costs.append(tr.clock.total - before)
		if i == 1:
			var back := MapTravel.from_dict(JSON.parse_string(JSON.stringify(tr.to_dict())), tr.graph)
			t.eq(back.paid_steps, 2, "读档：已经付过 2 步")
	t.eq(previews, costs, "预览和真花的一样：%s" % [costs])
	for i in costs.size():
		var free_here := (i + 1) % (fx.every + 1) == 0
		if free_here:
			t.eq(costs[i], 0, "第 %d 步免费" % (i + 1))
		else:
			t.check(costs[i] > 0, "第 %d 步照花（%d）" % [i + 1, costs[i]])
	t.eq(tr.last_cost, costs[costs.size() - 1], "日志读 last_cost")


static func run_slip(t: TestCase) -> void:
	t.begin("136 · 脱身（构件，256 起没有角色带它）：战前准备时用 —— 不打、点用过、没战利品、不扣体力、次数减一；地图上 / 核心点用不了；搜索遭遇按打输收会话但不弹「被赶跑」")
	var c := CS._content()
	var andreus := _slipper(CS._character(c, &"andreus"))
	var s := CS._start(c, andreus)
	var slip := _skill_of(andreus, SlipSkill)
	t.not_null(slip, "副本有脱身")
	if s == null or slip == null:
		return
	t.check(not slip.map_usable(), "地图右栏上按钮灰着")
	t.eq(s.use_skill(slip.id), "只能在开战前用", "没有等着开打的一场：用不了")
	var node := CS._battle_node(s)
	var v0 := s.vitality.current
	var m0 := s.wallet.balance
	var uses0 := s.skills.uses_of(slip.id)
	s.events.pending_battle = {"node": node.id, "type": "core", "content": node.content, "kind": "node"}
	t.eq(s.use_skill(slip.id), "这里溜不掉", "核心点溜不掉")
	t.eq(s.skills.uses_of(slip.id), uses0, "没扣次数")
	var skipped: Array = []
	s.events.battle_skipped.connect(func(n: MapNode): skipped.append(n.id))
	s.events.pending_battle = {"node": node.id, "type": "battle", "content": node.content, "kind": "node"}
	t.eq(s.use_skill(slip.id), "", "普通战斗：溜了")
	t.check(s.events.pending_battle.is_empty(), "等着开打的一场没了")
	t.check(node.is_visited(), "点算用过")
	t.eq(skipped, [node.id], "发了 battle_skipped")
	t.eq(s.vitality.current, v0, "体力不变")
	t.eq(s.wallet.balance, m0, "没进账")
	t.check(s.pending_loot == null, "没有战利品")
	t.eq(s.skills.uses_of(slip.id), uses0 - 1, "次数减一")
	t.eq(s.skills.cooldown_of(slip.id), slip.cooldown_steps, "冷却 %d 步" % slip.cooldown_steps)

	# 搜索遭遇：会话收掉（原因 slipped），不弹「被赶跑」
	var s2 := CS._start(c, andreus)
	var search: MapNode = null
	for id in s2.map.node_ids():
		var n := s2.map.get_node(id)
		if n.type == &"search" and not n.is_visited():
			search = n
			break
	t.not_null(search, "图上有搜索点")
	if search == null:
		return
	s2.events._open_search(search, false)
	t.not_null(s2.events.current_search, "会话开着")
	var reasons: Array = []
	s2.events.search_closed.connect(func(_n: MapNode, _h: GridInventory, why: StringName): reasons.append(why))
	s2.events.pending_battle = {"node": search.id, "type": "search", "content": node.content, "kind": "search", "loss_cost": 0}
	t.eq(s2.use_skill(slip.id), "", "搜索遭遇：溜了")
	t.check(s2.events.current_search == null, "会话收掉")
	t.eq(reasons, [&"slipped"], "收会话的原因是 slipped")
	t.check(s2.events.pending.is_empty(), "没弹「被赶跑」")
	t.check(search.is_visited(), "点算用过")
	t.eq(preload("res://ui/game/map_screen.gd").search_end_text(&"slipped"), "溜走了，这个点不能再搜", "日志一句")


static func run_slip_vs_hunter(t: TestCase) -> void:
	t.begin("136 · 脱身对猎手（构件）：开打前的事件屏多一项「脱身（必定逃掉）」，成功率 0 也逃得掉、记一次技能的账；用不了时那一项锁着")
	var c := CS._content()
	var andreus := _slipper(CS._character(c, &"andreus"))
	var hid: Array = c.hunter_defs.keys()
	hid.sort()
	if hid.is_empty():
		t.check(false, "没有猎手定义")
		return
	var defs := {}
	var hdef: HunterDef = (c.hunter_defs[hid[0]] as HunterDef).duplicate(true)
	hdef.engage_range = 0.0
	hdef.speed = 0
	hdef.flee_chance = 0.0
	defs[hdef.id] = hdef
	var diff := DifficultyDef.new()
	diff.id = &"probe"
	var m := HunterMechanic.new()
	m.hunter_ids = [hdef.id] as Array[StringName]
	m.spawn_min_distance = 0.0
	diff.mechanics.append(m)
	var s := CS._start(c, andreus, diff, defs)
	if s == null:
		t.check(false, "开不了局")
		return
	s.step_to(s.travel.available_moves()[0])     # 猎手在第一步之后出现（同躲避那条用例）
	var sys := s.hunters
	if sys.alive().is_empty():
		t.check(false, "没有猎手出现")
		return
	var h: Hunter = sys.alive()[0]
	s.events.pending = {}
	h.node_id = s.travel.current_id
	h.cooldown = 0
	t.check(sys.check_engagement(), "猎手够得着：排上事件屏")
	var ev := s.events.pending_event()
	var idx := -1
	for i in ev.options.size():
		if (ev.options[i] as EventOption).label.begins_with("脱身"):
			idx = i
	t.check(idx >= 0, "有「脱身」那一项")
	if idx < 0:
		return
	var uses0 := s.skills.uses_of(&"slip")
	t.check(s.events.choose(idx), "选了脱身")
	t.eq(h.cooldown, maxi(0, hdef.flee_cooldown), "成功率 0 也逃掉了：它歇 %d 步" % hdef.flee_cooldown)
	t.eq(s.skills.uses_of(&"slip"), uses0 - 1, "技能次数减一")
	# 冷却中：那一项锁着
	s.events.pending = {}
	h.cooldown = 0
	t.check(sys.check_engagement(), "又够得着")
	var ev2 := s.events.pending_event()
	var opt := ev2.options[idx] as EventOption
	t.ne(opt.locked_reason(s.events._event_ctx(s.current_node())), "", "冷却中：脱身锁着")


static func run_brutus(t: TestCase) -> void:
	t.begin("136 / 256 · 布鲁图斯没有技能、全靠面板（体力上限、耐力都是文件里的数）；休息多回与咬牙两个构件用副本测：休息回 规则 + n；咬牙回体力（满了不让用、有冷却）")
	var c := CS._content()
	var brutus := CS._character(c, &"brutus")
	t.check(brutus.skills.is_empty(), "256：布鲁图斯没有技能")
	var plain := CS._start(c, brutus)
	if plain == null:
		t.check(false, "开不了局")
		return
	t.eq(plain.vitality.maximum, brutus.vitality_max + c.chapter.vitality_bonus, "体力上限 = 面板（%d）" % brutus.vitality_max)
	t.eq(int(plain.effective_baseline().value_of(&"max_stamina")), int(brutus.baseline().value_of(&"max_stamina")), "耐力没有被动加成")
	t.eq(plain.buff_context().rest_bonus, 0, "没有休息多回")
	var rest := RestBonus.new()
	var probe := _with_passive(brutus, [rest] as Array[Effect])
	var sw := SecondWindSkill.new()
	sw.id = &"second_wind"
	sw.display_name = "咬牙"
	sw.uses = 2
	sw.cooldown_steps = 6
	probe.skills.append(sw)
	var s := CS._start(c, probe)
	t.eq(s.buff_context().rest_bonus, rest.amount, "上下文：休息多回 %d" % rest.amount)
	var rnode: MapNode = null
	for id in s.map.node_ids():
		if s.map.get_node(id).type == &"rest":
			rnode = s.map.get_node(id)
			break
	if rnode != null:
		s.vitality.spend(4)
		var got: Array = []
		s.events.rested.connect(func(_n: MapNode, n: int): got.append(n))
		s.events._proceed(rnode, &"rest")
		t.eq(got, [s.node_rules.rest_restore + rest.amount], "休息回 规则 + %d" % rest.amount)
	s.vitality.current = s.vitality.maximum
	t.eq(s.use_skill(sw.id), "体力是满的", "满的不让用")
	s.vitality.current = s.vitality.maximum - 2
	t.eq(s.use_skill(sw.id), "", "用了")
	t.eq(s.vitality.current, s.vitality.maximum - 2 + sw.amount, "回 %d 点" % sw.amount)
	t.ne(s.use_skill(sw.id), "", "冷却 %d 步内不能再用" % sw.cooldown_steps)


static func run_marcus(t: TestCase) -> void:
	t.begin("136 · 打赢的钱 ×倍数（构件；256 起马库斯的军功并进军功牌）；耐力回复写在面板上（149）、三人最高；耐力 65 三人最高（和布鲁图斯并列）")
	var c := CS._content()
	var marcus := CS._character(c, &"marcus")
	var probe := marcus.duplicate(true) as CharacterDef
	var merit := BattleRewardMult.new()
	var pass_skill := PassiveSkill.new()
	pass_skill.id = &"merit_probe"
	pass_skill.passive = [merit] as Array[Effect]
	probe.skills = [pass_skill] as Array[RunSkill]
	var s := CS._start(c, probe)
	if s == null:
		t.check(false, "开不了局")
		return
	var node := CS._battle_node(s)
	var base := s.economy.battle_reward(int(node.content.get("strength", 0)), float(s.events._depths.get(node.id, 0.0)), s.events.difficulty)
	var m0 := s.wallet.balance
	s.events._pay_battle_reward(node, node.content)
	t.eq(s.wallet.balance - m0, int(roundf(float(base) * merit.factor)), "进账 = %d × %.2f" % [base, merit.factor])
	var regen := &"regen_stamina"
	t.eq(s.effective_baseline().value_of(regen), marcus.baseline().value_of(regen), "149：耐力回复就是面板上的，没有技能再加")
	var regens := {}
	for id in [&"andreus", &"brutus", &"marcus"]:
		regens[id] = CS._character(c, id).baseline().value_of(regen)
	t.check(regens[&"marcus"] > regens[&"andreus"] and regens[&"marcus"] > regens[&"brutus"], "耐力回复马库斯最高：%s" % [regens])
	var stam := {}
	for id in [&"andreus", &"brutus", &"marcus"]:
		stam[id] = CS._character(c, id).baseline().value_of(&"max_stamina")
	t.check(stam[&"marcus"] > stam[&"andreus"] and stam[&"marcus"] >= stam[&"brutus"], "耐力：马库斯不低于任何人（256：布鲁图斯也是 65）%s" % [stam])
	# 三个角色打赢的钱都不乘（256：马库斯的军功被动删了）
	for id in [&"andreus", &"brutus", &"marcus"]:
		var s2 := CS._start(c, CS._character(c, id))
		t.eq(s2.buff_context().battle_reward_mult, 1.0, "%s 不乘" % id)


static func run_card_without_identity(t: TestCase) -> void:
	t.begin("136 修订 · 没有身份这一层（作者定：角色 = 初始面板 + 技能）；开局屏被动在前、主动在后各一行（166：藏着的主动不列，256：战前屏有键的照列）")
	var c := CS._content()
	for id in [&"andreus", &"brutus", &"marcus"]:
		var ch := CS._character(c, id)
		t.check(not ("identity" in ch), "%s：角色上没有身份字段" % id)
		var lines := ch.skill_lines()
		var passives := 0
		var shown_active := 0
		for sk in ch.skills:
			if not (sk as RunSkill).is_active():
				passives += 1
			elif (sk as RunSkill).shown_to_player():
				shown_active += 1
		t.eq(lines.size(), passives + shown_active, "%s：%d 行" % [id, passives + shown_active])
		for i in lines.size():
			t.check(lines[i].begins_with("被动：") if i < passives else lines[i].begins_with("主动："), "%s：%s" % [id, lines[i]])
			t.check(not lines[i].contains("{"), "%s：占位符都填上了" % id)
		for sk in ch.skills:
			t.check(not ("slot" in sk), "%s：技能没有分组字段" % id)
	t.check(not RunHooks.NAMES.has(&"identity"), "没有 identity 这个 hook")
	t.check(not RunRegistry.EVENT_CONDITIONS.has(&"identity_is"), "没有 identity_is 条件")
	t.check(not ResourceLoader.exists("res://core/run/events/conditions/identity_is.gd"), "身份条件的脚本删了")
	var page := FileAccess.get_file_as_string("res://data/authoring/help_pages/characters.json")
	t.check(page.contains("科技对每个角色都生效") and not page.contains("身份"), "百科「三个角色」：科技对谁都生效，不提身份")
	t.check(not RunSkills.ACTIVE_HIDDEN or not page.contains("主动"), "166 补充一：百科不提主动技能")
