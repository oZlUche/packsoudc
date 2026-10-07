## 136（作者定，五项待定按推荐）：三个角色各一套 —— 身份被动 + 擅长被动 + 一个主动 + 一条短板。
## 安德烈乌斯：熟门熟路（每四步免一步）/ 溜得掉（逃跑、潜行、免一败）/ 脱身（战前溜走，猎手面前必定逃掉）；
## 布鲁图斯：野地里长大（休息多回、侵蚀少扣）/ 坚韧（低血一次性护盾）/ 咬牙（回体力）；
## 马库斯：军功（打赢的钱 ×1.25）/ 操练（耐力回复 +1）/ 突击（不动）。期望从角色文件推：文件里写多少就断言多少。
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


## 一个可以来回走的点：current 的某个邻居，那个邻居能走回来
static func _ping_pong(travel: MapTravel) -> int:
	for id in travel.available_moves():
		if MapNavigator.available_moves(travel.graph, id).has(travel.current_id):
			return id
	return -1


static func run_travel_discount(t: TestCase) -> void:
	t.begin("136 · 熟门熟路：付过 N 步之后的那一步不花行动点（预览也是 0），之后重新数；计数跟着存档；别的角色没有")
	var c := CS._content()
	var andreus := CS._character(c, &"andreus")
	var marcus := CS._character(c, &"marcus")
	var fx := _effect_of(andreus, TravelDiscount) as TravelDiscount
	t.not_null(fx, "安德烈乌斯的身份被动里有熟门熟路")
	if fx == null:
		return
	var s := CS._start(c, andreus)
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
	t.begin("136 · 脱身：战前准备时用 —— 不打、点用过、没战利品、不扣体力、次数减一；地图上 / 核心点用不了；搜索遭遇按打输收会话但不弹「被赶跑」")
	var c := CS._content()
	var andreus := CS._character(c, &"andreus")
	var s := CS._start(c, andreus)
	var slip := _skill_of(andreus, SlipSkill)
	t.not_null(slip, "安德烈乌斯有脱身")
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
	t.begin("136 · 脱身对猎手：开打前的事件屏多一项「脱身（必定逃掉）」，成功率 0 也逃得掉、记一次技能的账；用不了时那一项锁着")
	var c := CS._content()
	var andreus := CS._character(c, &"andreus")
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
	var fled: Array = []
	sys.fled.connect(func(_h: Hunter, ok: bool): fled.append(ok))
	t.check(s.events.choose(idx), "选了脱身")
	t.eq(fled, [true], "成功率 0 也逃掉了")
	t.eq(h.cooldown, maxi(0, hdef.flee_cooldown), "它歇 %d 步" % hdef.flee_cooldown)
	t.eq(s.skills.uses_of(&"slip"), uses0 - 1, "技能次数减一")
	# 冷却中：那一项锁着
	s.events.pending = {}
	h.cooldown = 0
	t.check(sys.check_engagement(), "又够得着")
	var ev2 := s.events.pending_event()
	var opt := ev2.options[idx] as EventOption
	t.ne(opt.locked_reason(s.events._event_ctx(s.current_node())), "", "冷却中：脱身锁着")


static func run_brutus(t: TestCase) -> void:
	t.begin("136 · 布鲁图斯：基线 60 / 60 / 6（被动不再加数）；休息多回、侵蚀少扣（最少扣零）；咬牙回体力（满了不让用）；坚韧低血一次性护盾")
	var c := CS._content()
	var brutus := CS._character(c, &"brutus")
	var s := CS._start(c, brutus)
	if s == null:
		t.check(false, "开不了局")
		return
	t.eq(s.vitality.maximum, brutus.vitality_max, "体力上限 = 基线（%d）" % brutus.vitality_max)
	t.eq(int(s.effective_baseline().value_of(&"max_stamina")), int(brutus.baseline().value_of(&"max_stamina")), "耐力没有被动加成")
	var ctx := s.buff_context()
	var rest := _effect_of(brutus, RestBonus) as RestBonus
	var resist := _effect_of(brutus, ErosionResist) as ErosionResist
	t.check(rest != null and resist != null, "身份被动：休息多回 + 侵蚀少扣")
	t.eq(ctx.rest_bonus, rest.amount, "上下文：休息多回 %d" % rest.amount)
	# 休息
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
	# 侵蚀
	for pair in [[resist.amount + 1, 1], [resist.amount, 0]]:
		var fx := ErodeSpendVitality.new()
		fx.amount = int(pair[0])
		var ec := ErosionContext.new()
		ec.run = s
		var v := s.vitality.current
		fx.apply(ec)
		t.eq(v - s.vitality.current, int(pair[1]), "侵蚀扣 %d → 实扣 %d" % pair)
	# 咬牙
	var sw := _skill_of(brutus, SecondWindSkill) as SecondWindSkill
	t.not_null(sw, "主动：咬牙")
	s.vitality.current = s.vitality.maximum
	t.eq(s.use_skill(sw.id), "体力是满的", "满的不让用")
	var uses0 := s.skills.uses_of(sw.id)
	t.eq(s.skills.uses_of(sw.id), uses0, "没扣次数")
	s.vitality.current = s.vitality.maximum - 2
	t.eq(s.use_skill(sw.id), "", "用了")
	t.eq(s.vitality.current, s.vitality.maximum - 2 + sw.amount, "回 %d 点" % sw.amount)
	t.ne(s.use_skill(sw.id), "", "冷却 %d 步内不能再用" % sw.cooldown_steps)
	# 坚韧：编进玩家的单位规则；空手挨打，生命掉到三成以下时护盾出现一次
	var me := s.compile_player()
	var has_rule := false
	for r in me.set_rules:
		if (r as AbilityRule).trigger is OnResourceBelow:
			has_rule = true
	t.check(has_rule, "坚韧的规则挂到了玩家单位上")
	var core: MapNode = null
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if EnemyKit.has_enemy(n.content) and (core == null or int(n.content.get("strength", 0)) > int(core.content.get("strength", 0))):
			core = n
	var enemy := EnemyKit.spec_of(core.content, c.enemies, s.pool, c.items)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var result := BattleSim.run(me, enemy, rng, 120.0)
	var applied := 0
	for e in result.log:
		var be := e as BattleEvent
		if be.name == BattleEvent.STATUS_STACKED and be.side == 0 and String(be.payload.get("buff", "")) == "hardy_guard":
			applied += 1
	t.eq(applied, 1, "护盾出现一次（这一场玩家%s）" % ("赢了" if result.winner == 0 else "没赢"))


static func run_marcus(t: TestCase) -> void:
	t.begin("136 · 马库斯：打赢的钱 ×军功（四舍五入）；操练让耐力回复 +1；耐力 65 是三人唯一最高")
	var c := CS._content()
	var marcus := CS._character(c, &"marcus")
	var s := CS._start(c, marcus)
	if s == null:
		t.check(false, "开不了局")
		return
	var merit := _effect_of(marcus, BattleRewardMult) as BattleRewardMult
	t.not_null(merit, "身份被动：军功")
	var node := CS._battle_node(s)
	var base := s.economy.battle_reward(int(node.content.get("strength", 0)), float(s.events._depths.get(node.id, 0.0)), s.events.difficulty)
	var m0 := s.wallet.balance
	s.events._pay_battle_reward(node, node.content)
	t.eq(s.wallet.balance - m0, int(roundf(float(base) * merit.factor)), "进账 = %d × %.2f" % [base, merit.factor])
	var regen := &"regen_stamina"
	t.eq(s.effective_baseline().value_of(regen), marcus.baseline().value_of(regen) + 1.0, "耐力回复 +1")
	var stam := {}
	for id in [&"andreus", &"brutus", &"marcus"]:
		stam[id] = CS._character(c, id).baseline().value_of(&"max_stamina")
	t.check(stam[&"marcus"] > stam[&"andreus"] and stam[&"marcus"] > stam[&"brutus"], "耐力：%s" % [stam])
	# 别的角色打赢的钱不乘
	var s2 := CS._start(c, CS._character(c, &"brutus"))
	t.eq(s2.buff_context().battle_reward_mult, 1.0, "布鲁图斯不乘")


static func run_identity_and_card(t: TestCase) -> void:
	t.begin("136 · 身份字段（奴隶 / 军团士兵）给事件条件用；开局屏按「身份 / 擅长 / 主动」各一行")
	var c := CS._content()
	var want := {&"andreus": &"slave", &"brutus": &"slave", &"marcus": &"legion"}
	for id in want:
		var ch := CS._character(c, id)
		t.eq(ch.identity, want[id], "%s 的身份" % id)
		var s := CS._start(c, ch)
		t.eq(s.hooks.identity(), want[id], "%s：一局里查得到" % id)
		var cond := IdentityIs.new()
		cond.identities = [&"legion"] as Array[StringName]
		t.eq(cond.check(s.events._event_ctx(s.current_node())), want[id] == &"legion", "%s：条件「身份是军团士兵」" % id)
		var lines := ch.skill_lines()
		t.eq(lines.size(), 3, "%s：三行" % id)
		if lines.size() == 3:
			t.check(lines[0].begins_with("身份：") and lines[1].begins_with("擅长：") and lines[2].begins_with("主动："), "%s：%s" % [id, " / ".join(lines)])
			t.check(not lines[0].contains("{"), "%s：占位符都填上了" % id)
