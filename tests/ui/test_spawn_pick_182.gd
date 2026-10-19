## 182（作者 2026-10-17 15:26）：出生点在开局第三页挑定 —— 纸上画这张图的几个入口，点一个才亮「出发」，直接从它开局；
## 点入口微放大、屏幕正中弹提示窗；开局后另几个入口变普通搜索点
extends RefCounted

const Setup := preload("res://tests/ui/test_setup_180.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_demote(t: TestCase) -> void:
	t.begin("182 · 挑定出生点：只留这一个入口，别的入口就地变搜索点（环与位置、边不动），路线只留这一条")
	var c := TestSupport.load_content()
	var ch: ChapterDef = c.chapter1
	t.not_null(ch, "有一章不止一个入口")
	if ch == null:
		return
	var g: MapGraph = ch.map_source.resolve(7, &"")
	var keep := g.entry_ids[1]
	var others := g.entry_ids.filter(func(id: int) -> bool: return id != keep)
	var edges_before := g.edges.size()
	var layout_before: Dictionary = g.get_node(others[0]).layout.duplicate(true)
	t.check(not g.demote_entries(-99), "不是入口：不改")
	t.check(g.demote_entries(keep), "挑定")
	t.eq(g.entry_ids, [keep] as Array[int], "入口只剩挑的那个")
	t.check(others.all(func(id: int) -> bool: return g.get_node(id).type == &"search"), "别的入口变普通搜索点")
	t.eq(g.get_node(keep).type, &"spawn", "挑的那个还是出生点")
	t.eq(g.edges.size(), edges_before, "边不动")
	t.eq(g.get_node(others[0]).layout, layout_before, "环与位置不动")
	t.eq(g.routes.size(), 1, "路线只留一条")
	if g.routes.size() == 1:
		t.eq(int(g.routes[0]["entry_id"]), keep, "就是这个入口的那条，在下标 0")

	# 开局直接站上去：begin(spawn_id) 之后不进挑出生点阶段
	var flow := Support.flow(c, "spawn182")
	var g1: MapGraph = ch.map_source.resolve(11, &"")
	var pick := g1.entry_ids[g1.entry_ids.size() - 1]
	var run := flow.begin(ch, null, 11, [] as Array[int], flow.characters_for(ch)[0] if not flow.characters_for(ch).is_empty() else null, [], null, &"", 0, pick)
	t.not_null(run, "开得了")
	if run != null:
		t.eq(run.phase, RunState.Phase.ON_MAP, "直接在图上")
		t.eq(run.travel.current_id, pick, "站在挑的出生点上")
		t.eq(run.map.entry_ids, [pick] as Array[int], "别的入口已经降成搜索点")
		var back := RunState.from_dict(run.to_dict(), ch, run.items, run.enemies)
		t.not_null(back, "读得回来")
		if back != null:
			t.eq(back.map.entry_ids, [pick] as Array[int], "存档里也是降过的图")
	Support.cleanup("spawn182")


static func frame_pick_on_page_3(t: TestCase, root: Window) -> void:
	t.begin("182 · 第三页：纸上画入口（位置与真图一致），没挑「出发」灰；点一个 → 挑中、微放大、正中弹提示窗；再点同一个关窗；点空白回原样；换图清零")
	var game = Setup._game(root, "setup182")
	var flow: GameFlow = game.flow
	flow.settings.ui_fades = false
	var setup = game.base()
	setup.show_page(2)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var g: MapGraph = setup.preview_graph(setup.chapter(), setup.scale_id)
	t.not_null(g, "第三页按种子生成了这张图")
	if g == null:
		game.queue_free()
		return
	t.eq(pv.entry_ids(), g.entry_ids, "纸上的入口就是这张图的入口（%d 个）" % g.entry_ids.size())
	t.check(g.entry_ids.size() >= 2, "不止一个入口可挑")
	var outer := pv.ring_gap() * float(pv.levels)
	t.check(pv.entry_ids().all(func(id: int) -> bool: return absf(pv.entry_base(id).distance_to(pv.center()) - outer) < 1.0), "入口都落在最外一圈上")
	var lay := MapLayout.for_graph(g) as RingLayoutBase
	var canvas := Rect2(Vector2.ZERO, lay.canvas_size(g))
	var pos := lay.positions(g, canvas)
	var a: int = g.entry_ids[0]
	var b: int = g.entry_ids[1]
	var real_dir := ((pos[a] as Vector2) - canvas.get_center()).normalized()
	t.check(real_dir.dot((pv.entry_base(a) - pv.center()).normalized()) > 0.999, "方位和真图一致")
	t.eq(setup.spawn_id, -1, "进页没挑")
	t.check(setup.needs_spawn() and setup.can_depart() != "", "没挑：出发不了（%s）" % setup.can_depart())
	t.check(setup._enter_btn.disabled, "「出发」灰着")
	t.check(not setup.depart(), "硬出发也被拒")

	# 点印记（走真的输入）
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = pv.entry_point(a)
	pv._gui_input(click)
	t.eq(setup.spawn_id, a, "点印记 = 挑中")
	t.eq(pv.selected, a, "印记换选中态")
	t.check(not setup._enter_btn.disabled and setup.can_depart() == "", "「出发」亮了")
	t.check(is_equal_approx(pv.view_zoom, MapPreview.ZOOM_IN), "微放大 ×%.2f" % pv.view_zoom)
	t.check(pv.view_shift.distance_to((pv.entry_base(a) - pv.center()) * MapPreview.ZOOM_SHIFT) < 0.5, "视中心往它挪四成")
	var hint: NodeHintCard = setup.hint_card()
	t.check(hint.is_open() and hint.visible and hint.node_id == a, "正中弹提示窗")
	t.eq(hint.type, &"spawn", "说的是出生点")
	var texts := Setup._texts(hint)
	var style := ""
	for r in g.routes:
		if int(r.get("entry_id", -1)) == a:
			style = String(r.get("style", ""))
	var rt := RouteStyle.player_text(StringName(style))
	t.check(not rt.is_empty(), "这条路线有给玩家的名字（%s）" % style)
	t.check(texts.has("出生点·" + String(rt.get("name", ""))) and texts.any(func(s: String) -> bool: return s.contains(String(MapNodeTypes.HINTS[&"spawn"]))), "作者 10-19：标题「出生点·路线名」与一句说明")
	t.check(texts.has(String(rt.get("text", ""))), "路线特点那一句")
	t.check(not hint._glyph.visible, "标题不画「生」字")
	t.check(texts.has("点别处可以换一个"), "底下的小字")
	t.check(not texts.any(func(s: String) -> bool: return s.contains("风险")), "路线风险 / 收益跟着地图屏一起藏着")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_NODE_HINT), UiTheme.TONE_LIGHT, "浅底纸签")
	var mid: Vector2 = Vector2(game.get_viewport().get_visible_rect().size) * 0.5
	t.check(hint.get_global_rect().get_center().distance_to(mid) < 2.0, "在屏幕正中")

	click.position = pv.entry_point(a)     # 放大后印记挪了位置
	pv._gui_input(click)
	t.check(not hint.is_open(), "再点同一个：关窗")
	t.eq(setup.spawn_id, a, "挑的留着")
	t.check(is_equal_approx(pv.view_zoom, MapPreview.ZOOM_IN), "不再放大")

	setup.pick_spawn(b)
	t.eq(setup.spawn_id, b, "点另一个：换过去")
	t.check(pv.view_shift.distance_to((pv.entry_base(b) - pv.center()) * MapPreview.ZOOM_SHIFT) < 0.5, "平移到它")
	t.check(hint.is_open() and hint.node_id == b, "窗跟着换")

	var away := InputEventMouseButton.new()
	away.button_index = MOUSE_BUTTON_LEFT
	away.pressed = true
	away.global_position = pv.get_global_rect().end + Vector2(10, 10)     # 预览外、窗外
	if hint.get_global_rect().has_point(away.global_position):
		away.global_position = Vector2(pv.get_global_rect().end.x + 10, 4)
	setup._input(away)
	t.check(not hint.is_open(), "点窗外别处：关窗")

	click.position = pv.center() + Vector2(3, 3)
	pv._gui_input(click)
	t.eq(pv.view_zoom, 1.0, "点预览空白：回到不放大")
	t.eq(setup.spawn_id, b, "选择保留")

	setup.choose_difficulty(0)
	t.eq(setup.spawn_id, b, "换难度不动种子、不清选择")
	var other := -1
	for i in setup._chapters.size():
		if setup._chapters[i] != setup.chapter():
			other = i
	if other >= 0:
		setup.choose_chapter(other)
		t.eq(setup.spawn_id, -1, "换图：清零")
		t.check(setup._enter_btn.disabled or setup.preview().entries.is_empty(), "「出发」重新灰")
	setup.set_run_seed(setup.run_seed + 1)
	t.eq(setup.spawn_id, -1, "换种子：清零")

	# 出发：从挑的出生点开局，另几个入口降为搜索点
	var ids: Array[int] = setup.preview().entry_ids()
	if not ids.is_empty():
		var pick: int = ids[ids.size() - 1]
		setup.pick_spawn(pick)
		t.check(setup.depart(), "出发")
		t.eq(flow.run.phase, RunState.Phase.ON_MAP, "新局不进挑出生点阶段")
		t.eq(flow.run.travel.current_id, pick, "站在挑的出生点上")
		t.check(ids.all(func(id: int) -> bool: return id == pick or flow.run.map.get_node(id).type == &"search"), "另几个入口变成搜索点")
	game.queue_free()
	Support.cleanup("setup182")
