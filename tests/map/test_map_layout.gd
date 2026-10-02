## 布局求解（架构文档 5.9，M3-6）。地图沙盒的帧测试随沙盒一起删了（066）：走一步的行为在 test_map_travel / test_run_state 里。
##
## 唯一的硬目标：**异环通路垂直于切线** —— 每条径向边两端角度相等。
## 一个内层点接着多个角度不同的外层点时画不成，那要有告警而不是静默画歪。
extends RefCounted


## 径向边的体检。松弛解的性质：**一条简单的链（每个点至多一上一下，只从一个外层点垂下来）整条垂直**；
## 有分叉的分量（一个点接着两个外层点，或一个点向内分出两条）没法全垂直，
## 那就看总偏差比「按槽位名义角度画」小 —— 求解器至少得比不解强。
static func _radial_report(g: MapGraph, layout: RingLayoutBase) -> Dictionary:
	var angles := layout.angles(g)
	var levels := layout.levels_of(g)
	var fractions := layout.fractions_of(g)
	var top := layout.level_count(g)
	# 径向邻接（不含圆心）
	var nbrs := {}
	var radial: Array[MapEdge] = []
	for e in g.edges:
		var la := int(levels[e.from_id])
		var lb := int(levels[e.to_id])
		if la == lb or la == 0 or lb == 0:
			continue
		radial.append(e)
		for pair in [[e.from_id, e.to_id], [e.to_id, e.from_id]]:
			if not nbrs.has(pair[0]):
				nbrs[pair[0]] = [] as Array[int]
			(nbrs[pair[0]] as Array[int]).append(int(pair[1]))
	# 连通分量
	var comp := {}
	var next_comp := 0
	for id in nbrs:
		if comp.has(id):
			continue
		var stack: Array[int] = [int(id)]
		comp[id] = next_comp
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			for n in (nbrs[cur] as Array[int]):
				if not comp.has(n):
					comp[n] = next_comp
					stack.append(n)
		next_comp += 1
	# 哪些分量是简单的链：每个点至多两条径向边，且只有一个点在最外层
	var simple := {}
	for c in next_comp:
		simple[c] = true
	var tops := {}
	for id in nbrs:
		var c: int = comp[id]
		if (nbrs[id] as Array).size() > 2:
			simple[c] = false
		if int(levels[id]) == top:
			tops[c] = int(tops.get(c, 0)) + 1
	for c in tops:
		if int(tops[c]) > 1:
			simple[c] = false
	# 多亲的点（告警该提到的）
	var multi := 0
	for id in nbrs:
		var outer := 0
		for n in (nbrs[id] as Array[int]):
			if int(levels[n]) > int(levels[id]):
				outer += 1
		if outer > 1:
			multi += 1

	var real: Array[String] = []
	var solved_dev := 0.0
	var naive_dev := 0.0
	for e in radial:
		var d := absf(RingAngleSolver._wrap(float(angles[e.from_id]) - float(angles[e.to_id])))
		var nominal_a := TAU * float(fractions[e.from_id])
		var nominal_b := TAU * float(fractions[e.to_id])
		naive_dev += absf(RingAngleSolver._wrap(nominal_a - nominal_b))
		solved_dev += d
		# 同层的点不许挤到一起，链上的点偶尔要给邻居让一点位置：手绘图越靠里的行越短，
		# 外行上隔两列的两条 | 到了内行可能不足一格，得让开 —— 允许七度以内
		if bool(simple[comp[e.from_id]]) and d > 0.12:
			real.append("%d↔%d 差 %.4f 弧度（简单的链，该垂直）" % [e.from_id, e.to_id, d])
	return {
		"real": real, "multi": multi, "warnings": layout.warnings(g),
		"solved_dev": solved_dev, "naive_dev": naive_dev, "edges": radial.size(),
	}


static func run_radial_edges_vertical(t: TestCase) -> void:
	t.begin("布局求解 · 径向边垂直于切线")

	# 随机生成的图：每个点向内连一两条斜边是本意，求解器只把径向边往竖直方向带 ——
	# 要求「从不比按槽位画更歪」，而且十二个种子平均至少好一成五
	var ratio_sum := 0.0
	var counted := 0
	for s in 12:
		var g := RingMapGenerator.new().generate(RingMapConfig.sample(6), s)
		if g == null:
			continue
		var layout := MapLayout.for_graph(g) as RingLayoutBase
		var rep := _radial_report(g, layout)
		t.check(float(rep["solved_dev"]) <= float(rep["naive_dev"]) + 1e-6,
			"种子 %d：解过之后径向边的总偏差 %.2f，不比按槽位名义角度画的 %.2f 更歪"
			% [s, rep["solved_dev"], rep["naive_dev"]])
		ratio_sum += float(rep["solved_dev"]) / maxf(float(rep["naive_dev"]), 1e-6)
		counted += 1
		if int(rep["multi"]) > 0:
			t.check(not (rep["warnings"] as Array).is_empty(),
				"种子 %d：有 %d 个点接着两个外层点，求解器告了警，不是静默画歪" % [s, rep["multi"]])
	t.check(counted > 0 and ratio_sum / counted <= 0.85,
		"十二个种子平均：解过的偏差是名义的 %.0f%%（要 ≤ 85%%）" % (100.0 * ratio_sum / maxi(1, counted)))

	# 手绘图：作者画的 | 一律竖直（分叉处除外，那也有告警）
	var text := FileAccess.get_file_as_string("res://data/authoring/maps/chapter01_v0.1.txt")
	var grid := MapGridText.parse(text)
	var glayout := MapLayout.for_graph(grid) as RingLayoutBase
	var grep := _radial_report(grid, glayout)
	t.check((grep["real"] as Array).is_empty(), "chapter01_v0.1 里简单的 | 链都竖直（不竖的：%s）"
		% str((grep["real"] as Array).slice(0, 3)))
	t.check(float(grep["solved_dev"]) < float(grep["naive_dev"]),
		"chapter01_v0.1：解过之后 | 的总偏差 %.2f < 按列画的 %.2f" % [grep["solved_dev"], grep["naive_dev"]])


static func run_monotonic_and_deterministic(t: TestCase) -> void:
	t.begin("布局求解 · 每环按次序单调；同一张图解两次逐位相同")

	var g := RingMapGenerator.new().generate(RingMapConfig.sample(5), 3)
	t.not_null(g, "先有一张图")
	if g == null:
		return
	var a := (MapLayout.for_graph(g) as RingLayoutBase).angles(g).duplicate()
	var b := (MapLayout.for_graph(g) as RingLayoutBase).angles(g).duplicate()
	t.eq(a, b, "两个求解器实例解同一张图，逐位相同 —— 没有随机")

	var layout := MapLayout.for_graph(g) as RingLayoutBase
	var levels := layout.levels_of(g)
	var fractions := layout.fractions_of(g)
	var by_level := {}
	for id in g.node_ids():
		var lv := int(levels[id])
		if not by_level.has(lv):
			by_level[lv] = [] as Array[int]
		(by_level[lv] as Array[int]).append(id)
	var warned := layout.warnings(g)
	for lv in by_level:
		if int(lv) == 0:
			continue
		var ids: Array[int] = by_level[lv]
		ids.sort_custom(func(x: int, y: int) -> bool: return float(fractions[x]) < float(fractions[y]))
		var backwards := 0
		for k in ids.size():
			var d := fposmod(float(a[ids[(k + 1) % ids.size()]]) - float(a[ids[k]]), TAU)
			if d > PI:
				backwards += 1
		t.check(backwards == 0 or not warned.is_empty(),
			"第 %d 环按次序单调，或者求解器告了警（折返 %d 处）" % [lv, backwards])

	# 图改了才重解：version 没变不重算，变了要重算
	var v0 := g.version
	var e := g.edges[0]
	g.remove_edge(e)
	t.check(g.version > v0, "改拓扑 version 就变")
	g.add_edge(e)
	t.eq(layout.angles(g).size(), g.node_count(), "改完照样解得出每个点")


static func run_arcs(t: TestCase) -> void:
	t.begin("布局 · 切向边画弧，径向边画直线")

	var g := RingMapGenerator.new().generate(RingMapConfig.sample(4), 1)
	var layout := MapLayout.for_graph(g) as RingLayoutBase
	var rect := Rect2(Vector2.ZERO, layout.canvas_size(g))
	var pos := layout.positions(g, rect)
	var center := rect.get_center()
	var levels := layout.levels_of(g)
	var on_circle := true
	for id in pos:
		var lv := int(levels[id])
		if lv > 0 and absf((pos[id] as Vector2).distance_to(center) - RingLayoutBase.RING_STEP * lv) > 1e-3:
			on_circle = false
	t.check(on_circle, "每个点都在自己那一环的圆上，环距固定 %d 像素" % int(RingLayoutBase.RING_STEP))
	t.eq(layout.canvas_size(g).x, 2.0 * (4 * RingLayoutBase.RING_STEP + RingLayoutBase.MARGIN), "画布按环数算")

	# 弧以画布中心为圆心：弧上每个采样点都在那一环的圆上，两端落在两个点上。
	# 第一版从两端反推圆心、挑离原点近的那个 —— 原点是画布左上角，下半张图的弧全反着凸
	var found := 0
	var off_circle := 0
	for e in g.edges:
		var lv := int(levels[e.from_id])
		if lv != int(levels[e.to_id]) or lv <= 0:
			continue
		found += 1
		var r := RingLayoutBase.RING_STEP * float(lv)
		var pts := RingLayoutBase.arc_points(pos[e.from_id], pos[e.to_id], center, r)
		for p in pts:
			if absf((p as Vector2).distance_to(center) - r) > 1e-3:
				off_circle += 1
		t.check((pts[0] as Vector2).distance_to(pos[e.from_id]) < 1e-3
			and (pts[pts.size() - 1] as Vector2).distance_to(pos[e.to_id]) < 1e-3,
			"弧的两端就是那两个点（%d↔%d）" % [e.from_id, e.to_id])
	t.check(found > 0, "有切向边可试（%d 条）" % found)
	t.eq(off_circle, 0, "弧上没有一个采样点离开那一环的圆 —— 上下左右的弧都朝圆心凹")

