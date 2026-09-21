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
		# 逐环向内，一环不跳
		for i in range(1, ids.size()):
			var a := _ring_of(g, int(ids[i - 1]))
			var b := _ring_of(g, int(ids[i]))
			if b != a - 1:
				return "路线 %s 从第 %d 环跳到了第 %d 环" % [route["style"], a, b]

	# --- 高危区：区内连通、与区外恰好一条边、不含骨架节点 ---
	var skeleton := {}
	for route in g.routes:
		for id in (route["node_ids"] as Array):
			skeleton[int(id)] = true
	for zone_id in g.zones:
		var info: Dictionary = g.zones[zone_id]
		var ids: Array = info["node_ids"]
		var inside := {}
		for id in ids:
			inside[int(id)] = true
			if skeleton.has(int(id)):
				return "高危区 %s 占了骨架节点 %d" % [zone_id, id]
			if g.get_node(int(id)).danger != 2:
				return "高危区 %s 里的节点 %d 危险等级不是 2" % [zone_id, id]
		var gates := 0
		for e in g.edges:
			if inside.has(e.from_id) != inside.has(e.to_id):
				gates += 1
		if gates != 1:
			return "高危区 %s 与区外有 %d 条边" % [zone_id, gates]
		if int(info["gate_id"]) < 0 or not inside.has(int(info["gate_id"])):
			return "高危区 %s 的 gate 不在区内" % zone_id

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
	t.begin("环形生成器 · 高危区可选、且有环数门槛")

	# 门槛从配置里读，不写死是 5
	var cfg := RingMapConfig.sample(5)
	var spec: DangerZoneSpec = cfg.danger_zones[0]
	var below := RingMapConfig.sample(spec.min_rings - 1)
	for s in 8:
		var gen := _gen()
		var g := gen.generate(below, s)
		t.not_null(g, "环数比门槛少一环也生成得出来（种子 %d）" % s)
		if g != null:
			t.eq(g.zones.size(), 0, "环数不到门槛，没有高危区")
			t.check(not gen.failure_tally.has(&"zone_missing"), "也不会因为「缺高危区」而重试")

	var at := RingMapConfig.sample(spec.min_rings)
	var g_at := _gen().generate(at, 3)
	t.not_null(g_at, "环数正好到门槛，生成得出来")
	if g_at != null:
		t.eq(g_at.zones.size(), at.danger_zones.size(), "到了门槛就有高危区")

	# 一片怎么都长不起来的高危区：大到整张图放不下
	var impossible := RingMapConfig.sample(spec.min_rings)
	impossible.danger_zones[0].size = Vector2i(999, 999)
	t.is_null(_gen().generate(impossible, 1, 4), "必须有却长不起来 → 这张图生成失败")

	impossible.danger_zones[0].required = false
	var relaxed := _gen().generate(impossible, 1, 4)
	t.not_null(relaxed, "改成可选 → 照样生成")
	if relaxed != null:
		t.eq(relaxed.zones.size(), 0, "那一片被跳过了")
		t.eq(int(relaxed.layout_meta.get("zones_skipped", 0)), 1,
			"跳过了几片记在 layout_meta 里 —— 不是不声不响")


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

	var cfg := RingMapConfig.sample(5)
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
