## 地图编辑器（架构文档 5.3.1）：生成 → 手改 → 存成预设。
##
## 编辑器的每个改图动作都是公开方法，这里直接调，不伪造鼠标。
extends RefCounted

const SCENE := "res://ui/map_editor/map_editor.tscn"
const TMP_NAME := "__test_tmp_preset"


static func run_tables_cover_everything(t: TestCase) -> void:
	t.begin("地图界面 · 名单与配色表对得上")

	for type in MapNodeTypes.ALL:
		t.check(MapNodeStyle.STYLES.has(type), "类型 %s 有长相" % type)
	for type in MapNodeStyle.STYLES:
		t.check(MapNodeTypes.has(type), "配色表里的 %s 是名单上的类型" % type)

	# 每个登记过的生成器：给得出默认配置的，生成出来的图得有对应的布局可画
	for id in MapGeneratorRegistry.ids():
		var gen := MapGeneratorRegistry.create(id)
		var cfg := gen.default_config()
		if cfg == null:
			continue
		var g := gen.generate(cfg, 1)
		t.not_null(g, "生成器 %s 用默认配置生成得出来" % id)
		if g != null:
			t.not_null(MapLayout.for_graph(g), "形态 %s 登记了布局" % g.layout_kind)


static func frame_editing(t: TestCase, root: Window) -> void:
	t.begin("地图编辑器 · 生成后手改")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)
	var g: MapGraph = ed.graph()
	t.not_null(g, "开场就生成了一张")
	if g == null:
		ed.queue_free()
		return
	t.check(ed.validation()["blocking"].ok(), "刚生成的图过校验")

	# --- 改类型 ---
	var some: int = g.entry_ids[0]
	ed.set_node_type(some, &"shop")
	t.eq(g.get_node(some).type, &"shop", "类型改得动")
	t.check(ed.has_unsaved_changes(), "改过就是脏的")

	# --- 连 / 断 ---
	var ids := g.node_ids()
	var a: int = ids[1]
	var b := -1
	for id in ids:
		if id != a and g.edge_between(a, id) == null and g.edge_between(id, a) == null:
			b = id
			break
	var before := g.edges.size()
	t.check(ed.toggle_edge(a, b), "没路 → 连上")
	t.eq(g.edges.size(), before + 1, "多了一条路")
	t.check(not ed.toggle_edge(b, a), "有路 → 断开（不分方向）")
	t.eq(g.edges.size(), before, "路数回到原样")

	# --- 在空位上加点 ---
	var slots: Array = MapLayout.for_graph(g).free_slots(g, Rect2(0, 0, 800, 800))
	if slots.is_empty():
		t.check(true, "这张图没有空位，跳过加点")
	else:
		var count := g.node_count()
		var new_id: int = ed.add_node_at(slots[0])
		t.eq(g.node_count(), count + 1, "多了一个点")
		t.eq(ed.selected_id(), new_id, "新点自动选中")
		t.eq(g.get_node(new_id).layout, slots[0]["layout"], "布局载荷来自那个空位")
		t.check(not ed.validation()["blocking"].ok(), "新点还没连路 → 校验说它孤立")
		ed.toggle_edge(new_id, a)
		t.check(ed.validation()["blocking"].ok(), "连上之后校验通过")
		ed.delete_node(new_id)
		t.eq(g.node_count(), count, "删掉之后点数回到原样")
		t.eq(ed.selected_id(), -1, "被删的点不再选中")

	# --- 高危区跟着节点字段走 ---
	ed.set_node_zone(a, 7)
	t.check(g.zones.has(7) and (g.zones[7]["node_ids"] as Array).has(a), "改 zone 字段，graph.zones 同步")
	ed.set_node_zone(a, 0)
	t.check(not g.zones.has(7), "改回 0，那片区就没了")

	# --- 把出生点全孤立：通用校验要拦 ---
	for entry in g.entry_ids.duplicate():
		for e in g.edges_of(entry):
			ed.remove_edge(e)
	t.check(not ed.validation()["blocking"].ok(), "出生点没路了 → 拦下")

	ed.queue_free()


static func frame_scale_panel(t: TestCase, root: Window) -> void:
	t.begin("地图编辑器 · 从规模选起")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)
	ed.use_generator(&"ring")
	var cfg: RingMapConfig = ed.config()
	for p in cfg.scales:
		# 故意要得离谱：换规模时会被夹回这一档的范围
		cfg.entry_count = 99
		cfg.zone_count = 99
		cfg.zone_soft_cap = 99
		ed.choose_scale(p.id, 999)
		t.eq(cfg.ring_count(), p.rings.y, "%s：环数夹到上限" % p.id)
		t.eq(cfg.entry_count, p.entries.y, "%s：出发点夹到上限" % p.id)
		t.eq(cfg.zone_count, p.zones.y, "%s：高危区数量夹到上限" % p.id)
		t.eq(cfg.zone_soft_cap, p.zone_size.y, "%s：高危区规模夹到上限" % p.id)
		t.check(ed.generate(), "%s：按这一档的上限生成得出来" % p.id)
		if ed.graph() != null:
			t.eq(int(ed.graph().layout_meta["ring_count"]), p.rings.y, "%s：图的环数对" % p.id)

	# 不支持规模模板的生成器：面板是空的，choose_scale 什么都不做，也不报错
	ed.use_generator(&"grid_script")
	ed.choose_scale(&"small", 4)
	t.check(ed.generate(), "手绘地图照常生成")
	t.eq(ed.graph().layout_kind, MapGridText.LAYOUT_KIND, "而且是手绘的那张")
	t.check(ed.validation()["blocking"].ok(), "手绘地图在编辑器里过校验")

	ed.queue_free()


static func frame_preset_io(t: TestCase, root: Window) -> void:
	t.begin("地图编辑器 · 存成预设再载入")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)
	t.eq(ed.save_preset("  "), ERR_INVALID_PARAMETER, "空名字存不了")
	t.eq(ed.save_preset("a/b"), ERR_INVALID_PARAMETER, "不能当文件名的也存不了")

	var g: MapGraph = ed.graph()
	ed.set_node_type(g.entry_ids[0], &"rest")
	var saved := JSON.stringify(g.to_dict())
	t.eq(ed.save_preset(TMP_NAME), OK, "存得下")
	t.check(not ed.has_unsaved_changes(), "存完就不脏了")
	t.check(MapPreset.list().has(TMP_NAME), "预设列表里看得到")

	ed.generate_with_new_seed()
	t.check(ed.load_preset(TMP_NAME), "载得回")
	t.eq(JSON.stringify(ed.graph().to_dict()), saved, "载回来的就是存进去的那张")

	# 编辑器存出来的，对局就能直接载入
	var src := MapSource.new()
	src.mode = MapSource.Mode.PRESET
	src.preset_path = MapPreset.path_for(TMP_NAME)
	t.not_null(src.resolve(1), "MapSource 载得进编辑器存的预设")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(MapPreset.path_for(TMP_NAME)))
	ed.queue_free()


static func frame_view_hit_test(t: TestCase, root: Window) -> void:
	t.begin("地图视图 · 点哪儿算哪儿")

	var view := MapView.new()
	view.size = Vector2(800, 800)
	root.add_child(view)
	var g := RingMapGenerator.new().generate(RingMapConfig.sample(4), 2)
	view.graph = g
	view.show_free_slots = true

	var pos := view.positions()
	t.eq(pos.size(), g.node_count(), "每个点都有位置")
	var inside := true
	for id in pos:
		if not Rect2(Vector2.ZERO, view.size).has_point(pos[id]):
			inside = false
	t.check(inside, "全都画在控件之内")

	var hit: Array = []
	view.node_pressed.connect(func(id: int, _b: int, _s: bool): hit.append(id))
	var target: int = g.entry_ids[0]
	view.press(pos[target])
	t.eq(hit, [target], "点在节点上 → 报那个节点")

	var e: MapEdge = g.edges[0]
	var mid: Vector2 = ((pos[e.from_id] as Vector2) + (pos[e.to_id] as Vector2)) / 2.0
	if view.node_at(mid) < 0:
		t.not_null(view.edge_at(mid), "点在路的中点 → 命中一条路")

	view.queue_free()
