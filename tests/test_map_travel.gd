## 行动计数与单步移动（架构文档 5.6，M3-4）。
##
## 这一组守的是三件事：**结算顺序不可调换**（用假侵蚀钩子记调用次序）、
## **一切移动经过 MoveIntent**（导航器没有多步入口）、**已访问节点只能穿行**。
## 地图用生成器造，走哪条边看图不看常量。
extends RefCounted


## 假的侵蚀：只记谁在什么时候调了它，惩罚按配置给。
class FakeErosion:
	var log: Array
	var damage: int = 0
	var seen_totals: Array[int] = []

	func _init(p_log: Array, p_damage: int = 0) -> void:
		log = p_log
		damage = p_damage

	func on_action(clock: ActionClock, _graph: MapGraph) -> void:
		log.append("erosion")
		seen_totals.append(clock.total)

	func move_penalty(_node: MapNode) -> Dictionary:
		log.append("penalty")
		return {"hp_damage": damage, "item_risk": 0.0}


static func _map(seed: int = 3) -> MapGraph:
	return RingMapGenerator.new().generate(RingMapConfig.sample(5), seed)


static func run_clock(t: TestCase) -> void:
	t.begin("行动计数 · 只加不减，花多少由调用方说")

	var clock := ActionClock.new()
	var log := []
	clock.advanced.connect(func(total: int, delta: int): log.append([total, delta]))
	clock.spend(1)
	clock.spend(3, &"rest")
	t.eq(clock.total, 4, "1 + 3")
	t.eq(log, [[1, 1], [4, 3]], "每花一次一条信号，带累计与这一次")
	clock.spend(0)
	clock.spend(-5)
	t.eq(clock.total, 4, "0 与负数不花")
	t.eq(log.size(), 2, "也不发信号")
	t.eq(String(clock.last_reason()), "rest", "上一次花的原因")
	t.eq(ActionClock.from_dict(clock.to_dict()).total, 4, "存得下读得回")


static func run_navigator_is_read_only(t: TestCase) -> void:
	t.begin("导航器 · 只有单步与只读查询，没有多步移动的入口")

	# 公开方法就这几个。多一个「走过去」「寻路」之类的就红 —— 自动寻路是有意不做的（5.6）
	var allowed := ["available_moves", "edge_for_step", "resolve_step", "distance_map", "nearest_of_type"]
	var found: Array[String] = []
	for m in MapNavigator.new().get_script().get_script_method_list():
		var name := String(m["name"])
		if not name.begins_with("_"):
			found.append(name)
	found.sort()
	allowed.sort()
	t.eq(found, allowed, "MapNavigator 的公开方法就这几个")

	var g := _map()
	var start: int = g.entry_ids[0]
	t.eq(MapNavigator.available_moves(g, start), g.neighbors(start), "能走的就是相邻的")
	var dist := MapNavigator.distance_map(g, start)
	t.eq(int(dist[start]), 0, "自己 0 步")
	for n in g.neighbors(start):
		t.eq(int(dist[n]), 1, "邻居 1 步")
	t.eq(dist.size(), g.node_count(), "全图连通，每个点都到得了")
	var near := MapNavigator.nearest_of_type(g, start, &"core")
	t.eq(int(near["id"]), RingMapGenerator.CORE_ID, "最近的核心就是核心")
	t.eq(int(near["steps"]), int(dist[RingMapGenerator.CORE_ID]), "步数与距离表一致")
	t.eq(int(MapNavigator.nearest_of_type(g, start, &"junction")["id"]), -1, "没有的类型 → -1")

	# 单步意图：花的是那条边的 action_cost，别处不许自己去读它
	var to: int = g.neighbors(start)[0]
	var intent := MapNavigator.resolve_step(g, start, to)
	t.not_null(intent, "相邻的解析得出意图")
	t.eq(intent.action_cost, g.edge_between(start, to).action_cost, "花的就是那条边的 action_cost")
	t.eq(intent.kind, MoveIntent.STEP, "现在只有 step")
	var far := -1
	for id in g.node_ids():
		if int(dist.get(id, 0)) >= 2:
			far = id
			break
	t.is_null(MapNavigator.resolve_step(g, start, far), "不相邻的解析不出来")
	t.is_null(MapNavigator.resolve_step(g, start, start), "原地不动不是移动")


static func run_settlement_order(t: TestCase) -> void:
	t.begin("走一步 · 结算顺序：计数 → 侵蚀推进 → 目的地惩罚 → 节点事件")

	var g := _map()
	var log := []
	var clock := ActionClock.new()
	clock.advanced.connect(func(_total: int, _delta: int): log.append("spend"))
	var erosion := FakeErosion.new(log, 1)
	var travel := MapTravel.new(g, clock)
	travel.erosion = erosion
	travel.vitality = Vitality.new(5)
	travel.on_node_event = func(node: MapNode): log.append("event:%d" % node.id)

	var start: int = g.entry_ids[0]
	t.check(travel.start_at(start), "站到出生点上")
	t.check(g.get_node(start).is_visited(), "出生点开局就算踩过了")
	var to: int = g.neighbors(start)[0]
	t.check(travel.step_to(to), "走得过去")
	t.eq(log, ["spend", "erosion", "penalty", "event:%d" % to],
		"**顺序不可调换**：先计数，再侵蚀推进，再结算目的地惩罚，最后触发事件")
	t.eq(erosion.seen_totals, [1] as Array[int], "侵蚀看到的是花过这一步之后的累计")
	t.eq(travel.vitality.current, 4, "惩罚扣在体力上（假侵蚀说扣 1）")
	t.eq(travel.current_id, to, "人到了")
	t.eq(travel.history, [start, to] as Array[int], "走过的路记着")

	# 没人接事件时本类到点即标 VISITED；接了的话由事件系统说
	t.check(not g.get_node(to).is_visited(), "接了事件钩子，节点什么时候算用过由它说")
	travel.mark_visited(to)
	t.check(g.get_node(to).is_visited(), "事件系统说用过了")


static func run_visited_only_passes(t: TestCase) -> void:
	t.begin("走一步 · 已访问的点只能穿行，不再触发事件")

	var g := _map(7)
	var travel := MapTravel.new(g)
	var start: int = g.entry_ids[0]
	travel.start_at(start)
	var events := []
	var moves := []
	travel.on_node_event = func(node: MapNode):
		events.append(node.id)
		travel.mark_visited(node.id)
	travel.moved.connect(func(_i: MoveIntent, first: bool): moves.append(first))

	var to: int = g.neighbors(start)[0]
	travel.step_to(to)
	travel.step_to(start)      # 折返：边双向
	travel.step_to(to)
	t.eq(events, [to], "同一个点只触发一次事件")
	t.eq(moves, [true, false, false], "头一回踩上是 first_visit，之后只是穿行")
	t.eq(travel.clock.total, 3, "穿行照样花行动点")
	t.eq(travel.current_id, to, "人在那儿")

	# 没接事件钩子：到点即标 VISITED（占位）
	var plain := MapTravel.new(g)
	plain.start_at(start)
	var other: int = g.neighbors(start)[-1]
	plain.step_to(other)
	t.check(g.get_node(other).is_visited() or other == to, "没人接事件，到点就算用过")


static func run_refusals(t: TestCase) -> void:
	t.begin("走一步 · 走不了的说得出为什么")

	var g := _map()
	var travel := MapTravel.new(g)
	var start: int = g.entry_ids[0]
	travel.start_at(start)
	var whys := []
	travel.refused.connect(func(_i: MoveIntent, why: String): whys.append(why))

	var dist := MapNavigator.distance_map(g, start)
	var far := -1
	for id in g.node_ids():
		if int(dist.get(id, 0)) >= 2:
			far = id
			break
	t.check(not travel.step_to(far), "不相邻走不了")
	t.check(not travel.step_to(start), "原地不是移动")
	t.check(not travel.step_to(99999), "不存在的点走不了")

	# 过期的意图：以为人在别处
	var to: int = g.neighbors(start)[0]
	var stale := MoveIntent.step(to, g.neighbors(to)[0], 1)
	t.check(not travel.apply(stale), "意图的起点不是人所在的点 → 拒绝")
	# 还不认识的移动方式：留给定点移动等的缝（传送在 8-1 已实现）
	var tele := MoveIntent.step(start, to, 1)
	tele.kind = &"warp"
	t.check(not travel.apply(tele), "认不得的移动方式 → 拒绝，不是当 step 走（teleport 已在 8-1 实现，这里用 warp 当例子）")
	t.eq(whys.size(), 5, "每次拒绝一条原因")
	t.eq(travel.clock.total, 0, "拒绝的一步不花行动点")
	t.eq(travel.current_id, start, "人没动")
	for why in whys:
		t.check(why != "", "原因不是空的")


static func run_walk_random(t: TestCase) -> void:
	t.begin("走一步 · 随便走一批，计数等于走过的边的 action_cost 之和")

	for s in 6:
		var g := _map(s)
		var travel := MapTravel.new(g)
		travel.start_at(g.entry_ids[0])
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var expected := 0
		var visited_before := {}
		for _k in 40:
			var moves := travel.available_moves()
			t.check(not moves.is_empty(), "永远有地方可走（边双向，死路能折返）")
			var to: int = moves[rng.randi_range(0, moves.size() - 1)]
			var from := travel.current_id
			expected += g.edge_between(from, to).action_cost if g.edge_between(from, to) != null \
				else g.edge_between(to, from).action_cost
			visited_before[to] = true
			t.check(travel.step_to(to), "相邻的一定走得过去")
		t.eq(travel.clock.total, expected, "种子 %d：计数 = 走过的边的 action_cost 之和" % s)
		t.eq(travel.history.size(), 41, "种子 %d：起点 + 40 步" % s)
		for id in visited_before:
			t.check(g.get_node(int(id)).is_visited(), "踩过的点都标了 VISITED（没接事件钩子的占位行为）")

		# 存档读回：人、路、计数一致；图另存
		var back := MapTravel.from_dict(travel.to_dict(), MapGraph.from_dict(g.to_dict()))
		t.eq(back.current_id, travel.current_id, "种子 %d：人在哪读得回" % s)
		t.eq(back.history, travel.history, "种子 %d：走过的路读得回" % s)
		t.eq(back.clock.total, travel.clock.total, "种子 %d：计数读得回" % s)
		t.eq(back.available_moves(), travel.available_moves(), "种子 %d：读回来接着能走" % s)


static func run_intent_roundtrip(t: TestCase) -> void:
	t.begin("移动意图 · 纯数据，存得下读得回")

	var m := MoveIntent.step(3, 7, 2)
	m.passes_through = [4, 5] as Array[int]
	var back := MoveIntent.from_dict(m.to_dict())
	t.eq(back.to_dict(), m.to_dict(), "往返一致")
	t.eq(back.passes_through, [4, 5] as Array[int], "途经点是整数数组")
