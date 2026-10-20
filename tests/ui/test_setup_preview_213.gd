## 213（作者 2026-10-20：「开局预览在地图列表里切换时会跟着变，就这么做」）：开局第三页的预览认格阵（机关沙漏）——
## 纸按 `safe_area` 对准底图、每层一条虚线、第 0 层画入口可挑出生点、出发走入局转场一层层长出来；同心环的数值不变
extends RefCounted

const Setup := preload("res://tests/ui/test_setup_180.gd")
const B192 := preload("res://tests/ui/test_map_backdrop_192.gd")


## 第三页切到机关沙漏；切不到返回 null
static func _hourglass(setup) -> ChapterDef:
	setup.show_page(2)
	for i in setup._chapters.size():
		if (setup._chapters[i] as ChapterDef).id == &"clockwork_hourglass":
			setup.choose_chapter(i)
			return setup.chapter()
	return null


static func frame_lattice_preview(t: TestCase, root: Window) -> void:
	t.begin("213 · 第三页切到机关沙漏：层数 = 行数、按大型化开；入口 = 图的入口（都在第 0 层、在墨化那片里）；没挑出生点不能出发；每层一段层线")
	var game = Setup._game(root, "setup213a")
	var setup = game.base()
	var c := _hourglass(setup)
	t.not_null(c, "列表里有机关沙漏")
	if c == null:
		game.queue_free()
		return
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var g: MapGraph = setup.preview_graph(c, setup.scale_id)
	t.check(pv.layout is LatticeMapLayout, "按格阵布局")
	t.eq(pv.levels, LatticeMapLayout.rows_of(g), "层数 = 行数（%d）" % pv.levels)
	t.eq(pv.levels, setup.ring_levels(c, setup.scale_id), "ring_levels 对格阵数行")
	t.check(is_equal_approx(pv.radius_frac, MapPreview.RADIUS_BY_SCALE[MapPreview.LATTICE_SCALE]), "按大型化开（0.95）")
	t.check(pv.ring_gap() > 0.0, "有层距")
	t.eq(pv.entry_ids(), g.entry_ids, "入口 = 图的入口（%d 个）" % g.entry_ids.size())
	var rows := LatticeMapLayout.new().level_of(g)
	t.check(g.entry_ids.all(func(id: int) -> bool: return int(rows[id]) == 0), "入口都在第 0 层")
	t.check(g.entry_ids.all(func(id: int) -> bool: return pv.mark_alpha(id) > 0.5), "入口印记都在墨化那片里")
	var far := 0.0
	for id in g.node_ids():
		far = maxf(far, pv.canvas_to_view(LatticeMapLayout.new().positions(g, pv.canvas)[id]).distance_to(pv.center()))
	t.check(far <= pv.target_radius() + 1.0, "整张图都落在化开那片里（最远 %.0f ≤ 半径 %.0f）" % [far, pv.target_radius()])
	t.check(setup.needs_spawn(), "没挑出生点")
	t.check(setup.can_depart() != "", "出发灰着（%s）" % setup.can_depart())
	var lat := pv.layout as LatticeMapLayout
	var straight: Array = g.layout_meta.get("straight_rows", [])
	var drawn := 0
	for r in pv.levels:
		if not straight.has(r) and not lat.row_segment(g, pv.canvas, r).is_empty():
			drawn += 1
	t.check(drawn > 0, "有 %d 条层线" % drawn)
	t.check(pv.line_color().get_luminance() > 0.5, "深底的图：层线用纸色（墨色压在深底上看不见）")
	t.check(not pv._paper_covers(pv.paper_on_screen()), "宽图的纸上下盖不满化开那片：纸外画桌面")
	if LatticeMapLayout.is_horizontal(g) and drawn >= 3:
		var len_of := func(r: int) -> float:
			var seg: Array = lat.row_segment(g, pv.canvas, r)
			return (seg[0] as Vector2).distance_to(seg[1]) if not seg.is_empty() else 0.0
		var mid := pv.levels / 2
		t.check(len_of.call(mid) < len_of.call(0) and len_of.call(mid) < len_of.call(pv.levels - 1), "横置沙漏：中间短、两头长（蝴蝶结）")
	game.queue_free()
	_cleanup("setup213a")


static func frame_lattice_paper_matches_reveal(t: TestCase, root: Window) -> void:
	t.begin("213 · 沙漏的纸：第三页 = 入局第一帧（同一大小、同一位置）；挑了入口才带转场载荷，出发进图、站在挑的入口上、一层层长出来")
	var was := GameDirector.fades_allowed
	GameDirector.fades_allowed = true
	var game = Setup._game(root, "setup213b")
	game.flow.settings.ui_fades = true
	var setup = game.base()
	var c := _hourglass(setup)
	if c == null:
		t.check(false, "列表里没有机关沙漏")
		GameDirector.fades_allowed = was
		game.queue_free()
		return
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	t.check(pv.paper_on_screen().has_area(), "预览有纸（底图对准画布）")
	var zoom_p := pv.ring_gap() / RingLayoutBase.RING_STEP
	var want := MapSkin.paper_rect(pv.skin, pv.canvas)
	t.check(absf(pv.paper_on_screen().size.x - want.size.x * zoom_p * pv.view_zoom) < 0.01, "纸的大小 = 画布里的纸 × 层距 ÷ 环距")
	var ids: Array[int] = pv.entry_ids()
	t.check(not ids.is_empty(), "有入口可挑")
	if ids.is_empty():
		GameDirector.fades_allowed = was
		game.queue_free()
		return
	var pick := ids[ids.size() - 1]
	t.check(setup.pick_spawn(pick), "挑一个入口")
	pv.finish()
	setup.close_hint()
	t.eq(setup.can_depart(), "", "挑了就能出发")
	var payload: Dictionary = setup.reveal_payload()
	t.check(not payload.is_empty() and float(payload.get("ring_gap", 0.0)) > 0.0 and payload.has("spawn_at"), "带转场载荷（层距、出生点）")
	var from: Rect2 = pv.get_global_transform() * pv.paper_on_screen()
	t.check(setup.depart(), "出发")
	var map = game.base()
	var view: MapView = map._view
	t.check(map.revealing(), "在转场")
	var run: RunState = game.flow.run
	t.eq(run.map.entry_ids, [pick] as Array[int], "图上只剩挑的那个入口")
	t.eq(run.phase, RunState.Phase.ON_MAP, "直接在图上（不再进挑出生点）")
	var to: Rect2 = view.get_global_transform() * view.paper_on_screen()
	t.check(B192._near(from, to), "第一帧的纸和预览上的纸重合（%s / %s）" % [from, to])
	# 转场中段：出生那一层先长全，最远那层还没出来
	t.eq(view.level_count(), LatticeMapLayout.rows_of(run.map) - 1, "最远层号 = 行数 − 1")
	t.eq(view.reveal_origin_ring(), 0, "从第 0 层（出生那一列）长起")
	view.node_front = 1.0
	var grow: Dictionary = view._grow_map()
	var rows := LatticeMapLayout.new().level_of(run.map)
	var first_full := true
	var far_hidden := true
	for id in grow:
		if int(rows[id]) == 0 and float(grow[id]) < 1.0:
			first_full = false
		if int(rows[id]) == view.level_count() and float(grow[id]) > 0.0:
			far_hidden = false
	t.check(first_full, "出生那层先长全")
	t.check(far_hidden, "最远那层还没长")
	GameDirector.fades_allowed = was
	game.queue_free()
	_cleanup("setup213b")


static func frame_ring_unchanged(t: TestCase, root: Window) -> void:
	t.begin("213 · 回归：切回魔法废墟，同心环的层数、圈距、纸、入口位置和改之前的式子一样")
	var game = Setup._game(root, "setup213c")
	var setup = game.base()
	_hourglass(setup)
	setup.choose_chapter(0)
	var c: ChapterDef = setup.chapter()
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	t.eq(c.map_skin, &"ruins", "回到魔法废墟")
	t.check(pv.layout is RingLayoutBase, "同心环布局")
	t.eq(pv.levels, setup.ring_levels(c, setup.scale_id), "环数 = 真生成的环数")
	t.check(is_equal_approx(pv.ring_gap(), pv.target_radius() / float(pv.levels)), "圈距 = 化开半径 ÷ 环数")
	t.eq(pv.canvas.size, Vector2.ONE * RingLayoutBase.canvas_side(pv.levels), "画布 = 环数算的方形")
	t.check(pv.line_color().get_luminance() < 0.5, "浅底：圈照旧是墨色")
	t.check(pv._paper_covers(pv.paper_on_screen()), "同心环的纸盖满化开那片（不画桌面）")
	var g: MapGraph = setup.preview_graph(c, setup.scale_id)
	var ring := MapLayout.for_graph(g) as RingLayoutBase
	var area := Rect2(Vector2.ZERO, ring.canvas_size(g))
	var pos := ring.positions(g, area)
	for id in pv.entry_ids():
		var want: Vector2 = pv.center() + ((pos[id] as Vector2) - area.get_center()) / RingLayoutBase.RING_STEP * pv.ring_gap()
		t.check(pv.entry_base(id).distance_to(want) < 0.01, "入口 %d 的位置照旧" % id)
	# 老入口 show_map 还在：按环数画同一张纸
	var paper := pv.paper_on_screen()
	pv.show_map(c.map_skin, pv.levels, setup.scale_id, false)
	t.check(B192._near(pv.paper_on_screen(), paper, 0.01), "show_map 与 show_graph 画同一张纸")
	game.queue_free()
	_cleanup("setup213c")


static func run_layout_levels(t: TestCase) -> void:
	t.begin("213 · 布局的层：同心环 level_of = levels_of、layer_count = 环数；格阵 level_of = row、layer_count = 行数 − 1；row_span 是这一层的最左最右列")
	var g := MapGraph.new()
	g.layout_kind = &"hourglass"
	g.layout_meta = {"rows": 3, "cols": 3, "cells": [[0, 2], [1], [0, 1, 2]], "orientation": "horizontal"}
	var ids: Array[int] = []
	for rc in [[0, 0], [0, 2], [1, 1], [2, 0], [2, 2]]:
		var n := MapNode.new()
		n.id = ids.size() + 1
		n.layout = {"row": rc[0], "col": rc[1]}
		g.add_node(n)
		ids.append(n.id)
	var lat := LatticeMapLayout.new()
	var lv := lat.level_of(g)
	t.eq(int(lv[ids[2]]), 1, "第 1 行的点在第 1 层")
	t.eq(lat.layer_count(g), 2, "三行：最远层号 2")
	t.eq(LatticeMapLayout.row_span(g, 0), [0, 2], "第 0 行 0～2 列")
	t.eq(LatticeMapLayout.row_span(g, 1), [1, 1], "第 1 行只有 1 列")
	t.eq(LatticeMapLayout.row_span(g, 5), [], "没这一行：空")
	t.eq(lat.row_segment(g, Rect2(Vector2.ZERO, lat.canvas_size(g)), 1).size(), 2, "一格的层也有一根（零长）线段")
	t.eq(MapLayout.for_graph(null), null, "没图没布局")


static func _cleanup(prefix: String) -> void:
	Setup.Support.cleanup(prefix)
