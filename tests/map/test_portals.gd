## 传送点（第 8 阶段 8-1，报告 076）：kind 为 portal 的边 = 一次传送意图；生成器按配置连；校验、求解、路口都不把它当路；
## 走它花边上说的行动点、不经过途中；地图与编辑器认得。期望从数据推：配置说连几条就几条。
extends RefCounted


class FakeErosion:
	var log: Array
	func _init(p_log: Array) -> void:
		log = p_log
	func on_action(_clock: ActionClock, _graph: MapGraph) -> void:
		log.append("erosion")
	func move_penalty(_node: MapNode) -> Dictionary:
		log.append("penalty")
		return {"hp_damage": 0, "item_risk": 0.0}


static func _map(seed: int, portals: int, min_steps: int = 4, cost: int = 2) -> MapGraph:
	var cfg := RingMapConfig.sample(5)
	cfg.portal_count = portals
	cfg.portal_min_steps = min_steps
	cfg.portal_cost = cost
	return RingMapGenerator.new().generate(cfg, seed)


static func _portals(g: MapGraph) -> Array:
	var out: Array = []
	for e in g.edges:
		if (e as MapEdge).is_portal():
			out.append(e)
	return out


static func run_intent_and_travel(t: TestCase) -> void:
	t.begin("传送点 · portal 边解析成 teleport 意图；走它花边上的行动点、不经过途中；结算顺序照旧；不是路口的腿、不参与求解")
	var g := _map(3, 0)
	t.not_null(g, "生成一张没有传送点的图")
	if g == null:
		return
	# 手连一条：两个隔得远的点
	var a: int = g.entry_ids[0]
	var dist := MapNavigator.distance_map(g, a)
	var b := -1
	for id in g.node_ids():
		if dist.has(id) and int(dist[id]) >= 4 and not MapNodeTypes.STRUCTURAL.has(g.get_node(id).type):
			b = id
			break
	t.check(b >= 0, "找得到隔 4 步以上的点")
	var before := int(dist[b])
	var e := g.connect_nodes(a, b, MapEdge.PORTAL, 2)
	t.check(e != null and e.is_portal(), "连成了传送点")
	t.check(MapNavigator.available_moves(g, a).has(b), "传送点的另一头是能走到的点")
	var intent := MapNavigator.resolve_step(g, a, b)
	t.not_null(intent, "解析得出意图")
	t.eq(intent.kind, MoveIntent.TELEPORT, "意图是 teleport")
	t.eq(intent.action_cost, 2, "花边上说的 2 点")
	t.check(intent.passes_through.is_empty(), "不经过途中任何点")
	var d2 := MapNavigator.distance_map(g, a)
	t.eq(int(d2[b]), 1, "有了传送点距离变成 1（原来 %d）" % before)
	var back := MoveIntent.from_dict(intent.to_dict())
	t.eq([back.kind, back.from_id, back.to_id, back.action_cost], [MoveIntent.TELEPORT, a, b, 2], "意图存档往返")

	var log := []
	var clock := ActionClock.new()
	clock.advanced.connect(func(_total: int, delta: int): log.append("spend:%d" % delta))
	var travel := MapTravel.new(g, clock)
	travel.erosion = FakeErosion.new(log)
	travel.on_node_event = func(node: MapNode): log.append("event:%d" % node.id)
	t.check(travel.start_at(a), "站到出生点")
	t.check(travel.step_to(b), "传送过去")
	t.eq(log, ["spend:2", "erosion", "penalty", "event:%d" % b], "顺序不变：计数（花 2）→ 侵蚀 → 惩罚（只结算目的地）→ 事件")
	t.eq(travel.current_id, b, "人到了")
	t.eq(clock.total, 2, "行动点 = 传送的代价，不假定是 1")

	# 求解与路口不认它
	var layout := MapLayout.for_graph(g)
	var with := layout.positions(g, Rect2(Vector2.ZERO, layout.canvas_size(g)))
	var clean := RingMapGenerator.without_portals(g)
	t.eq(_portals(clean).size(), 0, "剔掉传送点的副本没有 portal 边")
	t.eq(clean.node_count(), g.node_count(), "点一个不少")
	var layout2 := MapLayout.for_graph(clean)
	var without := layout2.positions(clean, Rect2(Vector2.ZERO, layout2.canvas_size(clean)))
	var same := true
	for id in with:
		if not without.has(id) or (Vector2(with[id]) - Vector2(without[id])).length() > 0.5:
			same = false
	t.check(same, "有没有传送点，布局的坐标一样（求解器不认它）")
	var j := MapJunctions.find(g)
	var j2 := MapJunctions.find(clean)
	t.eq((j["edge_keys"] as Dictionary).size(), (j2["edge_keys"] as Dictionary).size(), "路口识别不认它")
	# 存档往返保住 kind
	var again := MapGraph.from_dict(g.to_dict())
	t.eq(_portals(again).size(), 1, "图存档往返之后传送点还在")
	t.check((_portals(again)[0] as MapEdge).action_cost == 2, "代价也在")


static func run_generation(t: TestCase) -> void:
	t.begin("传送点 · 生成器按配置连几条：两端隔得够远、不是结构点、每个点至多一条；校验剔掉它照过；0 条 = 和以前一样")
	var made := 0
	var checked := 0
	for seed in range(1, 12):
		var g := _map(seed, 2, 4, 1)
		if g == null:
			continue
		checked += 1
		var ps := _portals(g)
		t.check(ps.size() <= 2, "种子 %d：至多 2 条（%d）" % [seed, ps.size()])
		made += ps.size()
		var clean := RingMapGenerator.without_portals(g)
		var endpoints := {}
		for e in ps:
			var pe := e as MapEdge
			t.check(not endpoints.has(pe.from_id) and not endpoints.has(pe.to_id), "种子 %d：每个点至多一条传送点" % seed)
			endpoints[pe.from_id] = true
			endpoints[pe.to_id] = true
			t.check(not MapNodeTypes.STRUCTURAL.has(g.get_node(pe.from_id).type) and not MapNodeTypes.STRUCTURAL.has(g.get_node(pe.to_id).type), "种子 %d：两端都是普通点" % seed)
			var d := MapNavigator.distance_map(clean, pe.from_id)
			t.check(d.has(pe.to_id) and int(d[pe.to_id]) >= 4, "种子 %d：不走传送点两端隔 %s 步（≥ 4）" % [seed, str(d.get(pe.to_id, "∞"))])
			t.eq(pe.action_cost, 1, "代价按配置")
		var v := MapValidation.new()
		RingMapGenerator.new().validate(g, v)
		t.check(v.ok(), "种子 %d：带传送点的图照样通过生成规则校验：%s" % [seed, v.to_text()])
	t.check(checked > 0 and made > 0, "%d 张图里连了 %d 条" % [checked, made])
	var g0 := _map(3, 0)
	t.eq(_portals(g0).size(), 0, "配置 0 条 = 没有")
	var g_again := _map(3, 0)
	t.eq(g0.to_dict(), g_again.to_dict(), "同种子同图（传送点不影响别的随机）")
