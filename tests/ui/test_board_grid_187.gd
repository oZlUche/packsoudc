## 187 → 224 补充三（作者 2026-10-21 15:19：所有棋盘都显示外框和格线）：格线常开，187 的「棋盘格线」设置删了。
## 旧存档里的 show_grid 键照旧读得进来（忽略）；设置屏不再有这一项；仓库按 [constant InventoryView.GROUND_WAREHOUSE] 画棕底浅格线
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_setting_gone(t: TestCase) -> void:
	t.begin("224 · 棋盘格线设置删了：旧存档里的 show_grid 忽略，存盘不再写")
	var s := GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "show_grid": 0, "ui_fades": false})
	t.check(not s.ui_fades, "别的键照读")
	t.check(not s.to_dict().has("show_grid"), "存盘不写 show_grid")
	t.check(not ("show_grid" in s), "设置里没有这一项")
	t.check(not UiText.TEXT.has("settings.grid"), "设置屏的文案也删了")


static func run_draw_and_drag(t: TestCase) -> void:
	t.begin("224 · 棋盘视图格线常开：拖着东西和平时一样；仓库视图按棕底样式画")
	var c = NodeScreens._content()
	ItemInstance.reset_uid_counter()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	var bag := ItemInstance.create(c.items.get_def(&"bag_leather"), 0)
	board.try_add(bag, true)
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	t.check(not ("drag_hint" in view) and not ("grid_shown" in view), "没有开关可关")
	var drag := DragLayer.new()
	drag.register_view(view)
	view.grab_requested.emit(view, bag.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "抓起了包（拖拽不再动格线）")
	drag.cancel()
	t.check(view.is_in_group(InventoryView.GROUP), "视图在重画组里")
	t.check(view.ground.is_empty(), "默认：深底格")
	var wh := Warehouse.new(Vector2i(10, 8))
	var pages := WarehousePages.new()
	pages.setup(wh, UiPalette.cjk_font())
	t.eq(pages.view.ground, InventoryView.GROUND_WAREHOUSE, "仓库：棕底浅格线（224）")
	t.eq(String(InventoryView.GROUND_WAREHOUSE["ground"]), "#543c2a", "棕底照美术")
	pages.free()
	drag.free()
	view.free()


static func frame_settings_no_toggle(t: TestCase, root: Window) -> void:
	t.begin("224 · 设置屏不再有「棋盘格线」开关")
	var c = NodeScreens._content()
	var sf := Support.flow(c, "grid187")
	sf.settings = GameSettings.new()
	var settings = load("res://ui/game/settings_screen.gd").new()
	settings.flow = sf
	settings.font = UiPalette.cjk_font()
	root.add_child(settings)
	settings.open({})
	var found := false
	for n in settings.find_children("*", "Button", true, false):
		if (n as Button).text.begins_with("棋盘格线"):
			found = true
	t.check(not found, "没有开关")
	t.check(not settings.has_method("toggle_show_grid"), "方法也删了")
	settings.queue_free()
	Support.cleanup("grid187")
