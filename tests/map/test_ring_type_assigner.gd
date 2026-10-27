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

	# 覆盖：高危区外的每个点距最近的喘气处不超过 K；死胡同末端也算在内
	for type in cfg.coverage:
		var dist := MapNavigator.distances_to_type(g, StringName(type))
		for id in g.node_ids():
			var n := g.get_node(id)
			if n.danger > cfg.no_haven_in_danger_above:
				continue
			if int(dist.get(id, 1 << 20)) > int(cfg.coverage[type]):
				return "节点 %d 距最近的 %s 有 %s 步（%d 条路挨着它）" % [
					id, type, str(dist.get(id, "∞")), g.edges_of(id).size()]

	# 高危区里没有喘气的地方
	for id in g.node_ids():
		var n := g.get_node(id)
		if n.danger > cfg.no_haven_in_danger_above and cfg.coverage.has(String(n.type)):
			return "节点 %d 在高危区里却是 %s" % [id, n.type]

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

	# 撤离点只在撤离环间（去撤离点的路线也在那里收尾，报告 053），且那里至少有一个；不在高危区里
	var band := cfg.extract_band()
	if not band.is_empty():
		var in_band := 0
		for id in g.node_ids():
			if g.get_node(id).type != &"extract":
				continue
			var r := _ring_of(g, id)
			if band.has(r):
				in_band += 1
			else:
				return "撤离点 %d 在第 %d 环，不在撤离环间 %s" % [id, r, str(band)]
			if g.get_node(id).zone != 0:
				return "撤离点 %d 开在高危区里" % id
		if in_band == 0:
			return "撤离环间 %s 里没有撤离点" % str(band)

	# 撤离点两两之间至少 extract_gap 步（值从配置 / 规模模板读）
	var gap := cfg.effective_extract_gap()
	var extracts: Array[int] = []
	for id in g.node_ids():
		if g.get_node(id).type == &"extract":
			extracts.append(id)
	for i in extracts.size():
		var dist := MapNavigator.within_steps(g, extracts[i], gap - 1)
		for j in range(i + 1, extracts.size()):
			if dist.has(extracts[j]):
				return "撤离点 %d 与 %d 只隔 %d 步，至少要 %d" % [extracts[i], extracts[j], dist[extracts[j]], gap]

	# 节点总数落在规模模板的范围里
	var lim := cfg.node_range()
	if lim.y > 0 and (g.node_count() < lim.x or g.node_count() > lim.y):
		return "%d 个点，这个环数该是 %d～%d" % [g.node_count(), lim.x, lim.y]

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


static func run_band_extracts_and_step_havens(t: TestCase) -> void:
	t.begin("类型分配 · 撤离点在撤离环间、尽量两条路线共用；喘气处按路线步数放")

	for rings in [4, 6]:
		var cfg := RingMapConfig.sample(rings)
		var band := cfg.extract_band()
		var at := cfg.haven_at()
		var band_x := 0
		var shared := 0
		var stray := 0
		var pos := {}
		var n_pos := {}
		var routes_n := 0
		var search_routes := 0
		var search_shared := 0
		for s in SEEDS:
			var g := RingMapGenerator.new().generate(cfg, s)
			if g == null:
				continue
			var routes_of := {}
			for route in g.routes:
				for id in (route["node_ids"] as Array):
					routes_of[int(id)] = int(routes_of.get(int(id), 0)) + 1
			var pivot := {}
			for link in (g.layout_meta.get("pivot_links", []) as Array):
				pivot[int(link[0])] = true
				pivot[int(link[1])] = true
			for arc in (g.layout_meta.get("pivot_arcs", []) as Array):
				for id in (arc["node_ids"] as Array):
					pivot[int(id)] = true
			for id in g.node_ids():
				if g.get_node(id).type != &"extract":
					continue
				var r := _ring_of(g, id)
				if band.has(r):
					band_x += 1
					if int(routes_of.get(id, 0)) >= 2 or pivot.has(id):
						shared += 1
				else:
					stray += 1
			for route in g.routes:
				var ids: Array = route["node_ids"]
				var inner: Array = ids.slice(1, ids.size() - 1)
				routes_n += 1
				if String(route["ends_at"]) == "extract":
					search_routes += 1
					if pivot.has(int(ids[-1])):
						search_shared += 1
				for ty in at:
					# 搜索路线的商店挪到了撤离点之后的换乘区（报告 053），不在路线上、也不按步数算位置
					var tail: Array = route.get("exit_ids", [])
					if ty == "shop" and not tail.is_empty() and g.get_node(int(tail[0])).type == &"shop":
						n_pos[ty + "_exit"] = int(n_pos.get(ty + "_exit", 0)) + 1
						continue
					for k in inner.size():
						if g.get_node(int(inner[k])).type == StringName(ty):
							pos[ty] = float(pos.get(ty, 0.0)) + float(k) / float(maxi(1, inner.size() - 1))
							n_pos[ty] = int(n_pos.get(ty, 0)) + 1
							break
		t.check(band_x >= SEEDS, "%d 环：撤离环间 %s 里每张图至少一个撤离点（共 %d）" % [rings, str(band), band_x])
		t.eq(stray, 0, "%d 环：撤离环间之外没有撤离点" % rings)
		t.eq(search_shared, search_routes, "%d 环：搜索路线的尽头都在换乘弧上、和相邻路线共用（%d / %d）" % [rings, search_shared, search_routes])
		t.check(int(n_pos.get("shop_exit", 0)) >= search_routes * 0.6,
			"%d 环：多数搜索路线的商店在撤离点之后（%d / %d）" % [rings, int(n_pos.get("shop_exit", 0)), search_routes])
		t.check(float(shared) >= float(band_x) * 0.3,
			"%d 环：撤离环间的撤离点多数落在两条路线共用的地方（%d / %d，尽力而为）" % [rings, shared, band_x])
		for ty in at:
			var avg := float(pos.get(ty, 0.0)) / float(maxi(1, int(n_pos.get(ty, 0))))
			var got := int(n_pos.get(ty, 0)) + int(n_pos.get(ty + "_exit", 0))
			t.check(got >= routes_n * 0.9,
				"%d 环：%d/%d 条路线上（或出口之后）有 %s" % [rings, got, routes_n, ty])
			t.check(absf(avg - float(at[ty])) <= 0.2,
				"%d 环：%s 平均在路线 %.2f 处，目标 %.2f（按步数，不看环）" % [rings, ty, avg, float(at[ty])])


static func _free_mode_cfg(scale: StringName, rings: int) -> RingMapConfig:
	var ch: ChapterDef = RunSave.load_chapter(&"free_mode")
	var cfg: RingMapConfig = (ch.map_source.generator_config as RingMapConfig).duplicate(true)
	cfg.apply_scale(scale, rings)
	return cfg


## 259（作者 13:11 选 A）：魔法废墟的图 —— 规矩照查（配额、禁止相邻里的休息—休息、高危区最少几个从配置读）；
## 路线外的点跟最近路线走：战斗路线旁一步 战斗+精英 ≥ 搜索+宝箱，搜索路线旁 搜索 ≥ 战斗（趋势，48 种子累计）
static func run_free_mode_side_259(t: TestCase) -> void:
	t.begin("259 · 魔法废墟：路旁的点跟路线走、休息不挨休息、规矩照配置")
	var fixed := _free_mode_cfg(&"small", 5)
	t.check(MapNodeTypes.pair_forbidden(fixed.no_adjacent, &"rest", &"rest"), "配置里禁止休息挨休息")
	for pair in [[&"small", 5], [&"medium", 6]]:
		var cfg := _free_mode_cfg(pair[0], pair[1])
		var tag := "%s %d 环" % [pair[0], pair[1]]
		var bad: Array[String] = []
		var side := {}
		var near := 0
		for s in SEEDS:
			var g := RingMapGenerator.new().generate(cfg, s)
			if g == null:
				bad.append("种子 %d 没生成出来" % s)
				continue
			var why := _check_rules(g, cfg)
			if why != "":
				bad.append("种子 %d：%s" % [s, why])
			for e in g.edges:
				if MapNodeTypes.pair_forbidden(cfg.no_adjacent, g.get_node(e.from_id).type, g.get_node(e.to_id).type):
					bad.append("种子 %d：%s—%s 相邻" % [s, g.get_node(e.from_id).type, g.get_node(e.to_id).type])
			var on := {}
			for r in g.routes:
				for id in (r["node_ids"] as Array):
					on[int(id)] = true
			for id in g.node_ids():
				if g.get_node(id).layout.has("near_style"):
					near += 1
					if on.has(id):
						bad.append("种子 %d：路线上的点 %d 记了 near_style" % [s, id])
			for r in g.routes:
				var st := String(r["style"])
				if not side.has(st):
					side[st] = {}
				var seen := {}
				for id in (r["node_ids"] as Array):
					for nb in g.neighbors(int(id)):
						if on.has(nb) or seen.has(nb):
							continue
						seen[nb] = true
						var ty := String(g.get_node(nb).type)
						side[st][ty] = int(side[st].get(ty, 0)) + 1
		t.check(bad.is_empty(), "%s：规矩全成立。不成立的：\n    %s" % [tag, "\n    ".join(bad.slice(0, 6))])
		t.check(near > 0, "%s：路线外的点记下了最近路线的风格（%d 个）" % [tag, near])
		var c: Dictionary = side.get("combat", {})
		var fights := int(c.get("battle", 0)) + int(c.get("elite", 0))
		var loot := int(c.get("search", 0)) + int(c.get("chest", 0))
		t.check(fights >= loot, "%s：战斗路线旁一步 战斗+精英 %d ≥ 搜索+宝箱 %d" % [tag, fights, loot])
		var sr: Dictionary = side.get("search", {})
		t.check(int(sr.get("search", 0)) >= int(sr.get("battle", 0)), "%s：搜索路线旁一步 搜索 %d ≥ 战斗 %d" % [tag, int(sr.get("search", 0)), int(sr.get("battle", 0))])


## 259：环权重与 mix 对半 —— mix 按环权重总量归一
static func run_blend_mix_259(t: TestCase) -> void:
	t.begin("259 · 路旁权重：环权重与路线 mix 各占一半")
	var out := RingTypeAssigner._blend_mix({"battle": 4.0, "search": 2.0, "event": 2.0}, {"battle": 5.0, "elite": 1.0, "event": 2.0})
	t.eq(out, {"battle": 2.0 + 2.5, "search": 1.0, "event": 1.0 + 1.0, "elite": 0.5}, "4/2/2 ⊕ 5/1/2 → 4.5 / 1 / 2 / 0.5")
	var total := 0.0
	for k in out:
		total += float(out[k])
	t.eq(total, 8.0, "总量还是环权重的 8")
