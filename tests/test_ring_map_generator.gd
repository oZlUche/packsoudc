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
	if g.entry_ids.size() != mini(cfg.entry_count, outer):
		return "出生点有 %d 个，配置要 %d 个" % [g.entry_ids.size(), cfg.entry_count]
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

	# --- 高危区：环数不够就不该有；够了且必须有，就得有 ---
	var expected_zones := 0
	for spec in cfg.danger_zones:
		if spec.applies_to(cfg.ring_count()) and spec.required:
			expected_zones += 1
	if g.zones.size() < expected_zones:
		return "该有 %d 片高危区，只有 %d 片" % [expected_zones, g.zones.size()]

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
		elif _ring_of(g, int(ids[-1])) != 1:
			return "路线 %s 该停在核心前一环" % route["style"]
		# 每一步要么向内一环，要么沿当前这环横着挪（正对着空白区时）—— 不向外、不跳环
		for i in range(1, ids.size()):
			var a := _ring_of(g, int(ids[i - 1]))
			var b := _ring_of(g, int(ids[i]))
			if b != a - 1 and b != a:
				return "路线 %s 从第 %d 环跳到了第 %d 环" % [route["style"], a, b]

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
		var inside := {}
		var absorbed := 0
		for id in ids:
			inside[int(id)] = true
			if on_route.has(int(id)):
				absorbed += 1
			if g.get_node(int(id)).danger != 2 or g.get_node(int(id)).zone != int(zone_id):
				return "高危区 %s 里的节点 %d 没标上 zone / danger" % [zone_id, id]
		if ids.size() < rules.min_size or ids.size() > rules.max_size:
			return "高危区 %s 有 %d 个点" % [zone_id, ids.size()]
		if not RingMapGenerator._zone_connected(g, ids, inside):
			return "高危区 %s 内部不相连" % zone_id
		# 路线节点只会在「只长到两个点」时被划进来凑数，所以含路线节点的区一定是最小规模
		if absorbed > 1 or (absorbed == 1 and ids.size() != rules.min_size):
			return "高危区 %s（%d 个点）里有 %d 个路线节点" % [zone_id, ids.size(), absorbed]
		var gates := ZoneRules.crossing_edges(g, ids).size()
		if gates < 1 or gates > rules.max_gates_for(ids.size()):
			return "高危区 %s（%d 个点）有 %d 个出入口，上限 %d" % [
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
		if mini(posmod(sa - sb, slots), posmod(sb - sa, slots)) != 1:
			return "切向边跨过了空白区：第 %d 环 %d↔%d" % [ra, sa, sb]

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


static func run_zone_rules(t: TestCase) -> void:
	t.begin("环形生成器 · 高危区：环数门槛、可选、软上限")

	# 门槛从配置里读，不写死
	var spec: DangerZoneSpec = RingMapConfig.sample(5).danger_zones[0]
	var below := RingMapConfig.sample(spec.min_rings - 1)
	for s in 8:
		var gen := _gen()
		var g := gen.generate(below, s)
		t.not_null(g, "环数比门槛少一环也生成得出来（种子 %d）" % s)
		if g != null:
			t.eq(g.zones.size(), 0, "环数不到门槛，没有高危区")
			t.check(not gen.failure_tally.has(&"zone_missing"), "也不会因为「缺高危区」而重试")

	# 到了门槛就有；规模不超过这个环数对应的软上限
	for rings in [spec.min_rings, spec.min_rings + 2]:
		var cfg := RingMapConfig.sample(rings)
		var cap := cfg.danger_zones[0].soft_cap_for(rings)
		for s in 12:
			var g := _gen().generate(cfg, s)
			t.not_null(g, "%d 环生成得出来（种子 %d）" % [rings, s])
			if g == null:
				continue
			t.eq(g.zones.size(), cfg.danger_zones.size(), "配了几片就有几片")
			for zone_id in g.zones:
				var size: int = (g.zones[zone_id]["node_ids"] as Array).size()
				t.check(size <= maxi(cap, cfg.zone_rules.min_size),
					"%d 环的高危区 %d 个点，软上限 %d" % [rings, size, cap])

	# 一片永远岔不出来的：要求路线走过 200% 才岔
	var never := RingMapConfig.sample(spec.min_rings + 1)
	never.danger_zones[0].start_after_progress = 2.0
	t.is_null(_gen().generate(never, 1, 4), "必须有却岔不出来 → 这张图生成失败")

	never.danger_zones[0].required = false
	var relaxed := _gen().generate(never, 1, 4)
	t.not_null(relaxed, "改成可选 → 照样生成")
	if relaxed != null:
		t.eq(relaxed.zones.size(), 0, "那一片被跳过了")
		t.eq(int(relaxed.layout_meta.get("zones_skipped", 0)), 1,
			"跳过了几片记在 layout_meta 里 —— 不是不声不响")


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

	# 给一片区多开几个口，开到超过上限 → zone_gate
	var zone_id: int = g.zones.keys()[0]
	var ids: Array = g.zones[zone_id]["node_ids"]
	var cap := rules.max_gates_for(ids.size())
	var inside := {}
	for id in ids:
		inside[int(id)] = true
	var outsiders: Array[int] = []
	for id in g.node_ids():
		if not inside.has(id):
			outsiders.append(id)
	var k := 0
	while ZoneRules.crossing_edges(g, ids).size() <= cap and k < outsiders.size():
		if g.edge_between(int(ids[0]), outsiders[k]) == null:
			g.connect_nodes(int(ids[0]), outsiders[k], &"radial")
		k += 1
	var v := MapValidation.new()
	gen.validate(g, v)
	t.check(v.rules().has(&"zone_gate"), "出入口超过上限 → zone_gate")

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
	t.begin("高危区 · 多个出入口尽量分开")

	# 统计：有两个以上出入口、且区内不止一个点挨着区外的那些区里，
	# 出入口应当落在不同的点上（挤在同一个点上等于只有一个口）
	var cfg := RingMapConfig.sample(7)
	var multi := 0
	var crowded := 0
	for s in 48:
		var g := _gen().generate(cfg, s)
		if g == null:
			continue
		var on_route := {}
		for route in g.routes:
			for id in (route["node_ids"] as Array):
				on_route[int(id)] = true
		for zone_id in g.zones:
			var ids: Array = g.zones[zone_id]["node_ids"]
			var edges := ZoneRules.crossing_edges(g, ids)
			# 吸收了路线节点的小区不算：它的两个口就是那个点原本的两条路线边，本来就在同一个点上
			var absorbed := false
			for id in ids:
				if on_route.has(int(id)):
					absorbed = true
			if edges.size() < 2 or absorbed:
				continue
			multi += 1
			if (g.zones[zone_id]["gate_ids"] as Array).size() < edges.size():
				crowded += 1
	t.check(multi > 0, "48 个种子里出现过多出入口的高危区（%d 片）" % multi)
	t.eq(crowded, 0, "没有哪一片把两个口开在同一个点上")


static func run_entries(t: TestCase) -> void:
	t.begin("环形生成器 · 出生点间隔")

	var cfg := RingMapConfig.sample(5)
	var slots := cfg.slots_for_ring(cfg.ring_count())
	# 能放下的最大间隔：槽位数 / 出生点数（先把空白区去掉，免得碰运气）
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
	brittle.tangential_break_chance = 1.0
	for s in 16:
		var gg := _gen()
		t.not_null(gg.generate(brittle, s, 1), "切向边能断的全断，第一次尝试就连通（种子 %d）" % s)


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
	t.begin("环形生成器 · 空白区连成整段")

	# 一个环，18 个槽位只放 12 个点 —— 空出来的 6 个该连成 1～2 段，不是撒胡椒面
	var cfg := RingMapConfig.sample(2)
	cfg.rings[0].slots = 18
	cfg.rings[0].node_count = 12
	cfg.entry_count = 2
	cfg.danger_zones = [] as Array[DangerZoneSpec]

	var runs_seen: Array[int] = []
	for s in 16:
		var g := _gen().generate(cfg, s)
		if g == null:
			continue
		var filled := {}
		for id in g.node_ids():
			if _ring_of(g, id) == 2:
				filled[int(g.get_node(id).layout["order"])] = true
		t.eq(filled.size(), 12, "第 2 环放了 12 个点（种子 %d）" % s)

		# 数一数空槽连成几段
		var runs := 0
		for slot in 18:
			if not filled.has(slot) and filled.has(posmod(slot - 1, 18)):
				runs += 1
		runs_seen.append(runs)
		t.check(runs >= 1 and runs <= 2,
			"空槽连成 %d 段（种子 %d）—— 该是 1～2 段整弧，不是零散缺口" % [runs, s])
	t.check(runs_seen.size() > 0, "至少跑成了一次")


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
			for r in range(cfg.ring_count(), 0, -cfg.pivot_every_rings):
				var ia := RingMapGenerator._node_on_ring(g, a, r, ring_of)
				var ib := RingMapGenerator._node_on_ring(g, b, r, ring_of)
				if ia < 0 or ib < 0:
					continue
				if ia == ib or RingMapGenerator._connected_within_ring(g, ia, ib, r, ring_of):
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
