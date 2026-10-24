## 248：不打不罚、跑才罚 —— 战前屏「退回」（看得见的战斗 / 精英点，退一步、这一场留着）；
## 搜索遭遇 / 伏击 / 猎手统一的「逃跑（几成）」（节点规则 `flee`：成功照脱身收，失败扣体力、背虚弱再开打）
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _start(c: TestSupport.Content, diff: DifficultyDef = null, defs: Dictionary = {}) -> RunState:
	var s := CS._start(c, CS._character(c, &"brutus"), diff, defs)     # 布鲁图斯：没有省步的被动，步数好数
	if s != null:
		s.events.pause_before_battle = true
		s.buff_defs = RunBuffs.load_all()     # 失败背的虚弱是地图 buff
	return s


## 把规则复制一份、改逃跑成功率（规则是共享资产，别改原件）
static func _flee_rules(s: RunState, chance: float) -> void:
	var rules: NodeRules = s.events.rules.duplicate(true)
	rules.flee = {"chance": chance, "fail_vitality": 1, "fail_buff": "weakened"}
	s.events.rules = rules


## 第一步能到的一个点，改成战斗点、放上一个敌人
static func _battle_next(s: RunState) -> MapNode:
	var src := CS._battle_node(s)
	var moves := s.travel.available_moves()
	if src == null or moves.is_empty():
		return null
	var n := s.map.get_node(moves[0])
	n.type = &"battle"
	n.content = src.content.duplicate(true)
	return n


## 测试章的事件表里不一定有这几个：照内容资产补上（和正式章一样从 data/events 读）
static func _event(s: RunState, id: StringName) -> EventDef:
	if s.events.def_by_id(id) == null:
		var ev := load("res://data/events/%s.tres" % id) as EventDef
		if ev != null:
			s.events.event_defs[id] = ev
	return s.events.def_by_id(id)


static func _weak(s: RunState) -> bool:
	var bm := BuffModule.of(s)
	return bm != null and bm.has(&"weakened")


static func _option(ev: EventDef, prefix: String) -> int:
	for i in ev.options.size():
		if (ev.options[i] as EventOption).label.begins_with(prefix):
			return i
	return -1


static func run_retreat(t: TestCase) -> void:
	t.begin("248 §二：退回 —— 等着的一场清掉、点不算用过、人回到上一个点、多走一步（共两步）；再踩同一点还是这一场")
	var c := CS._content()
	var s := _start(c)
	var n := _battle_next(s) if s != null else null
	t.not_null(n, "有一步能到的点")
	if n == null:
		return
	var from := s.travel.current_id
	var clock0 := s.travel.clock.total
	var v0 := s.vitality.current
	t.check(s.step_to(n.id), "走上战斗点")
	t.check(not s.events.pending_battle.is_empty(), "停在战前屏")
	var content0 := JSON.stringify(s.events.pending_battle.get("content", {}))
	t.eq(s.events.retreat_reason(), "", "普通战斗点：能退")
	var fired: Array = []
	s.events.battle_retreated.connect(func(x: MapNode): fired.append(x.id))
	t.check(s.events.retreat_pending_battle(), "退了")
	t.check(s.events.pending_battle.is_empty(), "等着的一场清掉")
	t.check(not n.is_visited(), "点不算用过")
	t.eq(s.travel.current_id, from, "回到上一个点")
	t.eq(s.travel.clock.total - clock0, 2, "踩进 + 退回：两步")
	t.eq(s.vitality.current, v0, "不扣体力")
	t.check(not _weak(s), "不背虚弱")
	t.eq(fired, [n.id], "发了 battle_retreated")
	t.check(s.step_to(n.id), "再走上去")
	t.eq(JSON.stringify(s.events.pending_battle.get("content", {})), content0, "还是那一场（内容不变）")


static func run_retreat_where(t: TestCase) -> void:
	t.begin("248 §二：退回只给战斗 / 精英点 —— 核心点、搜索遭遇、伏击（事件点上开的）不给；序章（不走开局屏的章）不给")
	var c := CS._content()
	var s := _start(c)
	var n := _battle_next(s) if s != null else null
	if n == null:
		t.check(false, "开不了局")
		return
	t.check(s.step_to(n.id), "走上战斗点")
	var pb := s.events.pending_battle.duplicate(true)
	n.type = &"elite"
	t.eq(s.events.retreat_reason(), "", "精英点：能退")
	n.type = &"core"
	s.events.pending_battle["type"] = "core"
	t.ne(s.events.retreat_reason(), "", "核心点：退不了")
	t.check(not s.events.retreat_pending_battle(), "按了也不退")
	n.type = &"battle"
	s.events.pending_battle = pb.duplicate(true)
	s.events.pending_battle["kind"] = "search"
	t.ne(s.events.retreat_reason(), "", "搜索遭遇：退不了（走逃跑）")
	s.events.pending_battle = pb.duplicate(true)
	n.type = &"event"
	t.ne(s.events.retreat_reason(), "", "事件点上开的一场（伏击）：退不了")
	n.type = &"battle"
	var f := GameFlow.new()
	f.run = s
	t.eq(f.retreat_reason(), "", "正式章：流程层也放行")
	var ch: ChapterDef = s.chapter.duplicate()
	ch.skip_setup = true
	s.chapter = ch
	t.ne(f.retreat_reason(), "", "序章（skip_setup）：没有退回")


static func run_flee_ambush(t: TestCase) -> void:
	t.begin("248 §三：伏击的「逃跑（几成）」—— 逃掉走人、不背虚弱；没逃掉扣一点体力、背虚弱、照样开打")
	var c := CS._content()
	for chance in [1.0, 0.0]:
		var s := _start(c)
		if s == null:
			t.check(false, "开不了局")
			return
		_flee_rules(s, chance)
		var node := s.current_node()
		var ev := _event(s, &"event_ambush")
		t.not_null(ev, "伏击事件在")
		if ev == null:
			return
		var idx := _option(ev, "逃跑")
		t.check(idx >= 0 and (ev.options[idx] as EventOption).label == "逃跑（{flee_chance}%）", "「绕开」换成了「逃跑（几成）」")
		node.content = {}
		node.state = MapNode.State.UNVISITED
		s.events.set_pending(node, ev, &"event")
		var v0 := s.vitality.current
		t.check(s.events.choose(idx), "选了逃跑（成功率 %d%%）" % int(chance * 100.0))
		if chance >= 1.0:
			t.check(s.events.pending_battle.is_empty(), "逃掉：不打")
			t.eq(s.vitality.current, v0, "逃掉：不扣体力")
			t.check(not _weak(s), "逃掉：不再背虚弱")
			t.check(node.is_visited(), "逃掉：点用过")
		else:
			t.eq(s.vitality.current, v0 - 1, "没逃掉：扣一点体力")
			t.check(_weak(s), "没逃掉：背虚弱")
			t.check(not s.events.pending_battle.is_empty(), "没逃掉：照样开打（停在战前屏）")
			t.ne(s.events.retreat_reason(), "", "这一场没有退回")


static func run_flee_search(t: TestCase) -> void:
	t.begin("248 §三：搜索遭遇多了「逃跑（几成）」—— 逃掉会话按 slipped 收（不弹被赶跑、点用过）；没逃掉扣体力、背虚弱、打会话里的遭遇")
	var c := CS._content()
	for chance in [1.0, 0.0]:
		var s := _start(c)
		if s == null:
			t.check(false, "开不了局")
			return
		_flee_rules(s, chance)
		var rules: NodeRules = s.events.rules
		rules.search.encounter_curve.clear()
		rules.search.encounter_curve.append(1.0)
		rules.search.encounter_event = &"search_encounter"
		var search: MapNode = null
		for id in s.map.node_ids():
			var n := s.map.get_node(id)
			if n.type == &"search" and not n.is_visited():
				search = n
				break
		if search == null:
			t.check(false, "图上有搜索点")
			return
		_event(s, &"search_encounter")
		var reasons: Array = []
		s.events.search_closed.connect(func(_n: MapNode, _h: GridInventory, why: StringName): reasons.append(why))
		s.events._open_search(search, true)
		var ev := s.events.pending_event()
		t.check(ev != null and ev.id == &"search_encounter" and bool(s.events.pending.get("search_encounter", false)), "停在「有人来了」")
		if ev == null:
			return
		var idx := _option(ev, "逃跑")
		t.check(idx >= 0, "有「逃跑」那一项")
		var v0 := s.vitality.current
		t.check(s.events.choose(idx), "选了逃跑")
		if chance >= 1.0:
			t.check(s.events.current_search == null, "逃掉：会话收掉")
			t.eq(reasons, [&"slipped"], "收会话的原因是 slipped")
			t.check(s.events.pending.is_empty() and s.events.pending_battle.is_empty(), "逃掉：不打、不弹被赶跑")
			t.check(search.is_visited(), "逃掉：点用过")
			t.eq(s.vitality.current, v0, "逃掉：不扣体力")
		else:
			t.eq(s.vitality.current, v0 - 1, "没逃掉：扣一点体力")
			t.check(_weak(s), "没逃掉：背虚弱")
			t.eq(String(s.events.pending_battle.get("kind", "")), "search", "没逃掉：打会话里的遭遇")


static func run_flee_text(t: TestCase) -> void:
	t.begin("248 §三：「逃跑（{flee_chance}%）」的百分数由程序填 —— 规则的 chance + 逃跑加成")
	var c := CS._content()
	var s := _start(c)
	if s == null:
		t.check(false, "开不了局")
		return
	_flee_rules(s, 0.5)
	var ctx := TextTemplate.context_for(s, s.current_node())
	t.eq(int(ctx["flee_chance"]), int(roundf(clampf(0.5 + s.hooks.run_context().flee_bonus, 0.0, 1.0) * 100.0)), "{flee_chance} = 规则 + 加成")
	t.eq(TextTemplate.plain("逃跑（{flee_chance}%）", ctx), "逃跑（%d%%）" % int(ctx["flee_chance"]), "选项文字")
	# 游戏测试 v4.31：结果页标题（选项文字）也填好，不露 {flee_chance}
	var ev := _event(s, &"event_ambush")
	var f := GameFlow.new()
	f._chosen_option = ev.options[_option(ev, "逃跑")] as EventOption
	var title := f.outcome_title(s, s.current_node(), StringName(f._chosen_option.label_for()))
	t.eq(title, "逃跑（%d%%）" % int(ctx["flee_chance"]), "结果页标题填了百分数（%s）" % title)
	t.eq(f.outcome_title(s, s.current_node(), &"绕开"), "绕开", "没有占位符的原样")


static func run_flee_hunter(t: TestCase) -> void:
	t.begin("248 §三：猎手逃跑走同一把 —— 成功率、扣体力、歇几步按猎手定义；没逃掉也背虚弱")
	var c := CS._content()
	var hid: Array = c.hunter_defs.keys()
	hid.sort()
	if hid.is_empty():
		t.check(false, "没有猎手定义")
		return
	var hdef: HunterDef = (c.hunter_defs[hid[0]] as HunterDef).duplicate(true)
	hdef.engage_range = 0.0
	hdef.speed = 0
	hdef.flee_chance = 0.0001     # 0 就没有逃跑这一项（逃不掉的猎手）
	hdef.flee_fail_vitality = 1
	var diff := DifficultyDef.new()
	diff.id = &"probe"
	var m := HunterMechanic.new()
	m.hunter_ids = [hdef.id] as Array[StringName]
	m.spawn_min_distance = 0.0
	diff.mechanics.append(m)
	var s := CS._start(c, CS._character(c, &"brutus"), diff, {hdef.id: hdef})
	if s == null:
		t.check(false, "开不了局")
		return
	s.buff_defs = RunBuffs.load_all()
	s.step_to(s.travel.available_moves()[0])
	var sys := s.hunters
	if sys == null or sys.alive().is_empty():
		t.check(false, "没有猎手出现")
		return
	var h: Hunter = sys.alive()[0]
	s.events.pending = {}
	h.node_id = s.travel.current_id
	h.cooldown = 0
	t.check(sys.check_engagement(), "猎手够得着")
	var ev := s.events.pending_event()
	var idx := _option(ev, "逃跑") if ev != null else -1
	t.check(idx >= 0, "有「逃跑（几成）」")
	if idx < 0:
		return
	var spent: Array = []
	s.events.event_resolved.connect(func(_n: MapNode, _label: StringName, detail: Dictionary): spent.append(int(detail.get("spent", 0))))
	s.events.choose(idx)
	t.eq(spent, [1], "没逃掉：扣一点体力（猎手定义的 flee_fail_vitality）")
	t.check(_weak(s), "没逃掉：背虚弱（248 新加）")

