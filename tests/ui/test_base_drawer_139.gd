## 139（作者定，三项待定按推荐）：基地屏右侧的开发栏改成箭头抽屉（默认收起，点一下开、再点一下关，盖在页面上）；
## 仓库与图鉴的格子占满整行 —— 格子大小是每块视图自己的（`InventoryView.cell_px`，60 ～ 96），图鉴一行几个按宽度算。
extends RefCounted

const META := "user://test_139_meta.json"
const SETTINGS := "user://test_139_settings.json"
const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")


static func _flow() -> GameFlow:
	var db := ItemDatabase.new()
	db.load_dir()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	return f


static func _screen(f: GameFlow, root: Window) -> Control:
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	return screen


static func _cleanup() -> void:
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func frame_drawer(t: TestCase, root: Window) -> void:
	t.begin("139 · 调试台抽屉：默认收起，箭头点一下开、再点一下关；开发开关与最近几局都在抽屉里；五个页签都能开")
	var f := _flow()
	var screen = _screen(f, root)
	var drawer: DevDrawer = screen.dev_drawer()
	t.not_null(drawer, "有抽屉")
	if drawer == null:
		screen.queue_free()
		_cleanup()
		return
	t.check(not drawer.visible, "默认收起")
	t.eq(drawer.arrow.text, "◂", "收着时箭头朝左")
	t.check(drawer.arrow.is_inside_tree() and not drawer.is_ancestor_of(drawer.arrow), "箭头在头部那一行，不在抽屉里")
	t.check(screen.toggle_dev_drawer(), "点一下：开")
	t.check(drawer.visible, "开着")
	t.eq(drawer.arrow.text, "▸", "开着时箭头朝右")
	t.check(not screen.toggle_dev_drawer(), "再点一下：关")
	t.check(not drawer.visible, "关了")
	drawer.arrow.pressed.emit()
	t.check(drawer.visible, "按箭头按钮本身也开")
	screen.show_tab("codex")
	t.check(drawer.visible, "换页签抽屉不变")
	drawer.arrow.pressed.emit()
	var texts: Array[String] = []
	_collect_text(drawer.content, texts)
	var joined := " ".join(texts)
	t.check(joined.contains("最近几局"), "最近几局在抽屉里")
	if not OS.has_feature("template") and not f.tech_defs.is_empty():
		var tid: StringName = f.tech_defs[0].id
		var spin: SpinBox = screen.tech_level_spin(tid)
		t.not_null(spin, "科技等级的数字框还拿得到（抽屉收着也在树里）")
		t.check(spin != null and drawer.is_ancestor_of(spin), "数字框在抽屉里")
		t.eq(screen.set_tech_level(tid, 1), 1, "抽屉收着也能改级数")
		f.dev_set_tech_level(tid, 0)
	var page: Control = screen._pages["warehouse"]
	t.check(not drawer.is_ancestor_of(page) and not page.is_ancestor_of(drawer), "仓库页不再有右列")
	t.check(drawer.get_index() > page.get_parent().get_parent().get_index(), "抽屉后加：盖在页面上")
	t.eq(drawer.anchor_left, 1.0, "贴右缘")
	t.eq(drawer.offset_right - drawer.offset_left, DevDrawer.WIDTH, "宽 %d" % DevDrawer.WIDTH)
	screen.queue_free()
	_cleanup()


static func _collect_text(n: Node, out: Array[String]) -> void:
	for c in n.get_children():
		if c is Label:
			out.append((c as Label).text)
		elif c is Button:
			out.append((c as Button).text)
		_collect_text(c, out)


static func frame_warehouse_fills_row(t: TestCase, root: Window) -> void:
	t.begin("139 · 仓库格子按宽度放大（60 ～ 96），带回来的背包同一个大小；别的屏格子还是 60")
	t.eq(WarehousePanelScript.cell_for(1600.0, 10), 96.0, "1600 宽、10 列：封顶 96")
	t.eq(WarehousePanelScript.cell_for(800.0, 10), 78.0, "800 宽、10 列：(800 − 14) / 10 取整 = 78")
	t.eq(WarehousePanelScript.cell_for(400.0, 10), InventoryView.CELL, "太窄：不小于 60")
	var f := _flow()
	var screen = _screen(f, root)
	var wh = screen._wh
	t.check(wh.fill_width, "基地屏的仓库面板开着撑满")
	var c: float = wh.fit_to_width(1600.0)
	t.check(c >= 90.0, "1600 宽：一格 ≥ 90（%.0f）" % c)
	var view: InventoryView = wh.warehouse_view()
	t.eq(view.cell_px, c, "仓库视图用这个格子")
	t.eq(view.custom_minimum_size.x, f.meta.warehouse.size.x * c, "视图宽 = 列数 × 格子")
	# 按 cell_px 换算：光标在第 (3, 2) 格的中心
	var mid := (Vector2(3, 2) + Vector2(0.5, 0.5)) * c
	t.eq(view.cell_at_local(mid), Vector2i(3, 2), "像素 → 格按 cell_px 算")
	t.eq(view.cell_origin_px(Vector2i(3, 2)), Vector2(3, 2) * c, "格 → 像素按 cell_px 算")
	t.eq(wh.fit_to_width(500.0), InventoryView.CELL, "窄了缩回 60")
	screen.show_tab("sell")
	screen.fit_sell_to_width(1600.0)
	t.check(screen._sell_view.cell_px >= 90.0, "出售页的仓库也撑满（%.0f）" % screen._sell_view.cell_px)
	screen.queue_free()
	t.eq(InventoryView.new().cell_px, InventoryView.CELL, "新建的格子视图默认 60（地图背包、战前、开局不变）")
	_cleanup()


static func run_drag_on_big_cells(t: TestCase) -> void:
	t.begin("139 · 拖拽按视图自己的格子大小算落点：96 一格的两块视图之间拖，落在光标那一格")
	ItemInstance.reset_uid_counter()
	var d := ItemDef.new()
	d.id = &"t139"
	d.shape = ItemShape.from_ascii(["##"])
	var src := GridInventory.new(Vector2i(6, 4), 1)
	var dst := GridInventory.new(Vector2i(6, 4), 2)
	var a := ItemInstance.create(d, 1)
	src.place(a, Vector2i(0, 0))
	var big := 96.0
	var va := InventoryView.new()
	va.inventory = src
	va.cell_px = big
	va.position = Vector2.ZERO
	var vb := InventoryView.new()
	vb.inventory = dst
	vb.cell_px = big
	vb.position = Vector2(700, 0)
	t.eq(vb.size, Vector2(6, 4) * big, "视图尺寸跟着 cell_px")
	var drag := DragLayer.new()
	drag.register_view(va)
	drag.register_view(vb)
	# 抓第二格（像素在 96 格的 (1, 0) 里）
	va.grab_requested.emit(va, a.uid, Vector2(big * 1.5, big * 0.5))
	t.check(drag.is_dragging(), "抓起来了")
	var at := vb.position + (Vector2(4, 2) + Vector2(0.5, 0.5)) * big
	t.eq(drag.target_origin(vb, at), Vector2i(3, 2), "光标在 (4, 2)、抓的是第二格 → 锚点 (3, 2)")
	t.eq(drag.ghost_cell(at), big, "残影按目标视图的格子画")
	t.eq(drag.ghost_anchor(at), vb.position + Vector2(3, 2) * big, "残影吸附在落点上")
	t.check(drag.drop_at(at), "放下")
	t.eq(dst.get_item(a.uid).origin if dst.get_item(a.uid) != null else Vector2i(-1, -1), Vector2i(3, 2), "落在 (3, 2)")
	var sc := ScrollBox.wrap(InventoryView.new())
	t.eq(sc.custom_minimum_size.x, 8 * InventoryView.CELL + 14.0, "没设格子的视图：滚动框照旧按 60 算")
	var v2 := InventoryView.new()
	v2.inventory = dst
	var sc2 := ScrollBox.wrap(v2, 3)
	v2.cell_px = big
	t.eq(sc2.custom_minimum_size, Vector2(6 * big + 14.0, 3 * big), "格子放大了：滚动框跟着变")
	for n in [va, vb, drag, sc, sc2]:
		(n as Node).free()


static func frame_codex_columns(t: TestCase, root: Window) -> void:
	t.begin("139 · 图鉴一行几个按宽度算：1600 宽 ≥ 14 个，900 宽变少，至少一个")
	var meta_script = load("res://ui/game/meta_screen.gd")
	var wide: int = meta_script.codex_columns_for(1600.0)
	var narrow: int = meta_script.codex_columns_for(900.0)
	t.check(wide >= 14, "1600 宽：%d 个" % wide)
	t.check(narrow < wide and narrow >= 1, "900 宽：%d 个" % narrow)
	t.eq(meta_script.codex_columns_for(10.0), 1, "再窄也有一个")
	t.check(narrow * (CodexTile.SIZE.x + 8) - 8 <= 900.0 - 14.0, "900 宽放得下，不横向滚")
	var f := _flow()
	var screen = _screen(f, root)
	screen.fit_codex_to_width(1600.0)
	t.eq(screen.codex_columns(), wide, "图鉴页的网格跟着宽度")
	screen.fit_codex_to_width(900.0)
	t.eq(screen.codex_columns(), narrow, "窄了列数变少")
	screen.queue_free()
	_cleanup()
