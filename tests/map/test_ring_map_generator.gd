## 同心环生成器的拓扑与骨架（架构文档 5.4，M3-3）。
##
## [b]测的是不变式，不是具体形状。[/b] 一张图长什么样是随机的，
## 写死「第三环有 12 个节点」既脆弱又没意义 —— 改一个参数就红，红得毫无信息量。
##
## 类型相关的（配额、覆盖、路线风险收益）属于 M3-3c，这里一条都不测：
## 这一步的节点类型全是 `battle`。
extends RefCounted

## 跑多少个种子。每个都要过下面全部不变式。
const SEEDS := 64


static func _gen() -> RingMapGenerator:
	return RingMapGenerator.new()


static func _ring_of(g: MapGraph, id: int) -> int:
	return int(g.get_node(id).layout.get("ring", -1))


static func _slot_taken(g: MapGraph, r: int, slot: int) -> bool:
	for id in g.node_ids():
		var lay := g.get_node(id).layout
		if int(lay.get("ring", -1)) == r and int(lay.get("order", -1)) == slot:
			return true
	return false


## 按环分组：ring -> Array[node_id]
static func _by_ring(g: MapGraph) -> Dictionary:
	var out := {}
	for id in g.node_ids():
		var r := _ring_of(g, id)
		if not out.has(r):
			out[r] = []
		(out[r] as Array).append(id)
	return out


#region 主体：跑一批种子
static func run(t: TestCase) -> void:
	t.begin("环形生成器 · 一批种子下的不变式")

	var cfg := RingMapConfig.sample(5)
	var made := 0
	var bad: Array[String] = []

	for s in SEEDS:
		var gen := _gen()
		var g := gen.generate(cfg, s)
		if g == null:
			bad.append("种子 %d 没生成出来" % s)
			continue
		made += 1
		var why := _check_all(g, cfg)
		if why != "":
			bad.append("种子 %d：%s" % [s, why])

	t.eq(made, SEEDS, "%d 个种子全都生成得出来" % SEEDS)
	t.check(bad.is_empty(), "全部不变式成立。不成立的：\n    %s"
		% "\n    ".join(bad.slice(0, mini(6, bad.size()))))


## 返回第一条不成立的不变式；全过则返回空串。
static func _check_all(g: MapGraph, cfg: RingMapConfig) -> String:
	var by_ring := _by_ring(g)

	# --- 核心 ---
	var core := g.get_node(RingMapGenerator.CORE_ID)
	if core == null or core.type != &"core":
		return "核心不在，或者类型不对"
	if not g.goal_ids.has(RingMapGenerator.CORE_ID):
		return "核心不是终点"

	# --- 槽位数随环单调不增（环越靠里越短）---
	# 看槽位不看节点数：外环挖了空白之后节点可以比内环少，那是合法的
	var slot_table: Dictionary = g.layout_meta.get("ring_slots", {})
	var prev := -1
	for r in range(cfg.ring_count(), 0, -1):
		var nodes := (by_ring.get(r, []) as Array).size()
		if nodes <= 0:
			return "第 %d 环一个节点都没有" % r
		var slots := int(slot_table.get(r, -1))
		if slots < 0:
			return "第 %d 环没记下槽位数" % r
		if nodes > slots:
			return "第 %d 环 %d 个点却只有 %d 个槽位" % [r, nodes, slots]
		if prev >= 0 and slots > prev:
			return "第 %d 环 %d 个槽位，比外面那环的 %d 还多" % [r, slots, prev]
		prev = slots

	# --- tier / erosion_band 随环单调，且两者分开算 ---
	for id in g.node_ids():
		var node := g.get_node(id)
		var r := _ring_of(g, id)
		if node.tier != cfg.ring_count() - r:
			return "节点 %d 的 tier 与它所在的环对不上" % id
		if node.erosion_band != node.tier:
			return "节点 %d 的 erosion_band 与 tier 对不上" % id

	# --- 出生点：数量、都在最外环、互不相同 ---
	var outer := (by_ring.get(cfg.ring_count(), []) as Array).size()
	if g.entry_ids.size() != mini(cfg.effective_entry_count(), outer):
		return "出生点有 %d 个，该有 %d 个" % [g.entry_ids.size(), cfg.effective_entry_count()]
	var seen_entry := {}
	for id in g.entry_ids:
		if _ring_of(g, id) != cfg.ring_count():
			return "出生点 %d 不在最外环" % id
		if seen_entry.has(id):
			return "出生点 %d 重复了" % id
		seen_entry[id] = true

	# --- 出生点两两之间隔得够远 ---
	var outer_slots := int(slot_table.get(cfg.ring_count(), 0))
	for i in g.entry_ids.size():
		for j in range(i + 1, g.entry_ids.size()):
			var sa := int(g.get_node(g.entry_ids[i]).layout["order"])
			var sb := int(g.get_node(g.entry_ids[j]).layout["order"])
			var dist := mini(posmod(sa - sb, outer_slots), posmod(sb - sa, outer_slots))
			if dist < cfg.entry_min_gap:
				return "出生点 %d 与 %d 只隔 %d 个槽位" % [g.entry_ids[i], g.entry_ids[j], dist]

	# --- 高危区的片数落在规模模板给的范围里；每条路线身上岔出的不超过上限 ---
	var zone_range := cfg.zone_count_range()
	if g.zones.size() < zone_range.x or g.zones.size() > zone_range.y:
		return "高危区 %d 片，规模允许 %d～%d" % [g.zones.size(), zone_range.x, zone_range.y]

	# --- 路线：条数、简单路径、走得通、尽头对 ---
	if g.routes.size() != g.entry_ids.size():
		return "路线数与出生点数对不上"
	for route in g.routes:
		var ids: Array = route["node_ids"]
		var seen := {}
		for i in ids.size():
			var id := int(ids[i])
			if seen.has(id):
				return "路线 %s 上节点 %d 出现两次" % [route["style"], id]
			seen[id] = true
			if i > 0 and g.edge_between(int(ids[i - 1]), id) == null:
				return "路线 %s 在 %d→%d 处断了" % [route["style"], ids[i - 1], id]
		if int(ids[0]) != int(route["entry_id"]):
			return "路线 %s 的起点不是它的出生点" % route["style"]
		if String(route["ends_at"]) == "core":
			if int(ids[-1]) != RingMapGenerator.CORE_ID:
				return "路线 %s 说去核心，末端却不是" % route["style"]
		else:
			# 去撤离点的路线停在撤离环间（偶数环取内侧那环）；没有环间的规模停在核心前一环（报告 053）
			var band := cfg.extract_band()
			var stop := 1 if band.is_empty() else int(band.min())
			if _ring_of(g, int(ids[-1])) != stop:
				return "路线 %s 该停在第 %d 环，停在了第 %d 环" % [route["style"], stop, _ring_of(g, int(ids[-1]))]
			# 尽头之后的换乘区：同一环上、一路相连，接到别的路线上 —— 撤离点因此两条路线共用
			var tail: Array = route.get("exit_ids", [])
			var last := int(ids[-1])
			for id in tail:
				if _ring_of(g, int(id)) != stop or g.edge_between(last, int(id)) == null:
					return "路线 %s 尽头之后的换乘区在 %d→%d 处断了或不在同一环" % [route["style"], last, id]
				last = int(id)
			if not (route.get("zone_ids", []) as Array).is_empty():
				return "路线 %s 是搜索路线，却岔出了高危区" % route["style"]
		# 每一步要么向内一环，要么沿当前这环横着挪（正对着空白区时）—— 不向外、不跳环
		for i in range(1, ids.size()):
			var a := _ring_of(g, int(ids[i - 1]))
			var b := _ring_of(g, int(ids[i]))
			if b != a - 1 and b != a:
				return "路线 %s 从第 %d 环跳到了第 %d 环" % [route["style"], a, b]

	# --- 路不交叉（四个点两两相连的那种是四岔路口，不算）---
	var crossings := RingMapGenerator.bad_crossings(g)
	if not crossings.is_empty():
		var x: MapEdge = crossings[0][0]
		var y: MapEdge = crossings[0][1]
		return "%d↔%d 与 %d↔%d 交叉了" % [x.from_id, x.to_id, y.from_id, y.to_id]

	# --- 单条路径的长度上限：每一条边都守 ---
	for e in g.edges:
		if not RingMapGenerator.edge_within_limit(
				g, e.from_id, e.to_id, cfg.edge_max_ring_offset, cfg.edge_max_slot_offset):
			return "边 %d↔%d 超长：槽位偏移 %.2f" % [
				e.from_id, e.to_id, RingMapGenerator.slot_offset(g, e.from_id, e.to_id)]

	# --- 高危区：规模、相连、出入口数目随规模封顶（规则从配置读）---
	var rules := cfg.zone_rules
	var on_route := {}
	for route in g.routes:
		for id in (route["node_ids"] as Array):
			on_route[int(id)] = true
	for zone_id in g.zones:
		var info: Dictionary = g.zones[zone_id]
		var ids: Array = info["node_ids"]
		var absorbed := 0
		for id in ids:
			if on_route.has(int(id)):
				absorbed += 1
			if g.get_node(int(id)).danger != 2 or g.get_node(int(id)).zone != int(zone_id):
				return "高危区 %s 里的节点 %d 没标上 zone / danger" % [zone_id, id]
		if ids.size() < rules.min_size or ids.size() > rules.max_size:
			return "高危区 %s 有 %d 个点" % [zone_id, ids.size()]
		if not MapNavigator.connected_within(g, ids):
			return "高危区 %s 内部不相连" % zone_id
		# 路线节点只会在「只长到两个点」时被划进来凑数，所以含路线节点的区一定是最小规模
		if absorbed > 1 or (absorbed == 1 and ids.size() != rules.min_size):
			return "高危区 %s（%d 个点）里有 %d 个路线节点" % [zone_id, ids.size(), absorbed]
		# 出入口数的是【区内连着区外的点】，不是边
		var gates := ZoneRules.gate_ids(g, ids).size()
		if gates < 1 or gates > rules.max_gates_for(ids.size()):
			return "高危区 %s（%d 个点）有 %d 个出入口节点，上限 %d" % [
				zone_id, ids.size(), gates, rules.max_gates_for(ids.size())]
		if info["gate_ids"] != ZoneRules.gate_ids(g, ids):
			return "高危区 %s 记下的 gate_ids 与图上的对不上" % zone_id

	# --- 边：不跨空白区 ---
	for e in g.edges:
		if e.kind != &"tangential":
			continue
		var ra := _ring_of(g, e.from_id)
		var rb := _ring_of(g, e.to_id)
		if ra != rb:
			return "一条切向边连着两个不同的环"
		var slots := cfg.slots_for_ring(ra)
		var sa := int(g.get_node(e.from_id).layout["order"])
		var sb := int(g.get_node(e.to_id).layout["order"])
		var dist := mini(posmod(sa - sb, slots), posmod(sb - sa, slots))
		if dist > cfg.tangential_span_max + 1:
			return "切向边跨过了空白区：第 %d 环 %d↔%d 隔 %d 格" % [ra, sa, sb, dist]
		# 挨着的两个点之间不该还有别的点
		var dir := 1 if posmod(sb - sa, slots) == dist else -1
		for k in range(1, dist):
			if _slot_taken(g, ra, posmod(sa + dir * k, slots)):
				return "切向边跨过了别的点：第 %d 环 %d↔%d" % [ra, sa, sb]

	return ""
#endregion


#region 单项细看
static func run_small_maps(t: TestCase) -> void:
	t.begin("环形生成器 · 各种环数都过不变式")

	for rings in [2, 3, 4, 6]:
		var cfg := RingMapConfig.sample(rings)
		var bad: Array[String] = []
		for s in 16:
			var g := _gen().generate(cfg, s)
			var why := "没生成出来" if g == null else _check_all(g, cfg)
			if why != "":
				bad.append("种子 %d：%s" % [s, why])
		t.check(bad.is_empty(), "%d 环：%s" % [rings, "全过" if bad.is_empty() else bad[0]])


static func run_scale_profiles(t: TestCase) -> void:
	t.begin("环形生成器 · 规模模板：出发点、高危区数量与规模都有上限")

	var profiles := MapScaleProfile.defaults()
	t.check(not profiles.is_empty(), "有开箱的规模模板")

	# 没有规模覆盖到的环数（小测试图）：不要高危区，也不会因此重试
	var smallest := 999
	for p in profiles:
		smallest = mini(smallest, p.rings.x)
	var below := RingMapConfig.sample(smallest - 1)
	t.is_null(below.scale(), "%d 环不属于任何规模" % (smallest - 1))
	for s in 8:
		var gen := _gen()
		var g := gen.generate(below, s)
		t.not_null(g, "没有规模的小图也生成得出来（种子 %d）" % s)
		if g != null:
			t.eq(g.zones.size(), 0, "没有规模 → 没有高危区")
			t.check(not gen.failure_tally.has(&"zone_missing"), "也不会因为「缺高危区」而重试")

	# 每一档规模的两端环数：片数、规模、出发点数都落在这一档的范围里；节点数随环数增长
	for p in profiles:
		var nodes_at := {}
		for rings in [p.rings.x, p.rings.y]:
			var cfg := RingMapConfig.sample(rings)
			t.eq(cfg.scale().id, p.id, "%d 环属于 %s" % [rings, p.id])
			for s in 6:
				var g := _gen().generate(cfg, s)
				t.not_null(g, "%s · %d 环生成得出来（种子 %d）" % [p.id, rings, s])
				if g == null:
					continue
				t.check(g.zones.size() >= p.zones.x and g.zones.size() <= p.zones.y,
					"%s：高危区 %d 片，该在 %d～%d" % [p.id, g.zones.size(), p.zones.x, p.zones.y])
				t.check(g.entry_ids.size() >= p.entries.x and g.entry_ids.size() <= p.entries.y,
					"%s：出发点 %d 个，该在 %d～%d" % [p.id, g.entry_ids.size(), p.entries.x, p.entries.y])
				for zone_id in g.zones:
					var size: int = (g.zones[zone_id]["node_ids"] as Array).size()
					t.check(size <= maxi(p.zone_size.y, cfg.zone_rules.min_size),
						"%s：高危区 %d 个点，软上限 %d" % [p.id, size, p.zone_size.y])
				var lim := p.node_range(rings)
				if lim.y > 0:
					t.check(g.node_count() >= lim.x and g.node_count() <= lim.y,
						"%s · %d 环：%d 个点，该在 %d～%d" % [p.id, rings, g.node_count(), lim.x, lim.y])
					nodes_at[rings] = int(nodes_at.get(rings, 0)) + g.node_count()
				t.check(_zones_per_route_max(g) <= p.zones_per_route,
					"%s：每条路线身上岔出的不超过 %d 片" % [p.id, p.zones_per_route])

		if p.node_range(p.rings.y).y > 0 and p.rings.y > p.rings.x:
			t.check(int(nodes_at.get(p.rings.y, 0)) >= int(nodes_at.get(p.rings.x, 0)),
				"%s：%d 环的点数 ≥ %d 环的 —— 节点数仍随环数增长" % [p.id, p.rings.y, p.rings.x])

	# 可选项给了数就用那个数 —— 但会被夹进规模的范围
	var medium: MapScaleProfile = profiles[mini(1, profiles.size() - 1)]
	var picky := RingMapConfig.sample(medium.rings.y)
	picky.zone_count = medium.zones.y
	picky.zone_soft_cap = medium.zone_size.x
	picky.entry_count = medium.entries.y + 5
	t.eq(picky.effective_entry_count(), medium.entries.y, "出发点要得太多 → 夹到上限")
	t.eq(picky.effective_zone_soft_cap(), medium.zone_size.x, "高危区规模按指定的来")
	var want_many := _gen().generate(picky, 5)
	t.not_null(want_many, "要满额的高危区也生成得出来")
	if want_many != null:
		t.check(want_many.zones.size() >= medium.zones.x, "至少有必须的那几片")
		t.eq(want_many.zones.size() + int(want_many.layout_meta.get("zones_skipped", 0)), medium.zones.y,
			"长成的 + 记下跳过的 = 想要的 —— 没长成的不是不声不响")

	# 必须有的那一片岔不出来：要求路线走过 200% 才岔
	var never := RingMapConfig.sample(profiles[0].rings.y)
	never.zone_spec.start_after_progress = 2.0
	t.is_null(_gen().generate(never, 1, 4), "必须有却岔不出来 → 这张图生成失败")
	never.zone_spec = null
	var plain := _gen().generate(never, 1, 4)
	t.not_null(plain, "不配 zone_spec → 这张图不要高危区，照样生成")
	if plain != null:
		t.eq(plain.zones.size(), 0, "一片都没有")


## 一条路线身上最多岔出了几片。生成器把它记在路线标注里。
static func _zones_per_route_max(g: MapGraph) -> int:
	var worst := 0
	for route in g.routes:
		worst = maxi(worst, (route.get("zone_ids", []) as Array).size())
	return worst


static func run_zone_shape_rules(t: TestCase) -> void:
	t.begin("高危区 · 长成什么样才算数（ZoneRules）")

	var rules := ZoneRules.new()
	var prev := 0
	for size in range(rules.min_size, rules.max_size + 1):
		var cap := rules.max_gates_for(size)
		t.check(cap >= 1 and cap >= prev, "%d 个点至多 %d 个出入口 —— 随规模只增不减" % [size, cap])
		prev = cap
	# 表上每一档的边界：键那么大用它的值，再大一个就不比它小
	for k in rules.max_gates_by_size:
		t.eq(rules.max_gates_for(int(k)), int(rules.max_gates_by_size[k]), "点数 = %s 用这一档" % k)

	# 规则跟着图走，而且过得了 JSON（键会变成字符串）
	var gen := _gen()
	var g := gen.generate(RingMapConfig.sample(5), 6)
	t.not_null(g, "先有一张图")
	if g == null:
		return
	var back := MapGraph.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	var read := ZoneRules.from_graph(back)
	t.eq(read.min_size, rules.min_size, "min_size 读得回")
	for size in range(rules.min_size, rules.max_size + 1):
		t.eq(read.max_gates_for(size), rules.max_gates_for(size), "%d 个点的出入口上限读得回" % size)

	# 出入口数的是【区内连着区外的点】：给已有的那个口再多接几条通向区外的路，口还是那么多个
	var zone_id: int = g.zones.keys()[0]
	var ids: Array = g.zones[zone_id]["node_ids"]
	var cap := rules.max_gates_for(ids.size())
	var inside := {}
	for id in ids:
		inside[int(id)] = true
	var outsiders: Array[int] = []
	for id in g.node_ids():
		if not inside.has(id) and id != RingMapGenerator.CORE_ID:
			outsiders.append(id)
	var gate0: int = ZoneRules.gate_ids(g, ids)[0]
	var before := ZoneRules.gate_ids(g, ids).size()
	var added := 0
	for out in outsiders:
		if added >= 3:
			break
		if g.edge_between(gate0, out) == null and g.get_node(out).zone == 0:
			g.connect_nodes(gate0, out, &"radial")
			added += 1
	t.check(added > 0 and ZoneRules.gate_ids(g, ids).size() == before, "同一个点上多开几条路，出入口数不变")
	var v := MapValidation.new()
	ZoneRules.validate(g, v)
	t.check(not v.rules().has(&"zone_gate"), "所以也不算超标")
	# 换成让【不同的】区内点各自通向区外，口就多了 → zone_gate
	var k := 0
	for member in ids:
		if ZoneRules.gate_ids(g, ids).size() > cap:
			break
		while k < outsiders.size() and (g.edge_between(int(member), outsiders[k]) != null or g.get_node(outsiders[k]).zone != 0):
			k += 1
		if k < outsiders.size():
			g.connect_nodes(int(member), outsiders[k], &"radial")
	v = MapValidation.new()
	ZoneRules.validate(g, v)
	t.check(ZoneRules.gate_ids(g, ids).size() > cap and v.rules().has(&"zone_gate"),
		"不同的点各开一个口，超过上限 → zone_gate（%d 个口，上限 %d）" % [ZoneRules.gate_ids(g, ids).size(), cap])

	# 删到只剩两个点 → zone_size
	var small := MapGraph.from_dict(back.to_dict())
	var keep: Array = (small.zones[zone_id]["node_ids"] as Array).slice(0, rules.min_size - 1)
	for id in (small.zones[zone_id]["node_ids"] as Array).duplicate():
		if not keep.has(id):
			small.get_node(int(id)).zone = 0
	small.zones[zone_id]["node_ids"] = keep
	v = MapValidation.new()
	gen.validate(small, v)
	t.check(v.rules().has(&"zone_size"), "不到 %d 个点 → zone_size" % rules.min_size)


static func run_zone_gates_spread(t: TestCase) -> void:
	t.begin("高危区 · 出入口是点不是边；多个口尽量分开")

	# 每片区：gate_ids 里的每个点都真的连着区外；口数在 1～上限之间；
	# 有两个以上口的区，口与口之间至少隔一步（挤在一起等于一个口）
	var cfg := RingMapConfig.sample(7)
	var multi := 0
	var adjacent_gates := 0
	var bad := 0
	for s in 48:
		var g := _gen().generate(cfg, s)
		if g == null:
			continue
		var rules := ZoneRules.from_graph(g)
		for zone_id in g.zones:
			var ids: Array = g.zones[zone_id]["node_ids"]
			var gates: Array = g.zones[zone_id]["gate_ids"]
			if gates.size() < 1 or gates.size() > rules.max_gates_for(ids.size()):
				bad += 1
			for gate in gates:
				var touches_outside := false
				for n in g.neighbors(int(gate)):
					if not ids.has(n):
						touches_outside = true
				if not touches_outside:
					bad += 1
			if gates.size() >= 2:
				multi += 1
				for i in gates.size():
					for j in range(i + 1, gates.size()):
						if g.edge_between(int(gates[i]), int(gates[j])) != null:
							adjacent_gates += 1
	t.check(multi > 0, "48 个种子里出现过多出入口的高危区（%d 片）" % multi)
	t.eq(bad, 0, "每个口都真的通向区外，口数在 1～上限之间")
	t.check(adjacent_gates <= multi / 2, "多个口挤在一起的少（%d / %d）" % [adjacent_gates, multi])


static func run_entries(t: TestCase) -> void:
	t.begin("环形生成器 · 出生点间隔")

	var cfg := RingMapConfig.sample(5)
	var slots := cfg.slots_for_ring(cfg.ring_count())
	# 能放下的最大间隔：槽位数 / 出生点数（先把最外环填满，免得碰运气）。
	# 填满之后点数超出规模模板的范围，所以把模板拿掉
	cfg.scales = [] as Array[MapScaleProfile]
	cfg.rings[0].node_count = 0
	cfg.entry_min_gap = slots / cfg.entry_count
	var g := _gen().generate(cfg, 11)
	t.not_null(g, "间隔拉到理论上限也放得下")
	if g != null:
		t.eq(_check_all(g, cfg), "", "而且不变式照样成立")

	cfg.entry_min_gap = slots / cfg.entry_count + 1
	var gen := _gen()
	t.is_null(gen.generate(cfg, 11, 2), "再多一格就放不下了")
	t.check(gen.build_note.contains("出生点放不下"),
		"而且说得出为什么：%s" % gen.build_note)


static func run_routes_are_not_validity(t: TestCase) -> void:
	t.begin("环形生成器 · 路线是生成规则，不是合格条件")

	var gen := _gen()
	var g := gen.generate(RingMapConfig.sample(5), 4)
	t.not_null(g, "先有一张图")
	if g == null:
		return
	t.check(not g.routes.is_empty(), "生成器留下了路线标注（开局挑出生点时给玩家看的）")

	# 把标注清掉、改乱，图照样合格
	g.routes = [] as Array[Dictionary]
	var v := MapValidation.new()
	gen.validate(g, v)
	t.check(v.ok(), "没有路线标注，照样合格：%s" % v.to_text())

	g.routes = [{"entry_id": g.entry_ids[0], "style": "whatever", "ends_at": "core",
		"node_ids": [g.entry_ids[0], RingMapGenerator.CORE_ID]}] as Array[Dictionary]
	v = MapValidation.new()
	gen.validate(g, v)
	t.check(v.ok(), "标注与图对不上，也照样合格：%s" % v.to_text())


static func run_edge_limit(t: TestCase) -> void:
	t.begin("环形生成器 · 单条路径的长度上限")

	var cfg := RingMapConfig.sample(5)
	var gen := _gen()
	var g := gen.generate(cfg, 8)
	t.not_null(g, "先有一张图")
	if g == null:
		return
	t.eq(int(g.layout_meta["edge_max_slot_offset"]), cfg.edge_max_slot_offset,
		"上限跟着图走 —— 校验与编辑器从图上读，不必手上有配置")

	# 手动拉一条横穿半张图的边：校验说它太长
	var outer := cfg.ring_count()
	var slots := cfg.slots_for_ring(outer)
	var a := -1
	var b := -1
	for id in g.node_ids():
		if _ring_of(g, id) != outer:
			continue
		if a < 0:
			a = id
		elif RingMapGenerator.slot_offset(g, a, id) >= float(slots) / 3.0:
			b = id
			break
	t.check(a >= 0 and b >= 0, "最外环上找得到两个隔得远的点")
	g.connect_nodes(a, b, &"tangential")
	var v := MapValidation.new()
	gen.validate(g, v)
	t.check(v.rules().has(&"edge_length"), "拉一条超长的边 → edge_length")

	# 断边概率拉满也散不了架：断之前先看会不会断出孤岛
	# （用没有高危区的小图，免得「高危区没长起来」的重试混进来）
	var brittle := RingMapConfig.sample(4)
	brittle.zone_spec = null
	brittle.tangential_break_chance = 1.0
	for s in 16:
		var gg := _gen()
		var made := gg.generate(brittle, s)
		t.check(made != null and not gg.failure_tally.has(&"reachable") and not gg.failure_tally.has(&"isolated"), "切向边能断的全断也不会断出孤岛（种子 %d）—— 重试只许因为别的原因" % s)


static func run_crossing_rules(t: TestCase) -> void:
	t.begin("环形生成器 · 交叉的路：只有四岔路口说得清")

	# 手搭一张两环的小图：外环 p、q 相邻，内环 u、t 相邻
	var g := MapGraph.new()
	g.layout_kind = &"ring"
	g.layout_meta = {"ring_count": 2, "ring_slots": {2: 8, 1: 8}}
	var spots := {1: [2, 0], 2: [2, 1], 3: [1, 0], 4: [1, 1], 9: [0, 0]}     # id -> [ring, order]
	for id in spots:
		var n := MapNode.new()
		n.id = id
		n.type = &"core" if id == 9 else &"battle"
		n.layout = {"ring": spots[id][0], "order": spots[id][1]}
		g.add_node(n)
	var p_id := 1
	var q_id := 2
	var u_id := 3
	var t_id := 4
	g.connect_nodes(p_id, t_id, &"radial")      # 一条对角线
	t.check(RingMapGenerator.bad_crossings(g).is_empty(), "一条斜路自己不算交叉")
	g.connect_nodes(q_id, u_id, &"radial")      # 另一条对角线 → 打叉
	t.eq(RingMapGenerator.bad_crossings(g).size(), 1, "两条对角线 → 一处交叉")
	t.check(RingMapGenerator.edges_cross(g, p_id, t_id, q_id, u_id), "edges_cross 认得出来")
	t.check(not RingMapGenerator.edges_cross(g, p_id, t_id, p_id, u_id), "共用一个端点的不算")

	# 把四个点连满 → 它成了四岔路口，不再算交叉
	for pair in [[p_id, q_id], [u_id, t_id], [p_id, u_id], [q_id, t_id]]:
		g.connect_nodes(pair[0], pair[1])
	t.check(RingMapGenerator.bad_crossings(g).is_empty(), "四个点两两相连 → 四岔路口，不算交叉")
	var found := MapJunctions.find(g)
	t.eq((found["quads"] as Array).size(), 1, "MapJunctions 把它认成一个四岔")
	t.eq((found["tris"] as Array).size(), 0, "四岔占过的边，三岔不再用（先四后三）")
	t.eq((found["edge_keys"] as Dictionary).size(), 6, "六条边都归这个路口")

	# 少一条就又是交叉了
	g.remove_edge(g.edge_between(p_id, q_id))
	t.eq(RingMapGenerator.bad_crossings(g).size(), 1, "拆掉一条边 → 又成了说不清的交叉")
	g.entry_ids = [p_id] as Array[int]
	g.goal_ids = [9] as Array[int]
	g.connect_nodes(u_id, 9)
	var v := MapValidation.new()
	RingMapGenerator.new().validate(g, v)
	t.check(v.rules().has(&"edge_crossing"), "校验报 edge_crossing")

	# 环上正对面的两条路不是交叉（只比先后会在这里误判）
	var far := MapGraph.new()
	far.layout_meta = {"ring_count": 2, "ring_slots": {2: 6, 1: 6}}
	var far_spots := {1: [2, 1], 2: [1, 2], 3: [2, 5], 4: [1, 5]}
	for id in far_spots:
		var n := MapNode.new()
		n.id = id
		n.layout = {"ring": far_spots[id][0], "order": far_spots[id][1]}
		far.add_node(n)
	t.check(not RingMapGenerator.edges_cross(far, 1, 2, 3, 4), "隔着半个环的两条路不交叉")


static func run_junctions(t: TestCase) -> void:
	t.begin("岔路口 · 三点互连是三岔，由内向外")

	var g := MapGraph.new()
	for id in [1, 2, 3, 4, 5]:
		var n := MapNode.new()
		n.id = id
		n.tier = id        # id 越大越靠里
		g.add_node(n)
	# 两个三角形共用 2–3 这条边：1-2-3 与 2-3-4；5 只挂在 4 上
	for pair in [[1, 2], [2, 3], [1, 3], [2, 4], [3, 4], [4, 5]]:
		g.connect_nodes(pair[0], pair[1])
	var found := MapJunctions.find(g)
	t.eq(found["quads"], [], "没有四岔")
	t.eq(found["tris"], [[2, 3, 4]], "共用一条边的两个三角形只能成一个路口 —— 靠里的那个先得")
	t.check(not (found["edge_keys"] as Dictionary).has(MapJunctions.edge_key(4, 5)), "不在路口里的边照常单独画")

	# 生成出来的图上：路口之间不共用边
	var map := _gen().generate(RingMapConfig.sample(6), 3)
	if map != null:
		var seen := {}
		var shared := 0
		var all := MapJunctions.find(map)
		for clique in (all["quads"] as Array) + (all["tris"] as Array):
			for i in clique.size():
				for j in range(i + 1, clique.size()):
					var key := MapJunctions.edge_key(clique[i], clique[j])
					if seen.has(key):
						shared += 1
					seen[key] = true
		t.eq(shared, 0, "一条边只归一个路口")


static func run_pivot_budget(t: TestCase) -> void:
	t.begin("环形生成器 · 换乘次数随规模走，相邻就直接连")

	for profile in MapScaleProfile.defaults():
		var cfg := RingMapConfig.sample(profile.rings.y)
		var pairs := 0
		var made := 0
		for s in 8:
			var g := _gen().generate(cfg, s)
			if g == null:
				continue
			var route_pairs := 1 if g.routes.size() == 2 else (g.routes.size() if g.routes.size() > 2 else 0)
			var links: Array = g.layout_meta.get("pivot_links", [])
			pairs += route_pairs
			made += links.size()
			t.check(links.size() <= route_pairs * profile.pivots.y,
				"%s：相邻直连的换乘 %d 处，不超过 %d 对 × %d 次"
				% [profile.id, links.size(), route_pairs, profile.pivots.y])
			for link in links:
				t.not_null(g.edge_between(int(link[0]), int(link[1])), "%s：换乘那条路真的在" % profile.id)
		t.check(pairs > 0, "%s：有相邻的路线对" % profile.id)


static func run_ring_numbers_are_explicit(t: TestCase) -> void:
	t.begin("环形配置 · 环的槽位数与节点数写明白，不留 0")

	var cfg := RingMapConfig.sample(5)
	var g := _gen().generate(cfg, 2)
	t.not_null(g, "先有一张图")
	if g == null:
		return
	var by_ring := _by_ring(g)
	var baseline := 1
	for i in cfg.rings.size():
		var r := cfg.ring_count() - i
		t.check(cfg.rings[i].slots > 0 and cfg.rings[i].node_count > 0, "第 %d 环的两个数都不是 0" % r)
		t.eq(int(g.layout_meta["ring_slots"][r]), cfg.rings[i].slots, "第 %d 环：配置里写的槽位数 = 图上的" % r)
		t.check((by_ring[r] as Array).size() <= cfg.rings[i].slots, "第 %d 环：图上的点不多于槽位" % r)
		baseline += cfg.rings[i].node_count
	# 配置里的节点数是基准（范围中点）：每一局的总数在范围里抽，各环按基准的比例分
	var lim := cfg.node_range()
	t.check(baseline >= lim.x and baseline <= lim.y, "配置里各环节点数之和 %d 落在范围 %s 里" % [baseline, str(lim)])
	t.check(g.node_count() >= lim.x and g.node_count() <= lim.y, "图上 %d 个点也落在范围里" % g.node_count())
	# 0 仍然是合法写法：自动（按半径算槽位、填满）。那样算出来的点数不受规模模板管，
	# 所以拿一份没有规模模板的配置试
	cfg.scales = [] as Array[MapScaleProfile]
	cfg.rings[0].slots = 0
	cfg.rings[0].node_count = 0
	t.not_null(_gen().generate(cfg, 2), "手写配置里填 0（自动）照样能用")


static func run_lockstep(t: TestCase) -> void:
	t.begin("环形生成器 · 路线同步生长，合流之前互不相撞")

	var cfg := RingMapConfig.sample(6)
	var collisions := 0
	for s in 32:
		var g := _gen().generate(cfg, s)
		if g == null:
			continue
		# 前 converge_after_ring 步之内，任何两条路线不该落在同一个点上
		var owner := {}
		for i in g.routes.size():
			var ids: Array = g.routes[i]["node_ids"]
			for step in mini(cfg.converge_after_ring + 1, ids.size()):
				var id := int(ids[step])
				if owner.has(id) and owner[id] != i:
					collisions += 1
				owner[id] = i
	t.eq(collisions, 0, "32 个种子里没有一次提前合流")



static func run_determinism(t: TestCase) -> void:
	t.begin("环形生成器 · 同种子同一张图")

	var cfg := RingMapConfig.sample(4)
	var a := _gen().generate(cfg, 777)
	var b := _gen().generate(cfg, 777)
	t.not_null(a, "生成得出来")
	t.eq(JSON.stringify(b.to_dict()), JSON.stringify(a.to_dict()),
		"**同种子逐字节相同** —— 存档、回放、批量跑平衡都靠这条")

	var c := _gen().generate(cfg, 778)
	t.ne(JSON.stringify(c.to_dict()), JSON.stringify(a.to_dict()), "换个种子就是另一张图")

	# 同一个生成器实例连用两次，不该被上一次的中间状态污染
	var gen := _gen()
	gen.generate(cfg, 777)
	var again := gen.generate(cfg, 777)
	t.eq(JSON.stringify(again.to_dict()), JSON.stringify(a.to_dict()),
		"同一个实例复用，结果不变 —— 中间状态每次 build 都清干净")


static func run_gaps(t: TestCase) -> void:
	t.begin("环形生成器 · 节点少于槽位时匀着放，弧不跨空白区")

	# 一个环，18 个槽位只放 6 个点：点该匀着散在一圈上，不是挤在一段里
	var cfg := RingMapConfig.sample(2)
	cfg.scales = [] as Array[MapScaleProfile]
	cfg.rings[0].slots = 18
	cfg.rings[0].node_count = 6
	cfg.entry_count = 2
	cfg.zone_spec = null

	var made := 0
	for s in 16:
		var g := _gen().generate(cfg, s)
		if g == null:
			continue
		made += 1
		var filled: Array[int] = []
		for id in g.node_ids():
			if _ring_of(g, id) == 2:
				filled.append(int(g.get_node(id).layout["order"]))
		filled.sort()
		t.eq(filled.size(), 6, "第 2 环放了 6 个点（种子 %d）" % s)
		# 最长的空段不超过步长的两倍：匀着放，允许为了对上内环挪半步
		var worst := 0
		for i in filled.size():
			var nxt: int = filled[(i + 1) % filled.size()]
			worst = maxi(worst, posmod(nxt - filled[i], 18) - 1)
		t.check(worst <= 18 / 6 * 2, "最长空段 %d 格，不该挤成一团（种子 %d）" % [worst, s])
	t.check(made > 0, "至少跑成了一次")


## 路线在第 r 环上的（第一个）点；没经过这一环返回 -1。只有换乘那个用例问
static func _node_on_ring(graph: MapGraph, route: Dictionary, r: int, ring_of: Dictionary) -> int:
	for id in (route["node_ids"] as Array):
		if int(ring_of.get(int(id), -1)) == r:
			return int(id)
	return -1


## 只沿着这一环上的点走，看 a 到不到得了 b
static func _connected_within_ring(graph: MapGraph, a: int, b: int, r: int, ring_of: Dictionary) -> bool:
	var seen := {a: true}
	var queue: Array[int] = [a]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		if id == b:
			return true
		for n in graph.neighbors(id):
			if int(ring_of.get(n, -1)) == r and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return false


static func run_pivots(t: TestCase) -> void:
	t.begin("环形生成器 · 换乘点真的走得通")

	# 换乘是生成规则，不是合格条件 —— 弧上横着一段空白区时它连不过去，那张图照样合格。
	# 所以这里把空白区去掉再测：没有空白区，换乘弧就该条条走得通
	var cfg := RingMapConfig.sample(5)
	for spec in cfg.rings:
		spec.node_count = 0
	for s in 12:
		var g := _gen().generate(cfg, s)
		if g == null:
			continue
		var ring_of := {}
		for id in g.node_ids():
			ring_of[id] = _ring_of(g, id)

		# 相邻两条路线之间，至少有一环能只沿着那一环走过去
		for i in g.routes.size():
			var a: Dictionary = g.routes[i]
			var b: Dictionary = g.routes[(i + 1) % g.routes.size()]
			var linked := false
			for r in range(cfg.ring_count(), 0, -1):
				var ia := _node_on_ring(g, a, r, ring_of)
				var ib := _node_on_ring(g, b, r, ring_of)
				if ia < 0 or ib < 0:
					continue
				if ia == ib or _connected_within_ring(g, ia, ib, r, ring_of):
					linked = true
					break
			t.check(linked, "路线 %s 与 %s 之间换乘得过去（种子 %d）"
				% [a["style"], b["style"], s])


static func run_rejects_bad_config(t: TestCase) -> void:
	t.begin("环形生成器 · 配置不成立时干净地失败")

	# 没有环
	t.is_null(_gen().generate(RingMapConfig.new(), 1, 3), "一个环都没有，造不出来")

	# 没有路线风格：路线是生成之初就该有的东西，没有就不是这张图
	var no_routes := RingMapConfig.sample(3)
	no_routes.routes = [] as Array[RouteStyle]
	t.is_null(_gen().generate(no_routes, 1, 3), "没有路线风格，造不出来")

	# 一个环也能跑：出生点与核心直接相连
	var one := RingMapConfig.sample(1)
	one.entry_count = 2
	var g := _gen().generate(one, 5)
	t.not_null(g, "只有一个环也生成得出来")
	if g != null:
		t.eq(g.get_node(RingMapGenerator.CORE_ID).tier, 1, "核心的 tier 是环数")
		for route in g.routes:
			if String(route["ends_at"]) == "core":
				t.eq(int((route["node_ids"] as Array)[-1]), RingMapGenerator.CORE_ID,
					"去核心的路线一步就到")

	# 断边概率拉满：骨架与换乘弧仍然保得住
	var brittle := RingMapConfig.sample(4)
	brittle.tangential_break_chance = 1.0
	var broken := _gen().generate(brittle, 9)
	t.not_null(broken, "切向边全断也生成得出来 —— 径向边撑着，不会散架")
	if broken != null:
		for route in broken.routes:
			var ids: Array = route["node_ids"]
			for i in range(1, ids.size()):
				t.check(broken.edge_between(int(ids[i - 1]), int(ids[i])) != null,
					"骨架边不受断边影响")


static func run_registry_wired(t: TestCase) -> void:
	t.begin("环形生成器 · 已登记进注册表")

	t.check(MapGeneratorRegistry.has(&"ring"), "注册表里有 ring")
	var gen := MapGeneratorRegistry.create(&"ring")
	t.not_null(gen, "造得出实例")
	t.check(gen is RingMapGenerator, "造出来的是 RingMapGenerator")
	if gen != null:
		t.not_null(gen.generate(RingMapConfig.sample(3), 1), "从注册表拿到的能直接用")
#endregion


static func run_route_length_and_node_spread(t: TestCase) -> void:
	t.begin("环形生成器 · 路线随环数变长；节点数在范围里抽；中环加宽")

	for rings in [4, 6, 8]:
		var cfg := RingMapConfig.sample(rings)
		var steps := 0.0
		var routes := 0
		var counts := {}
		for s in 24:
			var g := _gen().generate(cfg, s)
			if g == null:
				continue
			counts[g.node_count()] = true
			for route in g.routes:
				steps += float((route["node_ids"] as Array).size() - 1)
				routes += 1
		var avg := steps / float(maxi(1, routes))
		# 每环一步是底；系数多出来的那一半以上得真走出来（横着走是尽力而为，走不动就算）
		t.check(avg >= float(rings) * (1.0 + (cfg.route_length_factor - 1.0) * 0.5),
			"%d 环：路线平均 %.1f 步，长度系数 %.2f 至少兑现一半" % [rings, avg, cfg.route_length_factor])
		t.check(counts.size() >= 3,
			"%d 环：24 个种子里节点数至少 3 种（%s）—— 是范围不是定数" % [rings, str(counts.keys())])
		t.check(cfg.node_range().y > cfg.node_range().x, "%d 环的节点数范围 %s 是个区间" % [rings, str(cfg.node_range())])

	t.eq(RingMapConfig.middle_rings(4), [2, 3] as Array[int], "4 环的中环是第 2、3 环")
	t.eq(RingMapConfig.middle_rings(5), [3] as Array[int], "5 环的中环是第 3 环")
	t.eq(RingMapConfig.middle_rings(6), [3, 4] as Array[int], "6 环的中环是第 3、4 环")
	t.eq(RingMapConfig.middle_rings(7), [4] as Array[int], "7 环的中环是第 4 环")
	t.eq(RingMapConfig.middle_rings(8), [4, 5] as Array[int], "8 环的中环是第 4、5 环")
	var cfg6 := RingMapConfig.sample(6)
	t.check(cfg6.slots_for_ring(3) >= cfg6.slots_for_ring(2) + cfg6.mid_ring_extra_slots,
		"中环比里面那环至少宽出加的那几个槽位（%d vs %d）" % [cfg6.slots_for_ring(3), cfg6.slots_for_ring(2)])
	# 节点范围对着槽位数定，填充率六七成上下
	for rings in [4, 5, 6, 7, 8]:
		var cfg := RingMapConfig.sample(rings)
		var slots := 0
		for r in range(1, rings + 1):
			slots += cfg.slots_for_ring(r)
		var lim := cfg.node_range()
		var lo := float(lim.x - 1) / float(slots)
		var hi := float(lim.y - 1) / float(slots)
		t.check(lo >= 0.55 and hi <= 0.8,
			"%d 环：节点 %s / 槽位 %d = %.0f%%～%.0f%%，填充率在六七成上下" % [rings, str(lim), slots, lo * 100.0, hi * 100.0])


static func run_route_ends_and_pivot_pairs(t: TestCase) -> void:
	t.begin("环形生成器 · 路线尽头不被高危区吸收；换乘记着是谁和谁的")

	var cfg := RingMapConfig.sample(6)
	var eaten := 0
	var links := 0
	var arcs := 0
	for s in 48:
		var g := _gen().generate(cfg, s)
		if g == null:
			continue
		for route in g.routes:
			var last := g.get_node(int((route["node_ids"] as Array)[-1]))
			if last.zone != 0:
				eaten += 1
		for link in (g.layout_meta.get("pivot_links", []) as Array):
			links += 1
			t.check((link as Array).size() == 4 and int(link[2]) != int(link[3]), "换乘直连带着两条路线的下标")
		for arc in (g.layout_meta.get("pivot_arcs", []) as Array):
			arcs += 1
			t.check((arc["routes"] as Array).size() == 2 and not (arc["node_ids"] as Array).is_empty(),
				"换乘弧带着两条路线的下标与弧上的点")
	t.eq(eaten, 0, "48 个种子里没有一条路线的尽头被高危区吸收")
	t.check(links + arcs > 0, "有换乘记录（直连 %d，弧 %d）" % [links, arcs])
