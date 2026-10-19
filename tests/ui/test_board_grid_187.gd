## 187（作者 2026-10-17 16:25）：有了道具图之后棋盘格子默认不画（设置里能打开），像《背包乱斗》。
## 设置三态（没动过 = 跟着道具图走）；关着时不画底 / 格底 / 线 / 外框，拖着东西时格按 50 % 临时出现；设置屏「显示」节有开关
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_setting(t: TestCase) -> void:
	t.begin("187 · 棋盘格线：没动过跟着道具图走（201 起有图 = 不画），玩家定了就照玩家的；存读一致")
	t.eq(ItemPainter.art_available(), FileAccess.file_exists(ItemPainter.ART_MANIFEST), "有没有道具图 = 清单在不在（201）")
	var s := GameSettings.from_dict({"version": GameSettings.SAVE_VERSION})
	t.eq(s.show_grid, GameSettings.GRID_AUTO, "缺省 = 跟默认")
	t.check(s.grid_on(false), "没道具图：默认画")
	t.check(not s.grid_on(true), "有道具图：默认不画（没动过的老玩家一起翻）")
	s.show_grid = 1
	t.check(s.grid_on(true), "玩家打开了：有图也画")
	s.show_grid = 0
	t.check(not s.grid_on(false), "玩家关了：没图也不画")
	t.eq(GameSettings.from_dict(s.to_dict()).show_grid, 0, "存读一致")
	t.eq(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "show_grid": 7}).show_grid, 1, "坏值收进三态")


static func run_draw_and_drag(t: TestCase) -> void:
	t.begin("187 · 关着时格底与线不画；拖着东西时 50 % 临时画出来，松手即隐；开着照旧")
	var c = NodeScreens._content()
	ItemInstance.reset_uid_counter()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	var bag := ItemInstance.create(c.items.get_def(&"bag_leather"), 0)
	board.try_add(bag, true)
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	var off := GameSettings.new()
	off.show_grid = 0
	InventoryView.apply_grid_setting(off)
	t.check(not InventoryView.grid_shown, "关")
	t.eq(view.grid_alpha(), 0.0, "关着：不画格")
	var drag := DragLayer.new()
	drag.register_view(view)
	view.grab_requested.emit(view, bag.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "抓起了包")
	t.check(view.drag_hint, "拖着：视图知道")
	t.eq(view.grid_alpha(), InventoryView.GRID_DRAG_ALPHA, "拖着：格按 50 % 画")
	drag.cancel()
	t.check(not view.drag_hint and view.grid_alpha() == 0.0, "松手：格又收起")
	InventoryView.apply_grid_setting(GameSettings.new())
	var art := ItemPainter.art_available()
	t.check(InventoryView.grid_shown == (not art) and view.grid_alpha() == (0.0 if art else 1.0), "默认跟着道具图走（201 起有图：不画）")
	t.check(view.is_in_group(InventoryView.GROUP), "视图在重画组里（设置一改整组重画）")
	drag.free()
	view.free()


static func frame_settings_toggle(t: TestCase, root: Window) -> void:
	t.begin("187 · 设置屏「显示」节有「棋盘格线」开关：切一下翻转、存盘、棋盘跟着变")
	var c = NodeScreens._content()
	var sf := Support.flow(c, "grid187")
	sf.settings = GameSettings.new()
	var settings = load("res://ui/game/settings_screen.gd").new()
	settings.flow = sf
	settings.font = UiPalette.cjk_font()
	root.add_child(settings)
	settings.open({})
	var btn: Button = null
	for n in settings.find_children("*", "Button", true, false):
		if (n as Button).text.begins_with("棋盘格线"):
			btn = n
	t.not_null(btn, "有开关")
	if btn != null:
		var on0 := not ItemPainter.art_available()     # 201 起有道具图：默认关
		t.eq(btn.text, "棋盘格线：开" if on0 else "棋盘格线：关", "默认跟着道具图走")
		settings.toggle_show_grid()
		t.eq(sf.settings.show_grid, 0 if on0 else 1, "切了一下（玩家定的）")
		t.eq(btn.text, "棋盘格线：关" if on0 else "棋盘格线：开", "按钮跟着写")
		t.eq(InventoryView.grid_shown, not on0, "棋盘跟着变")
		var back := GameSettings.load_from(sf.settings_path)
		t.eq(back.show_grid, 0 if on0 else 1, "存盘读回一致")
		settings.toggle_show_grid()
		t.eq(sf.settings.show_grid, 1 if on0 else 0, "再点：切回来")
		t.eq(InventoryView.grid_shown, on0, "棋盘也切回来")
	settings.queue_free()
	InventoryView.apply_grid_setting(GameSettings.new())
	Support.cleanup("grid187")
