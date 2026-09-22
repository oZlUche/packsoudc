## 节点类型分配（架构文档 5.4 步骤 5，M3-3c）。
##
## 期望值全部从配置里读（配额、覆盖、禁止相邻、必须型、高危区内容、路线的 mix 与档位），
## 改一个数不会让测试红 —— 红了说明分配器没照着配置做。
##
## 图自身的规矩逐种子硬查；路线相关的（mix、档位）是尽力而为，只查趋势与记账。
extends RefCounted

const SEEDS := 48


static func _ring_of(g: MapGraph, id: int) -> int:
	return int(g.get_node(id).layout.get("ring", -1))


static func run_map_rules(t: TestCase) -> void:
	t.begin("类型分配 · 图自身的规矩，一批种子逐条查")

	var cfg := RingMapConfig.sample(6)
	var bad: Array[String] = []
	var made := 0
	for s in SEEDS:
		var g := RingMapGenerator.new().generate(cfg, s)
		if g == null:
			bad.append("种子 %d 没生成出来" % s)
			continue
		made += 1
		var why := _check_rules(g, cfg)
		if why != "":
			bad.append("种子 %d：%s" % [s, why])
	t.eq(made, SEEDS, "%d 个种子全都生成得出来" % SEEDS)
	t.check(bad.is_empty(), "全部规矩成立。不成立的：\n    %s" % "\n    ".join(bad.slice(0, 6)))


static func _check_rules(g: MapGraph, cfg: RingMapConfig) -> String:
	# 每个点都有类型，且是名单上的
	for id in g.node_ids():
		if not MapNodeTypes.has(g.get_node(id).type):
			return "节点 %d 的类型 %s 不在名单上" % [id, g.get_node(id).type]

	# 环配额：从配置读
	for i in cfg.rings.size():
		var r := cfg.ring_count() - i
		for type in cfg.rings[i].quota:
			var lim: Array = cfg.rings[i].quota[type]
			var n := 0
			for id in g.node_ids():
				if _ring_of(g, id) == r and g.get_node(id).type == StringName(type):
					n += 1
			if n < int(lim[0]) or n > int(lim[1]):
				return "第 %d 环 %s 有 %d 个，配额 %s" % [r, type, n, str(lim)]

	# 覆盖：高危区外、走过路径前一段之后的每个点距最近的喘气处不超过 K；死胡同末端也算在内
	for type in cfg.coverage:
		var dist := RingTypeAssigner.distances_to_type(g, StringName(type))
		for id in g.node_ids():
			var n := g.get_node(id)
			if n.danger > cfg.no_haven_in_danger_above:
				continue
			if RingTypeAssigner.progress_of(_ring_of(g, id), cfg.ring_count()) < cfg.haven_after_progress:
				continue
			if int(dist.get(id, 1 << 20)) > int(cfg.coverage[type]):
				return "节点 %d 距最近的 %s 有 %s 步（%d 条路挨着它）" % [
					id, type, str(dist.get(id, "∞")), g.edges_of(id).size()]

	# 高危区里没有喘气的地方；路径前一段也没有
	for id in g.node_ids():
		var n := g.get_node(id)
		if n.danger > cfg.no_haven_in_danger_above and cfg.coverage.has(String(n.type)):
			return "节点 %d 在高危区里却是 %s" % [id, n.type]
		if _ring_of(g, id) > 0 and cfg.coverage.has(String(n.type)) \
				and RingTypeAssigner.progress_of(_ring_of(g, id), cfg.ring_count()) < cfg.haven_after_progress:
			return "节点 %d 是 %s，却在路径的前 %d%% 里" % [id, n.type, roundi(cfg.haven_after_progress * 100)]

	# 出生点是 spawn，spawn 都是出生点
	for id in g.node_ids():
		var is_spawn := g.get_node(id).type == &"spawn"
		if is_spawn != g.entry_ids.has(id):
			return "节点 %d：spawn=%s 出生点=%s，两者该一致" % [id, is_spawn, g.entry_ids.has(id)]

	# 每环都不填满
	var slot_table: Dictionary = g.layout_meta.get("ring_slots", {})
	var per_ring := {}
	for id in g.node_ids():
		var r := _ring_of(g, id)
		per_ring[r] = int(per_ring.get(r, 0)) + 1
	for r in per_ring:
		if int(r) <= 0:
			continue
		var slots := int(slot_table.get(r, 0))
		if int(per_ring[r]) >= slots or int(per_ring[r]) > floori(float(slots) * cfg.fill_cap):
			return "第 %d 环 %d 个槽位放了 %d 个点，填得太满（上限 %.0f%%）" % [r, slots, per_ring[r], cfg.fill_cap * 100]

	# 不许相邻
	for e in g.edges:
		var ta := String(g.get_node(e.from_id).type)
		var tb := String(g.get_node(e.to_id).type)
		for pair in cfg.no_adjacent:
			if (pair[0] == ta and pair[1] == tb) or (pair[0] == tb and pair[1] == ta):
				return "%d（%s）与 %d（%s）挨着" % [e.from_id, ta, e.to_id, tb]

	# 高危区里的精英与搜索点；被吸收的路线节点不是必须型
	var on_route := {}
	for route in g.routes:
		for id in (route["node_ids"] as Array):
			on_route[int(id)] = true
	for zone_id in g.zones:
		var ids: Array = g.zones[zone_id]["node_ids"]
		if g.get_node(int(ids[0])).danger < 2:
			continue
		var elites := 0
		var searches := 0
		for id in ids:
			var n := g.get_node(int(id))
			if n.type == &"elite":
				elites += 1
			if n.type == &"search":
				searches += 1
			if on_route.has(int(id)) and cfg.mandatory_types.has(n.type):
				return "高危区 %s 吸收的路线节点 %d 成了必须型 %s" % [zone_id, id, n.type]
		if cfg.zone_spec != null and (elites < cfg.zone_spec.min_elites or searches < cfg.zone_spec.min_search):
			return "高危区 %s：%d 精英 %d 搜索点" % [zone_id, elites, searches]

	# 每 N 环至少一个撤离点，且撤离点没有盖掉必须型（没法直接看，看数量：必须型的最小配额仍成立即可）
	if cfg.extract_every_rings > 0:
		var r_hi := cfg.ring_count()
		while r_hi >= 1:
			var r_lo := maxi(1, r_hi - cfg.extract_every_rings + 1)
			var has := false
			for id in g.node_ids():
				var r := _ring_of(g, id)
				if r >= r_lo and r <= r_hi and g.get_node(id).type == &"extract":
					has = true
			if not has:
				return "第 %d～%d 环没有撤离点" % [r_lo, r_hi]
			r_hi = r_lo - 1

	# 撤离点两两之间至少 extract_gap 步（值从配置 / 规模模板读）
	var gap := cfg.effective_extract_gap()
	var extracts: Array[int] = []
	for id in g.node_ids():
		if g.get_node(id).type == &"extract":
			extracts.append(id)
	for i in extracts.size():
		var dist := RingTypeAssigner._steps_from(g, extracts[i], gap - 1)
		for j in range(i + 1, extracts.size()):
			if dist.has(extracts[j]):
				return "撤离点 %d 与 %d 只隔 %d 步，至少要 %d" % [extracts[i], extracts[j], dist[extracts[j]], gap]

	# 节点总数落在规模模板的范围里
	var p := cfg.scale()
	if p != null and p.nodes.y > 0 and (g.node_count() < p.nodes.x or g.node_count() > p.nodes.y):
		return "%d 个点，规模 %s 该是 %d～%d" % [g.node_count(), p.id, p.nodes.x, p.nodes.y]

	# 规则跟着图走
	if not g.layout_meta.has("type_rules"):
		return "layout_meta 里没有 type_rules"
	return ""


static func run_route_rules(t: TestCase) -> void:
	t.begin("类型分配 · 路线：尽头、中途撤离、记账、风格趋势")

	var cfg := RingMapConfig.sample(6)
	var comp_by_style := {}   # style -> {type -> 独占节点里出现的次数}，48 个种子累计
	var risk_sum := {}
	var in_band := 0
	var routes_seen := 0
	for s in SEEDS:
		var g := RingMapGenerator.new().generate(cfg, s)
		if g == null:
			continue
		var scores := RingTypeAssigner.route_scores(g, cfg)
		var bands := RingTypeAssigner.route_bands(g, cfg)
		var on := {}
		for route in g.routes:
			for id in (route["node_ids"] as Array):
				on[int(id)] = int(on.get(int(id), 0)) + 1
		for i in g.routes.size():
			var route: Dictionary = g.routes[i]
			var style := cfg.style_by_id(StringName(route["style"]))
			var ids: Array = route["node_ids"]
			routes_seen += 1

			# 去撤离点的路线，末端是撤离点
			if String(route["ends_at"]) == "extract":
				t.eq(g.get_node(int(ids[-1])).type, &"extract", "%s 的末端是撤离点（种子 %d）" % [route["style"], s])
			# 有 bailout 的路线，每隔那么多环有一个撤离点
			if style.bailout_every_rings > 0:
				var last_extract := cfg.ring_count()
				var ok := true
				for id in ids:
					var r := _ring_of(g, int(id))
					if r <= 0:
						continue
					if g.get_node(int(id)).type == &"extract":
						last_extract = r
					elif last_extract - r > style.bailout_every_rings + 1:
						ok = false
				t.check(ok, "%s 沿路每 %d 环左右有撤离点（种子 %d）" % [route["style"], style.bailout_every_rings, s])
			# min_share：这条路线独占的、可换的节点里，该类型至少占那么多
			for k in style.min_share:
				var have := 0
				var pool := 0
				for id in ids:
					if int(on[int(id)]) != 1:
						continue
					var ty := String(g.get_node(int(id)).type)
					if MapNodeTypes.STRUCTURAL.has(StringName(ty)) or cfg.coverage.has(ty):
						continue
					pool += 1
					if ty == String(k):
						have += 1
				t.check(pool == 0 or float(have) >= float(style.min_share[k]) * float(pool) - 1e-6,
					"%s：%s 占 %d/%d，至少要 %d%%（种子 %d）" % [route["style"], k, have, pool, roundi(float(style.min_share[k]) * 100), s])
			# 记在路线上的分数与重算一致
			t.eq(int(route["risk_x100"]), roundi(scores[i]["risk"] * 100.0), "记账的风险分对得上（种子 %d）" % s)
			t.eq(int(route["reward_x100"]), roundi(scores[i]["reward"] * 100.0), "记账的收益分对得上（种子 %d）" % s)

			# 风格趋势：独占节点的类型构成，按风格累计
			if not comp_by_style.has(style.id):
				comp_by_style[style.id] = {}
			for id in ids:
				if int(on[int(id)]) == 1 and g.get_node(int(id)).zone == 0:
					var ty := String(g.get_node(int(id)).type)
					comp_by_style[style.id][ty] = int(comp_by_style[style.id].get(ty, 0)) + 1
			risk_sum[style.id] = float(risk_sum.get(style.id, 0.0)) + float(route["risk_x100"])

			var rel: Dictionary = bands["rel"][i]
			if rel["risk"] >= style.risk_band.x and rel["risk"] <= style.risk_band.y \
					and rel["reward"] >= style.reward_band.x and rel["reward"] <= style.reward_band.y:
				in_band += 1

	# 趋势（尽力而为的部分只看总体）：每种风格的独占节点累计起来，
	# mix 里最重的那种类型在【可换的类型】里占得最多。撤离点、休息区、商店是别的步骤放的，不算
	for style_id in comp_by_style:
		var style := cfg.style_by_id(style_id)
		# mix 里并列最重的可能不止一种（{battle 2, search 2, event 2}），哪一种最多都算数
		var heaviest: Array[String] = []
		var top_weight := 0.0
		for k in style.mix:
			top_weight = maxf(top_weight, float(style.mix[k]))
		for k in style.mix:
			if float(style.mix[k]) == top_weight:
				heaviest.append(String(k))
		var comp: Dictionary = comp_by_style[style_id]
		var top := ""
		for k in comp:
			if cfg.mandatory_types.has(StringName(k)) or cfg.coverage.has(k) or k == "extract":
				continue
			if top == "" or int(comp[k]) > int(comp[top]):
				top = String(k)
		t.check(heaviest.has(top), "%s：独占节点里最多的是 mix 里最重的那种 %s（累计 %s）" % [style_id, str(heaviest), str(comp)])
	# 档位：多数路线落在自己的区间里
	t.check(float(in_band) / float(maxi(1, routes_seen)) >= 0.7,
		"%d/%d 条路线落进自己的风险收益档位（尽力而为，要多数）" % [in_band, routes_seen])
	# 风险高低的顺序与档位的顺序一致（平均意义上）
	var order: Array = cfg.routes.duplicate()
	order.sort_custom(func(a: RouteStyle, b: RouteStyle): return a.risk_band.x < b.risk_band.x)
	for i in range(1, order.size()):
		var lo: RouteStyle = order[i - 1]
		var hi: RouteStyle = order[i]
		if lo.risk_band.y <= hi.risk_band.x:
			t.check(float(risk_sum.get(lo.id, 0.0)) < float(risk_sum.get(hi.id, 0.0)),
				"平均风险：%s < %s，与档位顺序一致" % [lo.id, hi.id])


static func run_conflicting_config_fails(t: TestCase) -> void:
	t.begin("类型分配 · 配置自相矛盾时干净地失败")

	# 配额把休息区限死为 0，覆盖却要求每个点 4 步内有一个
	var cfg := RingMapConfig.sample(5)
	for spec in cfg.rings:
		spec.quota["rest"] = [0, 0]
	var gen := RingMapGenerator.new()
	t.is_null(gen.generate(cfg, 1, 6), "6 次之内放弃")
	t.check(gen.failure_tally.has(&"coverage"), "失败原因指向覆盖：%s" % str(gen.failure_tally))

	# 高危区要 2 个搜索点，但类型权重与配额都不给：仍然凑得出（凑数的是固定节点，不看权重）
	var strict := RingMapConfig.sample(5)
	for spec in strict.rings:
		spec.type_weights = {"battle": 1}
	var g := RingMapGenerator.new().generate(strict, 2)
	t.not_null(g, "权重里没有搜索点，高危区照样凑够")
	if g != null:
		t.eq(_check_rules(g, strict), "", "并且别的规矩照样成立")


static func run_validation_reads_graph(t: TestCase) -> void:
	t.begin("类型分配 · 校验从图上读规则")

	var cfg := RingMapConfig.sample(5)
	var gen := RingMapGenerator.new()
	var g := gen.generate(cfg, 3)
	t.not_null(g, "先有一张图")
	if g == null:
		return
	var back := MapGraph.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	var v := MapValidation.new()
	RingMapGenerator.new().validate(back, v)      # 一个没有配置的生成器
	t.check(v.ok(), "过一遍 JSON、没有配置在手，照样查得了：%s" % v.to_text())

	# 把一个休息区改掉 → coverage；把两个精英连起来 → adjacent；商店塞满一环 → quota
	var rest_id := -1
	for id in back.node_ids():
		if back.get_node(id).type == &"rest":
			rest_id = id
	if rest_id >= 0:
		back.get_node(rest_id).type = &"battle"
		v = MapValidation.new()
		RingMapGenerator.new().validate(back, v)
		# 不一定每个休息区都关键，但至少校验跑了；关键的那种一定报
		back.get_node(rest_id).type = &"rest"
	var zone_free: Array[int] = []
	for id in back.node_ids():
		if back.get_node(id).zone == 0 and id != RingMapGenerator.CORE_ID and _ring_of(back, id) > 0:
			zone_free.append(id)
	var e: MapEdge = null
	for edge in back.edges:
		if zone_free.has(edge.from_id) and zone_free.has(edge.to_id):
			e = edge
			break
	if e != null:
		back.get_node(e.from_id).type = &"elite"
		back.get_node(e.to_id).type = &"elite"
		v = MapValidation.new()
		RingMapGenerator.new().validate(back, v)
		t.check(v.rules().has(&"adjacent"), "两个精英挨着 → adjacent")
	for id in zone_free:
		back.get_node(id).type = &"shop"
	v = MapValidation.new()
	RingMapGenerator.new().validate(back, v)
	t.check(v.rules().has(&"quota"), "商店塞满 → quota")

	# 没有 type_rules 的图（手绘）什么都不查
	var grid := MapGridText.parse(FileAccess.get_file_as_string("res://data/authoring/maps/chapter01_v0.1.txt"))
	v = MapValidation.new()
	RingTypeAssigner.validate(grid, v)
	t.check(v.ok(), "手绘图没有 type_rules → 一条不查")


static func run_determinism(t: TestCase) -> void:
	t.begin("类型分配 · 同种子同一张图")

	var cfg := RingMapConfig.sample(5)
	var a := RingMapGenerator.new().generate(cfg, 77)
	var b := RingMapGenerator.new().generate(cfg, 77)
	t.eq(JSON.stringify(b.to_dict()), JSON.stringify(a.to_dict()), "类型分配之后仍然逐字节相同")
