## 278（作者 2026-11-04 选 A）：高危区画成一片地 —— 分组、三角取舍、区块形状、按版本 / 缩放缓存
extends RefCounted


static func _graph(dangers: Array, links: Array) -> MapGraph:
	var g := MapGraph.new()
	for i in dangers.size():
		var n := MapNode.new()
		n.id = i
		n.type = &"battle"
		n.danger = int(dangers[i])
		g.add_node(n)
	for l in links:
		g.connect_nodes(int(l[0]), int(l[1]))
	return g


static func run_groups(t: TestCase) -> void:
	t.begin("278 · 分组：有 zones 按 zones（都算高危）；没有就按 danger 同级相连；隔开的两片不连，中危高危不混")
	# 0-1-2 高危相连，3 普通隔开，4-5 高危另一片，6 中危挨着 5
	var g := _graph([2, 2, 2, 0, 2, 2, 1], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6]])
	var gs := DangerZones.groups(g)
	t.eq(gs.size(), 3, "三片：%s" % str(gs))
	if gs.size() == 3:
		t.eq(gs[0]["ids"], [0, 1, 2] as Array[int], "第一片 0-1-2")
		t.eq(gs[1]["ids"], [4, 5] as Array[int], "被普通点隔开的 4-5 另成一片")
		t.eq([gs[2]["ids"], gs[2]["level"]], [[6] as Array[int], 1], "中危自成一片（level 1），不并进挨着的高危")
	g.zones = {7: {"node_ids": [3, 4]}, 2: {"node_ids": [0]}}
	gs = DangerZones.groups(g)
	t.eq(gs.size(), 2, "有 zones：按 zones 分")
	if gs.size() == 2:
		t.eq([gs[0]["ids"], gs[0]["level"]], [[0] as Array[int], 2], "按 zone id 排，都是 2 级")
		t.eq(gs[1]["ids"], [3, 4] as Array[int], "zone 7")


static func run_triangles(t: TestCase) -> void:
	t.begin("278 · 三角：区外点在里面的不填；最长边超了不填；留下的都是逆时针")
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(50, 80)])
	var ok := DangerZones.triangles(pts, PackedVector2Array(), 200.0)
	t.eq(ok.size(), 1, "三个点、没有区外点：一个三角")
	if ok.size() == 1:
		t.check(not Geometry2D.is_polygon_clockwise(ok[0]), "逆时针（并多边形时当外缘）")
	t.eq(DangerZones.triangles(pts, PackedVector2Array([Vector2(50, 30)]), 200.0).size(), 0, "区外点在三角里：不填")
	t.eq(DangerZones.triangles(pts, PackedVector2Array([Vector2(300, 300)]), 200.0).size(), 1, "区外点在外面：照填")
	t.eq(DangerZones.triangles(pts, PackedVector2Array(), 90.0).size(), 0, "最长边 100 > 90：不填")
	t.eq(DangerZones.triangles(PackedVector2Array([Vector2.ZERO, Vector2(10, 0)]), PackedVector2Array(), 200.0).size(), 0, "不到三个点：没有三角")


static func run_shapes(t: TestCase) -> void:
	t.begin("278 · 区块：隔开的两片画成两块；区外点不被盖住；中危一块 level 1；磨圆后抖过的外缘点数够多")
	var g := _graph([2, 2, 0, 2, 2, 1], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5]])
	var screen := {0: Vector2(100, 100), 1: Vector2(200, 100), 2: Vector2(350, 100), 3: Vector2(500, 100), 4: Vector2(600, 100), 5: Vector2(800, 100)}
	var shapes := DangerZones.shapes(g, screen, 16.0)
	t.eq(shapes.size(), 3, "两片高危 + 一片中危 = 三块")
	var levels: Array = []
	for s in shapes:
		levels.append(int(s["level"]))
		var poly: PackedVector2Array = s["poly"]
		t.check(poly.size() >= 12, "外缘点数 %d" % poly.size())
		t.check(not Geometry2D.is_point_in_polygon(screen[2], poly), "普通点 2 不在任何一块里")
		t.check(not (s["inner"] as Array).is_empty(), "内收一圈有东西")
	levels.sort()
	t.eq(levels, [1, 2, 2], "级别")
	var ids: Array = []
	for s in shapes:
		ids.append(s["ids"])
	t.check(ids.has([0, 1] as Array[int]) and ids.has([3, 4] as Array[int]) and ids.has([5] as Array[int]), "每块记着自己盖住的点：%s" % str(ids))
	t.eq(DangerZones.shapes(_graph([0, 0], [[0, 1]]), {0: Vector2.ZERO, 1: Vector2(100, 0)}, 16.0).size(), 0, "没有危险点：没有区块")


static func frame_cache(t: TestCase, root: Window) -> void:
	t.begin("278 · MapView：区块按 graph.version / 缩放缓存，没变就不重算")
	var view := MapView.new()
	root.add_child(view)
	view.size = Vector2(800, 600)
	view.graph = _graph([2, 2], [[0, 1]])
	var pos := {0: Vector2(100, 100), 1: Vector2(220, 100)}
	var rect := Rect2(Vector2.ZERO, view.size)
	var a: Array[Dictionary] = view._zones(pos, rect)
	t.eq(a.size(), 1, "一块")
	t.check(is_same(view._zones(pos, rect), a), "什么都没变：同一份缓存")
	view.zoom = 1.5
	var b: Array[Dictionary] = view._zones(pos, rect)
	t.check(not is_same(b, a), "缩放变了：重算")
	view.graph.version += 1
	t.check(not is_same(view._zones(pos, rect), b), "图的版本变了：重算")
	view.queue_free()


static func run_dedupe(t: TestCase) -> void:
	t.begin("278 补：外缘去掉挨得太近的点（含首尾），三角剖分不再失败")
	var poly := PackedVector2Array([Vector2(0, 0), Vector2(0.01, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100), Vector2(0.02, 0.01)])
	var out := DangerZones.dedupe(poly)
	t.eq(out.size(), 4, "6 点去掉 2 个挨太近的：%s" % str(out))
	t.check(not Geometry2D.triangulate_polygon(out).is_empty(), "剖分得出")


static func frame_fit_free_mode(t: TestCase, root: Window) -> void:
	t.begin("278 补（UI设计 v5.03 核对）：free_mode 种子 7 缩到整张图，每块高危区的外缘都剖分得出（红底画得出来）")
	var ch := load(ContentPaths.asset_file("chapters", "free_mode")) as ChapterDef
	var view := MapView.new()
	root.add_child(view)
	view.size = Vector2(1920, 1200)
	view.graph = ch.map_source.resolve(7)
	view.fit()
	var pos := view.positions()
	var shapes: Array[Dictionary] = view._zones(pos, Rect2(Vector2.ZERO, view.size))
	t.check(not shapes.is_empty(), "有高危区（%d 块）" % shapes.size())
	for s in shapes:
		t.check(not Geometry2D.triangulate_polygon(s["poly"]).is_empty(), "外缘 %d 点剖分得出" % (s["poly"] as PackedVector2Array).size())
	view.queue_free()


static func run_degenerate_fill(t: TestCase) -> void:
	t.begin("278 补（测试 v5.49）：剖不开的一块不填，只画边 —— 免得引擎报 triangulation failed")
	t.check(DangerZones.fillable(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])), "正方形：填")
	t.check(not DangerZones.fillable(PackedVector2Array([Vector2(0, 0), Vector2(10, 10), Vector2(10, 0), Vector2(0, 10)])), "自相交的蝴蝶结：不填")
	t.check(not DangerZones.fillable(PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])), "不到三个点：不填")
