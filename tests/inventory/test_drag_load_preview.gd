## 用真实拖拽比较预告与松手后的重量。行囊、战利品与搜索共用同一个 InventoryPanel。
extends RefCounted

const D := preload("res://tests/inventory/test_drag_layer.gd")
const StripSuite := preload("res://tests/ui/test_stats_strip_216.gd")
const BagPanel := preload("res://ui/game/inventory_panel.gd")


static func run_weighted_bags(t: TestCase) -> void:
	t.begin("拖拽负重 · 目标包的减重、角色标签折扣、顶替与取消")
	var board := GridInventory.new(Vector2i(4, 2), 1, true)
	var box := GridInventory.new(Vector2i(4, 2), 2)
	var light := D._bag_def("light", ["11", "11"])
	light.bag_weight_mult = 0.5
	var bag := ItemInstance.create(light)
	board.place(bag, Vector2i.ZERO)
	board.place(ItemInstance.create(D._bag_def("plain", ["11", "11"])), Vector2i(2, 0))
	var heavy := D._def("heavy", ["1"], ["weapon"])
	heavy.weight = 11
	var a := ItemInstance.create(heavy)
	var victim := ItemInstance.create(D._def("dot", ["1"]))
	box.place(a, Vector2i.ZERO)
	board.place(victim, Vector2i(1, 0))
	var v := D._view(board, Vector2.ZERO)
	var src := D._view(box, Vector2(500, 0))
	var drag := DragLayer.new()
	drag.register_view(v)
	drag.register_view(src)
	drag.stash = ItemStash.new(3, 0)
	var rules := [{"tags": ["weapon"], "percent": -25}]
	src.grab_requested.emit(src, a.uid, D._grab(Vector2i.ZERO))
	var spot := D._center(v, Vector2i(1, 0))
	drag.update_preview(spot)
	var expected := drag.projected_weight(board, rules, spot)
	t.eq(expected, 5, "11 先按包折为 6，再按标签折为 4.5，换下 1 重的旧物")
	t.check(board.has_item(victim.uid) and a.container_id == 0, "预测不动旧物与手上物")
	t.check(drag.drop_at(spot), "顶替成功")
	t.eq(ItemWeight.total_scaled(board, rules), expected, "实际盘重等于预告")
	t.check(drag.is_dragging(), "顶掉的一件接手")
	drag.cancel()
	t.eq(board.item_count(), 4, "取消后被顶者进入其他可用格")
	v.grab_requested.emit(v, a.uid, D._grab(a.origin))
	spot = D._center(v, Vector2i(2, 1))
	drag.update_preview(spot)
	expected = drag.projected_weight(board, rules, spot)
	t.eq(expected, 9, "同盘移动到普通包也按真实落点重新计重")
	drag.cancel()
	t.eq(ItemWeight.total_scaled(board, rules), 6, "取消返回减重包且保留旧物")
	v.grab_requested.emit(v, bag.uid, D._grab(Vector2i.ZERO))
	spot = D._center(v, Vector2i.ZERO)
	drag.update_preview(spot)
	t.eq(drag.projected_weight(board, rules, spot), 6, "装满的包整体试摆保留内容物折扣")
	drag.cancel()
	v.free()
	src.free()
	drag.free()


static func frame_integration(t: TestCase, root: Window) -> void:
	t.begin("拖拽负重 · 行囊实际接线，跨档、移回、取消、丢到地上、禁用落点")
	var f := StripSuite._flow("drag-load-panel")
	var run := f.run
	run.character = CharacterDef.new()
	run.character.weight_capacity = 10
	run.encumbrance = EncumbranceRules.standard()
	run.board = GridInventory.new(Vector2i(4, 2), 1)
	var heavy := D._def("test_load_heavy", ["1"])
	heavy.weight = 16
	var inst := ItemInstance.create(heavy)
	run.board.place(inst, Vector2i.ZERO)
	var panel := BagPanel.new()
	root.add_child(panel)
	panel.setup(run, null)
	var view: InventoryView = panel.board_view
	view.size = Vector2(run.board.size) * view.cell_px
	var drag: DragLayer = panel.drag_layer()
	var outside := Vector2(-500, -500)
	var initial: Array = panel.strip.texts(StatsStrip.LOAD).duplicate()
	view.grab_requested.emit(view, inst.uid, D._grab(Vector2i.ZERO))
	t.eq(panel.strip.texts(StatsStrip.LOAD), initial, "拿起瞬间保留原重与档位")
	drag.update_preview(outside)
	t.check(panel.strip.texts(StatsStrip.LOAD)[1].begins_with("→ 0"), "悬停地面预告 0 重")
	drag.update_preview(view.global_position + D._grab(Vector2i(1, 0)))
	t.eq(panel.strip.texts(StatsStrip.LOAD), initial, "回到盘内移动时清除过档预告")
	drag.update_preview(outside)
	drag.cancel()
	t.eq(panel.strip.texts(StatsStrip.LOAD), initial, "取消后恢复实际盘重")
	view.grab_requested.emit(view, inst.uid, D._grab(Vector2i.ZERO))
	drag.drop_filter = func(_i: ItemInstance, _dest: ItemContainer) -> bool: return false
	drag.update_preview(outside)
	t.eq(panel.strip.texts(StatsStrip.LOAD), initial, "被禁止的落点不报预测")
	drag.drop_filter = Callable()
	drag.update_preview(outside)
	t.check(drag.drop_at(outside), "松手落地")
	t.check(not panel.strip.texts(StatsStrip.LOAD)[1].begins_with("→") and run.carry_weight() == 0, "落子后用新盘重，清预告")
	panel.free()
	StripSuite.Support.cleanup("drag-load-panel")


static func frame_search_and_loot(t: TestCase, root: Window) -> void:
	t.begin("搜索与战利品 · 真实容器已揭物品跨档、负重详情焦点往返")
	var f := StripSuite._flow("drag-load-search")
	var run := f.run
	run.character = CharacterDef.new()
	run.character.weight_capacity = 10
	run.encumbrance = EncumbranceRules.standard()
	run.board = GridInventory.new(Vector2i(4, 2), 1)
	for searching in [false, true]:
		var box := GridInventory.new(Vector2i(4, 2), 2)
		var session := SearchSession.new(run.current_node(), run.node_rules.search, run.items, RandomNumberGenerator.new())
		if searching:
			box = session.haul_box
		var def := D._def("test_acquired_ore", ["1"])
		def.weight = 16
		var ore := ItemInstance.create(def)
		box.place(ore, Vector2i.ZERO)
		# 掉落容器还有一件，让拿走被测试物品后仍能检查同一张签。
		box.place(ItemInstance.create(D._def("other", ["1"])), Vector2i(1, 0))
		var scr := StripSuite.CS.new()
		scr.flow = f
		scr.font = UiPalette.cjk_font()
		scr.screen = GameFlow.Screen.SEARCH if searching else GameFlow.Screen.LOOT
		root.add_child(scr)
		scr.open({"session": session} if searching else {"container": box})
		var tag := scr._strip.load_tag()
		t.check(scr._take_btn.get_node(scr._take_btn.focus_neighbor_bottom) == tag and tag.get_node(tag.focus_next) == scr._take_btn, "焦点往返真实控件")
		scr._loot.grab_requested.emit(scr._loot, ore.uid, D._grab(Vector2i.ZERO))
		var dest := scr._inv.board_view.global_position + D._grab(Vector2i.ZERO)
		scr._drag.update_preview(dest)
		t.check(not scr._strip.texts(StatsStrip.LOAD)[1].begins_with("→"), "未探明的物品不透露重量")
		scr._drag.cancel()
		scr._loot.reveal_all()
		scr._loot.grab_requested.emit(scr._loot, ore.uid, D._grab(Vector2i.ZERO))
		scr._drag.update_preview(dest)
		t.check(scr._strip.texts(StatsStrip.LOAD)[1].begins_with("→ 16"), "探明后悬停才预告真实重量")
		t.check(scr._drag.drop_at(dest) and run.carry_weight() == 16, "取得物资的实际负重等于预测")
		t.check(not scr._strip.texts(StatsStrip.LOAD)[1].begins_with("→"), "完成后清除搜索或战利品预测")
		scr.free()
		run.board.remove(ore.uid)
	StripSuite.Support.cleanup("drag-load-search")
