## 事件构件扩充（第 8 阶段 8-3，报告 077）：条件看步数 / 段位 / 侵蚀深度 / 身上有什么 / 点是什么；
## 后果传送（造 teleport 意图走旅程：不查边、花后果说的点、落地头一回踩上就触发）、改类型、照常发生、原地耗时、失去道具；
## 导入器校验撞车的组合；休息 / 商店点的默认事件走管线。期望从数据推：传送花几点、耗几点都读后果的字段。
extends RefCounted


class FakeErosion extends ErosionField:
	var log: Array = []
	var depths: Dictionary = {}
	func on_action(clock: ActionClock, _graph: MapGraph) -> void:
		log.append("erosion@%d" % clock.total)
	func settle(_node: MapNode) -> void:
		log.append("penalty")
	func depth_of(node: MapNode) -> int:
		return int(depths.get(node.id, -1))


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["events", "node_rules"])


static func _event(id: StringName, options: Array) -> EventDef:
	var def := EventDef.new()
	def.id = id
	def.title = String(id)
	for o in options:
		var opt := EventOption.new()
		opt.label = String(o[0])
		if o.size() > 1:
			opt.outcomes = o[1]
		if o.size() > 2:
			opt.requires = o[2]
		def.options.append(opt)
	return def


## 出生点旁边有某类型点的一局；把事件 [param eid] 放到那个点上。返回 {"run", "next"}
static func _run_with(c: TestSupport.Content, defs: Dictionary, eid: StringName, type: StringName = &"event") -> Dictionary:
	for seed in range(1, 80):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [&"bag_leather", &"rifle", &"knife"] as Array[StringName])
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == type:
					s.player_baseline = CombatantBaseline.with_hp(10000.0)
					s.event_defs = c.events.duplicate()
					for id in defs:
						s.event_defs[id] = defs[id]
					s.pick_spawn(entry)
					s.map.get_node(nid).content["event"] = String(eid)
					return {"run": s, "next": nid}
	return {}


static func run_conditions(t: TestCase) -> void:
	t.begin("事件构件 · 条件：步数 / 段位 / 侵蚀深度的区间、身上有某道具、点是什么；没接的段位与侵蚀永远不满足；说明文字")
	var ctx := EventContext.new()
	ctx.node = MapNode.new()
	ctx.node.id = 7
	ctx.node.type = &"event"
	ctx.steps = 5
	var st := StepsWithin.new()
	st.min_steps = 4
	t.check(st.check(ctx), "步数 5 ≥ 4")
	st.max_steps = 4
	t.check(not st.check(ctx), "步数 5 不在 4～4")
	t.eq(st.describe(), "需要步数 4～4", "说明")
	st.min_steps = 0
	st.max_steps = 9
	t.eq(st.describe(), "需要步数 ≤ 9", "只封顶的说明")

	var br := BracketWithin.new()
	br.min_bracket = 0
	t.check(not br.check(ctx), "没接段位（没有猎手机制）：永远不满足")
	ctx.hooks.register(&"bracket", func() -> int: return 2)
	t.check(br.check(ctx), "段位 2 ≥ 0")
	br.min_bracket = 3
	t.check(not br.check(ctx), "段位 2 < 3")
	t.eq(br.describe(), "需要段位 ≥ 3", "说明")

	var er := ErosionDepthWithin.new()
	t.check(not er.check(ctx), "没接侵蚀：永远不满足")
	var fake := FakeErosion.new()
	ctx.erosion_depth = func(n: MapNode) -> int: return fake.depth_of(n)
	t.check(not er.check(ctx), "没被侵蚀（-1）：min 0 不满足")
	fake.depths[7] = 0
	t.check(er.check(ctx), "刚被侵蚀（0）：满足")
	er.min_depth = 2
	t.check(not er.check(ctx), "深度 0 < 2")
	fake.depths[7] = 3
	t.check(er.check(ctx), "深度 3 ≥ 2")
	er.max_depth = 2
	t.check(not er.check(ctx), "深度 3 > 2")
	t.eq(ErosionDepthWithin.new().describe(), "需要这里已被侵蚀", "默认的说明")

	var items := ItemDatabase.new()
	items.load_dir()
	var board := GridInventory.new(Vector2i(8, 6))
	board.requires_bag = false
	var stash := ItemStash.new(99, 0)
	ctx.board = board
	ctx.storage = stash
	var hi := HasItem.new()
	hi.item = &"medkit"
	t.check(not hi.check(ctx), "两处都空：没有医疗包")
	t.check(stash.admit(ItemInstance.create(items.get_def(&"medkit"), 0)), "地上放一个")
	t.check(hi.check(ctx), "地上有：两处任一算")
	hi.where = HasItem.Where.BOARD
	t.check(not hi.check(ctx), "只看棋盘：没有")
	t.check(board.admit(ItemInstance.create(items.get_def(&"medkit"), 0)), "棋盘放一个")
	t.check(hi.check(ctx), "棋盘上有了")
	hi.count = 2
	hi.where = HasItem.Where.BOTH
	t.check(hi.check(ctx), "两处合计 2 件")
	hi.count = 3
	t.check(not hi.check(ctx), "合计 2 < 3")
	t.eq(hi.describe(), "需要medkit ×3", "说明")
	var any := HasItem.new()
	t.check(any.check(ctx), "item 空 = 任何道具")
	t.eq(ctx.count_item(&"", 2), 2, "数得出两处一共 2 件")

	var nt := NodeTypeIs.new()
	nt.types = [&"rest", &"shop"] as Array[StringName]
	t.check(not nt.check(ctx), "event 点不在名单")
	ctx.node.content["resolved_type"] = "rest"
	t.check(nt.check(ctx), "揭成 rest 的按 rest 算")
	t.eq(nt.describe(), "需要这是rest / shop点", "说明")

	# 都在注册表里，导入器认得
	for name in [&"steps_within", &"bracket_within", &"erosion_depth_within", &"has_item", &"node_type_is"]:
		t.check(RunRegistry.has_type(&"event_condition", name), "条件 %s 登记了" % name)
	for name in [&"teleport", &"change_node_type", &"proceed", &"pass_time", &"lose_item"]:
		t.check(RunRegistry.has_type(&"event_outcome", name), "后果 %s 登记了" % name)


static func run_travel_teleport(t: TestCase) -> void:
	t.begin("旅程 · 传送意图不查边（信任解析方），不存在的点 / 原地拒绝；原地耗时：计数 → 侵蚀 → 脚下结算，不挪人")
	var g := RingMapGenerator.new().generate(RingMapConfig.sample(5), 3)
	t.not_null(g, "生成一张图")
	if g == null:
		return
	var a: int = g.entry_ids[0]
	var dist := MapNavigator.distance_map(g, a)
	var far := -1
	for id in g.node_ids():
		if dist.has(id) and int(dist[id]) >= 3:
			far = id
			break
	t.check(far >= 0 and MapNavigator.edge_for_step(g, a, far) == null, "找一个隔 3 步、没有边直连的点")
	var clock := ActionClock.new()
	var travel := MapTravel.new(g, clock)
	var fake := FakeErosion.new()
	travel.erosion = fake
	var events: Array = []
	travel.on_node_event = func(node: MapNode): events.append(node.id)
	var refused: Array = []
	travel.refused.connect(func(_i: MoveIntent, why: String): refused.append(why))
	travel.start_at(a)
	t.check(not travel.apply(MoveIntent.step(a, far, 1)), "走一步到没有边的点：拒绝")
	t.check(not travel.apply(MoveIntent.teleport(a, 99999, 1)), "传送到不存在的点：拒绝")
	t.check(not travel.apply(MoveIntent.teleport(a, a, 1)), "传送到原地：拒绝")
	t.eq(refused.size(), 3, "三次都发了 refused")
	t.check(travel.apply(MoveIntent.teleport(a, far, 3)), "传送到没有边的点：可以")
	t.eq(travel.current_id, far, "人到了")
	t.eq(clock.total, 3, "花的是意图说的 3 点")
	t.eq(events, [far], "落地头一回踩上就触发它的事")
	t.eq(fake.log, ["erosion@3", "penalty"], "侵蚀推进、目的地结算")
	# 原地耗时
	fake.log.clear()
	var waited: Array = []
	travel.waited.connect(func(n: int): waited.append(n))
	travel.wait(0)
	t.check(waited.is_empty() and clock.total == 3, "耗 0 点 = 什么也不做")
	travel.wait(2, &"event")
	t.eq(clock.total, 5, "耗了 2 点")
	t.eq(String(clock.last_reason()), "event", "理由记进计数器")
	t.eq(fake.log, ["erosion@5", "penalty"], "计数 → 侵蚀推进 → 脚下的点结算")
	t.eq(travel.current_id, far, "没挪人")
	t.eq(waited, [2], "发了 waited")


static func run_teleport_outcome(t: TestCase) -> void:
	t.begin("事件 · 传送后果：随机 / 最近 / 最远 / 指定，按类型与步数区间挑，挑不到不传；走 RunState：清地上、花后果说的点、落地触发事件；给东西 + 传送在导入器里撞车")
	var c := _content()
	var tp := Teleport.new()
	tp.target = Teleport.Target.RANDOM
	tp.min_steps = 2
	tp.max_steps = 4
	tp.action_cost = 2
	var far := Teleport.new()
	far.target = Teleport.Target.FARTHEST
	far.min_steps = 1
	far.action_cost = 0
	var near_rest := Teleport.new()
	near_rest.target = Teleport.Target.NEAREST
	near_rest.node_types = [&"rest"] as Array[StringName]
	near_rest.unvisited_only = false
	var fixed := Teleport.new()
	fixed.target = Teleport.Target.FIXED
	fixed.action_cost = 1
	var none := Teleport.new()
	none.min_steps = 999
	var say := Say.new()
	say.text = "呼"
	var defs := {
		&"t_tp": _event(&"t_tp", [["跳", [tp, say] as Array[EventOutcome]]]),
		&"t_far": _event(&"t_far", [["远", [far] as Array[EventOutcome]]]),
		&"t_near_rest": _event(&"t_near_rest", [["歇", [near_rest] as Array[EventOutcome]]]),
		&"t_fixed": _event(&"t_fixed", [["定", [fixed] as Array[EventOutcome]]]),
		&"t_none": _event(&"t_none", [["空", [none] as Array[EventOutcome]]]),
	}
	var found := _run_with(c, defs, &"t_tp")
	t.check(not found.is_empty(), "找得到出生点旁边是事件点的种子")
	if found.is_empty():
		return
	var s: RunState = found["run"]
	var next := int(found["next"])
	# 地上先放一件：离开发生过事的点会清
	s.storage.admit(ItemInstance.create(c.items.get_def(&"medkit"), 0))
	var dropped: Array = []
	NodeStorageModule.of(s).dropped.connect(func(_id: int, items: Array): dropped.append(items.size()))
	var moved: Array = []
	s.travel.moved.connect(func(i: MoveIntent, first: bool): moved.append([i.kind, i.from_id, i.to_id, i.action_cost, first]))
	var resolved: Array = []
	s.events.event_resolved.connect(func(_n: MapNode, _o: StringName, d: Dictionary): resolved.append(d))
	t.check(s.step_to(next), "走上事件点")
	var before := s.travel.clock.total
	var dist := MapNavigator.distance_map(s.map, next)
	t.check(s.events.choose(0), "跳")
	t.eq(moved.size(), 2, "两次移动：走上去、传送走")
	if moved.size() == 2:
		var m: Array = moved[1]
		t.eq([m[0], m[1], m[3]], [MoveIntent.TELEPORT, next, 2], "第二次是 teleport 意图，从事件点出发，花后果说的 2 点")
		var to := int(m[2])
		t.check(dist.has(to) and int(dist[to]) >= 2 and int(dist[to]) <= 4, "目的地隔 2～4 步（%s）" % str(dist.get(to, "?")))
		t.eq(s.travel.current_id, to, "人到了")
		t.check(bool(m[4]), "落地是头一回踩上")
		t.eq(int((resolved[0] as Dictionary).get("teleported", -1)), to, "detail 里记了传到哪")
	t.eq(s.travel.clock.total, before + 2, "行动点 = 传送的代价")
	t.check(s.map.get_node(next).is_visited(), "事件点用过了")
	t.eq(dropped, [1], "离开发生过事的点：地上清了（规则一致，导入器因此不许「给东西 + 传送」）")
	t.check(s.events.pending_event() != null or s.map.get_node(s.travel.current_id).is_visited() or s.events.current_search != null or s.events.current_shop != null,
		"落地的点已经发生了：等着选、或用过了、或开了会话")

	# 最远、指定、最近某类型、挑不到
	var f2 := _run_with(c, defs, &"t_far")
	if not f2.is_empty():
		var s2: RunState = f2["run"]
		var n2 := int(f2["next"])
		s2.step_to(n2)
		var d2 := MapNavigator.distance_map(s2.map, n2)
		var best := 0
		for id in d2:
			if s2.map.get_node(id).state == MapNode.State.UNVISITED:
				best = maxi(best, int(d2[id]))
		var t0 := s2.travel.clock.total
		s2.events.choose(0)
		t.eq(int(d2.get(s2.travel.current_id, -1)), best, "最远：落在离事件点最远的没用过的点")
		t.eq(s2.travel.clock.total, t0, "代价 0 = 白送")
	var f3 := _run_with(c, defs, &"t_fixed")
	if not f3.is_empty():
		var s3: RunState = f3["run"]
		var n3 := int(f3["next"])
		s3.step_to(n3)
		var target := -1
		for id in s3.map.node_ids():
			if id != n3 and id != s3.travel.history[0] and MapNavigator.edge_for_step(s3.map, n3, id) == null:
				target = id
				break
		s3.map.get_node(n3).content[Teleport.CONTENT_KEY] = target
		s3.events.choose(0)
		t.eq(s3.travel.current_id, target, "指定：内容里写的点")
	var f4 := _run_with(c, defs, &"t_near_rest")
	if not f4.is_empty():
		var s4: RunState = f4["run"]
		var n4 := int(f4["next"])
		s4.step_to(n4)
		var d4 := MapNavigator.distance_map(s4.map, n4)
		var nearest := 999
		for id in d4:
			if id != n4 and NodeEvents.effective_type(s4.map.get_node(id)) == &"rest":
				nearest = mini(nearest, int(d4[id]))
		s4.events.choose(0)
		if nearest < 999:
			var landed := s4.map.get_node(s4.travel.current_id)
			t.check(NodeEvents.effective_type(landed) == &"rest" and int(d4[landed.id]) == nearest, "最近的休息点")
		else:
			t.eq(s4.travel.current_id, n4, "这张图没有休息点：不传")
	var f5 := _run_with(c, defs, &"t_none")
	if not f5.is_empty():
		var s5: RunState = f5["run"]
		var n5 := int(f5["next"])
		s5.step_to(n5)
		var t5 := s5.travel.clock.total
		s5.events.choose(0)
		t.eq(s5.travel.current_id, n5, "挑不到目的地：不传")
		t.eq(s5.travel.clock.total, t5, "也不花点")
		t.check(s5.map.get_node(n5).is_visited(), "点照样用过了")

	# 导入器：撞车的组合
	var ictx := ContentImporter.Context.new()
	for id in c.items.ids():
		ictx.items[id] = c.items.get_def(id)
	var bad := {"id": "x", "title": "x", "options": [
		{"label": "a", "outcomes": [{"type": "teleport"}, {"type": "open_search"}]},
		{"label": "b", "outcomes": [{"type": "teleport"}, {"type": "give_item", "item": "salve"}]},
		{"label": "c", "outcomes": [{"type": "teleport", "action_cost": -1, "min_steps": 5, "max_steps": 2, "node_types": ["nope"]}]},
		{"label": "d", "outcomes": [{"type": "change_node_type", "node_type": "spawn"}]},
		{"label": "e", "outcomes": [{"type": "lose_item", "item": "nope"}, {"type": "pass_time", "actions": 0}]},
		{"label": "f", "requires": [{"type": "has_item", "item": "nope"}, {"type": "node_type_is"}, {"type": "steps_within", "min_steps": 5, "max_steps": 1}]},
	]}
	var rep := ImportReport.new()
	ContentImporter.import_event(bad, ictx, rep)
	var text := rep.to_text()
	for needle in ["会话就断了", "地上会清空", "代价不能是负的", "步数区间反了", "认不得的节点类型 'nope'", "结构性的类型", "找不到道具 'nope'", "耗时得是正数", "名单是空的"]:
		t.check(text.contains(needle), "导入器报：%s" % needle)
	var good := {"id": "y", "title": "y", "options": [
		{"label": "a", "outcomes": [{"type": "teleport", "target": "nearest", "node_types": ["rest"]}, {"type": "spend_vitality"}]},
		{"label": "b", "requires": [{"type": "has_item", "item": "salve"}], "outcomes": [{"type": "lose_item", "item": "salve"}]},
	]}
	var rep2 := ImportReport.new()
	var def := ContentImporter.import_event(good, ictx, rep2)
	t.check(rep2.ok() and def != null, "合法的过：%s" % rep2.to_text())


static func run_type_proceed_wait_lose(t: TestCase) -> void:
	t.begin("事件 · 改类型 + 开战按新类型打；照常发生（休息点回体力 / 商店开店）；原地耗时给猎手回合、进 detail；失去道具：最值钱 / 指定 / 数量")
	var c := _content()
	var to_battle := ChangeNodeType.new()
	to_battle.node_type = &"battle"
	var fight := StartBattle.new()
	var proceed := Proceed.new()
	var wait := PassTime.new()
	wait.actions = 3
	var lose_top := LoseItem.new()
	lose_top.pick = LoseItem.Pick.MOST_VALUABLE
	lose_top.where = LoseItem.Where.BOARD
	var lose_id := LoseItem.new()
	lose_id.pick = LoseItem.Pick.BY_ID
	lose_id.item = &"medkit"
	lose_id.count = 2
	var need := HasItem.new()
	need.item = &"medkit"
	need.count = 2
	var defs := {
		&"t_smash": _event(&"t_smash", [["砸", [to_battle, fight] as Array[EventOutcome]]]),
		&"t_rest": _event(&"t_rest", [["歇", [proceed] as Array[EventOutcome]], ["扎营", [wait, proceed] as Array[EventOutcome]], ["走"]]),
		&"t_shop": _event(&"t_shop", [["进", [proceed] as Array[EventOutcome]]]),
		&"t_lose": _event(&"t_lose", [["献", [lose_top] as Array[EventOutcome]], ["交两个", [lose_id] as Array[EventOutcome], [need] as Array[EventCondition]]]),
	}
	# 改类型 + 开战
	var f := _run_with(c, defs, &"t_smash")
	if not f.is_empty():
		var s: RunState = f["run"]
		var n := int(f["next"])
		var typed: Array = []
		s.events.type_changed.connect(func(node: MapNode, type: StringName): typed.append([node.id, type]))
		var fights: Array = []
		s.events.battle_finished.connect(func(node: MapNode, _r: BattleResult, _w: bool): fights.append(node.id))
		var resolved: Array = []
		s.events.event_resolved.connect(func(_n: MapNode, _o: StringName, d: Dictionary): resolved.append(d))
		s.step_to(n)
		s.events.choose(0)
		t.eq(typed, [[n, &"battle"]], "发了 type_changed")
		t.eq(NodeEvents.effective_type(s.map.get_node(n)), &"battle", "这个点从此算战斗点")
		t.eq(fights, [n], "打了一场")
		t.eq(String((resolved[0] as Dictionary).get("type_changed", "")), "battle", "detail 里记了")
		t.check(s.map.get_node(n).is_visited(), "用过了")
	# 照常发生：休息
	var fr := _run_with(c, defs, &"t_rest", &"rest")
	t.check(not fr.is_empty(), "找得到出生点旁边是休息点的种子")
	if not fr.is_empty():
		var s: RunState = fr["run"]
		var n := int(fr["next"])
		s.vitality.spend(2, &"test")
		var vit := s.vitality.current
		var rested: Array = []
		s.events.rested.connect(func(_n: MapNode, got: int): rested.append(got))
		s.step_to(n)
		t.eq(String(s.events.pending_event().id), "t_rest", "休息点先停下等选")
		t.eq(s.vitality.current, vit, "还没回")
		s.events.choose(0)
		t.eq(rested, [c.node_rules.rest_restore], "照常发生：回了规则说的 %d 点" % c.node_rules.rest_restore)
		t.eq(s.vitality.current, mini(vit + c.node_rules.rest_restore, s.vitality.maximum), "体力回了")
		t.check(s.map.get_node(n).is_visited(), "用过了")
		# 扎营：耗时
		var fr2 := _run_with(c, defs, &"t_rest", &"rest")
		var s2: RunState = fr2["run"]
		var n2 := int(fr2["next"])
		var waited: Array = []
		s2.events.waited.connect(func(_n: MapNode, k: int): waited.append(k))
		var resolved2: Array = []
		s2.events.event_resolved.connect(func(_n: MapNode, _o: StringName, d: Dictionary): resolved2.append(d))
		s2.step_to(n2)
		var t0 := s2.travel.clock.total
		s2.events.choose(1)
		t.eq(s2.travel.clock.total, t0 + 3, "耗了后果说的 3 点")
		t.eq(waited, [3], "发了 waited")
		t.eq(int((resolved2[0] as Dictionary).get("waited", 0)), 3, "detail 里记了")
		t.eq(s2.travel.current_id, n2, "没挪人")
		# 走：不休息，点也不算用过（反馈：休息点离开不消耗，回头还能来）
		var fr3 := _run_with(c, defs, &"t_rest", &"rest")
		var s3: RunState = fr3["run"]
		var n3 := int(fr3["next"])
		s3.vitality.spend(2, &"test")
		var v3 := s3.vitality.current
		s3.step_to(n3)
		s3.events.choose(2)
		t.eq(s3.vitality.current, v3, "走了：没回")
		t.check(not s3.map.get_node(n3).is_visited(), "点没用掉，留着以后用")
	# 照常发生：商店
	var fs := _run_with(c, defs, &"t_shop", &"shop")
	if not fs.is_empty():
		var s: RunState = fs["run"]
		var n := int(fs["next"])
		s.step_to(n)
		s.events.choose(0)
		t.check(s.events.current_shop != null, "照常发生：开了店")
		s.events.current_shop.leave()
		t.check(s.map.get_node(n).is_visited(), "走了用过了")
	# 失去道具
	var fl := _run_with(c, defs, &"t_lose")
	if not fl.is_empty():
		var s: RunState = fl["run"]
		var n := int(fl["next"])
		var top: ItemDef = null
		for inst in s.board.items():
			var d := (inst as ItemInstance).def
			if not d.is_bag and (top == null or ItemValue.of(d) > ItemValue.of(top)):
				top = d
		t.not_null(top, "棋盘上有不是包的东西")
		var count_before := s.board.item_count()
		var resolved: Array = []
		s.events.event_resolved.connect(func(_n: MapNode, _o: StringName, d: Dictionary): resolved.append(d))
		s.step_to(n)
		t.check(not bool(s.events.option_state(1)["ok"]), "没两个医疗包：「交两个」锁住")
		s.events.choose(0)
		t.eq(s.board.item_count(), count_before - 1, "棋盘少了一件")
		if top != null:
			t.eq((resolved[0] as Dictionary).get("items_lost", []), [top.display_name], "没的是最值钱的那件，记在 detail")
		var fl2 := _run_with(c, defs, &"t_lose")
		var s2: RunState = fl2["run"]
		var n2 := int(fl2["next"])
		s2.step_to(n2)
		# 地上一移动就清（080），所以站到点上再放
		for i in 3:
			s2.storage.admit(ItemInstance.create(c.items.get_def(&"medkit"), 0))
		t.check(bool(s2.events.option_state(1)["ok"]), "有三个：能交")
		s2.events.choose(1)
		t.eq(s2.storage.item_count(), 1, "交了两个，剩一个")


static func run_pipeline(t: TestCase) -> void:
	t.begin("事件构件 · 休息 / 商店的默认事件、裂隙、祭坛走管线；节点规则把休息 / 商店点挂上事件；描述文字不带两个冒号")
	var events := EventPlacer.load_all()
	for id in [&"rest_default", &"shop_default", &"event_rift", &"event_altar"]:
		t.check(events.has(id), "装回了 %s" % id)
	var rest: EventDef = events.get(&"rest_default", null)
	if rest != null:
		t.eq(rest.options.size(), 4, "休息点四个选项（093：多了「神坛」，没信仰时藏起来）")
		t.check(rest.options[1].outcomes[0] is PassTime and (rest.options[1].outcomes[0] as PassTime).actions == 2, "扎营耗 2 点（读数据）")
	var rift: EventDef = events.get(&"event_rift", null)
	if rift != null:
		var tp := rift.options[0].outcomes[0] as Teleport
		t.check(tp != null and tp.target == Teleport.Target.RANDOM and tp.min_steps == 2 and tp.max_steps == 5, "裂隙：随机 2～5 步")
		t.check(rift.options[1].requires[0] is StepsWithin, "第二个选项要步数")
	var altar: EventDef = events.get(&"event_altar", null)
	if altar != null:
		t.check(altar.options[0].requires[0] is HasItem and (altar.options[0].requires[0] as HasItem).where == HasItem.Where.BOARD, "祭坛：要棋盘上有东西")
		t.check(altar.options[2].outcomes[0] is ChangeNodeType, "砸了它：改类型")
	var rules: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	t.check(rules != null and rules.events_by_type.has(&"rest") and rules.events_by_type.has(&"shop"), "节点规则里休息 / 商店点挂了事件")
	for def in events.values():
		for opt in (def as EventDef).options:
			for o in (opt as EventOption).outcomes:
				var text := (o as EventOutcome).describe()
				t.check(not text.contains("：：") and text != "", "%s 的后果说明「%s」" % [(def as EventDef).id, text])
			for cnd in (opt as EventOption).requires:
				t.check((cnd as EventCondition).describe() != "", "条件有说明")
