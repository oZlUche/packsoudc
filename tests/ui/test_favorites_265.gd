## 265（作者 2026-10-29 16:43；丝带定稿 17:20）：道具收藏 —— 按种类存局外、存读往返；悬浮窗右上角丝带就是按钮（点一下切、按钮排里没有「收藏」）；
## 收藏了的道具右上角一枚星（和随身之物小钉同角时往左让）；铁匠铺材料格也有种类窗；一键出售 / 出售同类跳过收藏；仓库「只看收藏」、图鉴「收藏」档
extends RefCounted

const Records := preload("res://tests/ui/test_records_board_260.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_save_round_trip(t: TestCase) -> void:
	t.begin("265 · 收藏按种类存局外：切两下回原样、存读往返、退役的 id 读档丢掉；没挂局外状态时谁都不是收藏")
	var db := _db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	t.check(not ItemFavorites.available() and not ItemFavorites.has(&"longsword"), "没挂：没有收藏")
	ItemFavorites.attach(m)
	t.check(ItemFavorites.toggle(&"longsword"), "收藏长剑")
	t.check(m.is_favorite(&"longsword") and ItemFavorites.has(&"longsword"), "局外记着")
	t.check(not ItemFavorites.toggle(&"longsword"), "再切：取消")
	ItemFavorites.toggle(&"longsword")
	var d := m.to_dict()
	(d["favorites"] as Array).append("no_such_item_265")
	var back := MetaState.from_dict(d, db)
	t.eq(back.favorites, [&"longsword"] as Array[StringName], "存读往返；没了的 id 丢掉")
	d.erase("favorites")
	t.eq(MetaState.from_dict(d, db).favorites, [] as Array[StringName], "老档没这项：空")
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), back)
	t.check(ItemFavorites.source() == back, "GameFlow 换局外时挂上")
	f.meta = MetaState.new()
	t.check(not ItemFavorites.has(&"longsword"), "换了一份局外：跟着换")
	ItemFavorites.attach(null)


static func run_sell_skips_favorites(t: TestCase) -> void:
	t.begin("265 §2.5 · 一键出售跳过收藏、预览数对；出售同类对收藏的种类灰着；单件照卖")
	var db := _db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	ItemFavorites.attach(m)
	var swords: Array = []
	for i in 2:
		var s := ItemInstance.create(db.get_def(&"longsword"), m.allocate_uid())
		m.warehouse.try_add(s, true)
		swords.append(s)
	var plank := ItemInstance.create(db.get_def(&"hardwood_plank"), m.allocate_uid())
	m.warehouse.try_add(plank, true)
	m.toggle_favorite(&"longsword")
	t.eq(int(m.sell_preview(-1)["count"]), 1, "预览只卖木板")
	t.eq(m.favorite_matching(-1), 2, "跳过收藏 2 件")
	var same := ItemActions.sell_same(swords[0], m.warehouse, func(i): return 1, func(uid): m.sell_item(uid))
	t.check(not same.enabled and same.reason == UiText.t("act.fav_no_bulk"), "出售同类：灰着，写收藏的不成批出售")
	t.eq(same.label, "出售同类 · 已收藏", "按钮上直接写原因（复测 v4.75：原来写「×0 得 0 币」）")
	UiText.lang = "en"
	t.eq(UiText.tn("meta.sell_skip_fav", 1) % 1, " (keeps 1 favorite)", "英文一件用单数")
	t.eq(UiText.tn("meta.sell_skip_fav", 2) % 2, " (keeps 2 favorites)", "两件用复数")
	UiText.lang = "zh"
	var one := ItemActions.sell(swords[0], 1, func(uid): m.sell_item(uid))
	t.check(one.enabled, "单件出售照常")
	var got := m.sell_where(-1)
	t.eq(int(got["count"]), 1, "一键出售卖了一件")
	t.check(m.warehouse.has_item(swords[0].uid) and m.warehouse.has_item(swords[1].uid), "两把长剑都留着")
	ItemFavorites.attach(null)


static func frame_tip_ribbon(t: TestCase, root: Window) -> void:
	t.begin("265 · 悬浮窗右上角丝带：没收藏短而暗、点一下拉下来变亮带星、按钮排里没有「收藏」；名字行让出 48；角标画在右上，和小钉同角时往左让；钉子不画了")
	var db := _db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var sword := ItemInstance.create(db.get_def(&"longsword"))
	board.place(sword, Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.auto_tooltip = false
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	view.item_context.emit(view, sword.uid)
	t.eq(tip.fav_state(), -1, "没挂局外状态：不画丝带")
	tip.hide_tip()
	ItemFavorites.attach(m)
	view.actions_for = func(uid: int) -> Array:
		var inst := board.get_item(uid)
		return [ItemActions.lock(inst, board), ItemActions.sell_same(inst, board, func(i): return 1, func(_u): pass)]
	view.item_context.emit(view, sword.uid)
	var w: HoverTip.TipWindow = tip._panel
	t.eq(tip.fav_state(), 0, "没收藏")
	t.check(w.fav_len == HoverTip.FAV_LEN_OFF and w.fav_dim == 1.0 and w.fav_star_k == 0.0, "丝带收着 15、压暗、没星")
	t.eq(w.head.custom_minimum_size.x, w.full_width - HoverTip.FAV_MARGIN, "名字行右边让 48")
	t.eq(tip.action_rows(), [["lock", "sell_same"]], "按钮排里没有「收藏」")
	t.check(tip.action_buttons()[1].action.enabled, "没收藏：出售同类亮着")
	var hit := w.fav_rect()
	t.check(hit.size.x == 44.0 and hit.size.y >= 24.0 and is_equal_approx(hit.position.x, w.size.x - 58.0), "点击区 44 宽、至少 24 高、在铜杆下（%s）" % hit)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = hit.get_center()
	w._gui_input(click)
	t.check(m.is_favorite(&"longsword"), "点丝带：收藏了")
	t.eq(tip.fav_state(), 1, "丝带亮")
	w._fav_snap()     # 动画走完
	t.check(w.fav_len == HoverTip.FAV_LEN_ON and w.fav_dim == 0.0 and w.fav_star_k == 1.0, "放下 46、原色、带星")
	t.check(tip.is_pinned() and tip.is_showing(), "窗还钉着")
	t.check(not tip.action_buttons()[1].action.enabled, "收藏了：出售同类当场灰掉")
	var r := ItemPainter.favorite_rect(sword.def, 0, Vector2.ZERO, InventoryView.CELL)
	t.check(r.size == Vector2.ONE * ItemPainter.LOCK_SIDE and r.end.x <= float(sword.def.shape.size_rotated(0).x) * InventoryView.CELL, "星在右上那格里（%s）" % r)
	sword.set_locked(true)
	t.check(not r.intersects(ItemPainter.lock_rect(sword, 0, Vector2.ZERO, InventoryView.CELL)), "锁（左上）+ 星（右上）不重叠")
	var beside := ItemPainter.favorite_rect(sword.def, 0, Vector2.ZERO, InventoryView.CELL, true)
	t.eq(beside.position.x, r.position.x - ItemPainter.LOCK_SIDE - 2.0, "有小钉：往左让一个角标宽 + 2")
	tip.click_fav()
	t.check(not m.is_favorite(&"longsword") and tip.fav_state() == 0, "再点：取消")
	t.eq(ItemPainter.favorite_rect(sword.def, 0, Vector2.ZERO, InventoryView.CELL), Rect2(), "没收藏不画星")
	tip.show_text("地图点", Vector2(100, 100))
	tip.hide_tip()
	tip.show_text("地图点", Vector2(100, 100))
	t.eq(tip.fav_state(), -1, "文字窗没有丝带")
	host.free()
	ItemFavorites.attach(null)


static func frame_material_slot(t: TestCase, root: Window) -> void:
	t.begin("265 §2.4 · 铁匠铺材料格：停上去出这一种的道具窗（有丝带、没有按钮），点丝带收藏，格子图右上角画星")
	var db := _db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	ItemFavorites.attach(m)
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var tip := HoverTip.new()
	host.add_child(tip)
	var slot := RecipeScroll.MatSlot.new()
	slot.def = db.get_def(&"hardwood_plank")
	slot.size = Vector2(90, 110)
	host.add_child(slot)
	t.check(slot.is_in_group(ItemFavorites.GROUP), "收藏变了会重画")
	slot.hover()
	t.check(tip.is_showing() and tip.text().contains(Names.of(slot.def)), "出了木板的窗")
	t.eq(tip.fav_state(), 0, "有丝带、没收藏")
	t.eq(tip.action_buttons().size(), 0, "没有按钮")
	tip.click_fav()
	t.check(m.is_favorite(&"hardwood_plank"), "收藏了木板")
	slot.unhover()
	t.check(not tip.is_showing(), "离开就收（没钉住）")
	host.free()
	ItemFavorites.attach(null)


static func frame_warehouse_and_codex(t: TestCase, root: Window) -> void:
	t.begin("265 §2.5 · 仓库筛选牌「只看收藏」压灰别的、清除连它一起清；图鉴「全部 / 收藏」两档；出售页预览写跳过收藏")
	var f := Records._flow()
	var sword := ItemInstance.create(f.items.get_def(&"longsword"), f.meta.allocate_uid())
	var plank := ItemInstance.create(f.items.get_def(&"hardwood_plank"), f.meta.allocate_uid())
	for inst in [sword, plank]:
		f.meta.warehouse.try_add(inst, true)
	f.meta.toggle_favorite(&"longsword")
	f.meta.codex[&"longsword"] = 1
	var screen = Records._screen(f, root)
	screen.show_tab("warehouse")
	var tools: WarehouseTools = screen.warehouse_tools()
	t.eq(tools.fav_btn.text, "只看收藏", "筛选牌有「只看收藏」")
	tools.fav_btn.button_pressed = true
	tools.fav_btn.pressed.emit()
	var shelf: WarehousePages = screen.shelf()
	t.check(shelf.filter_fav and shelf.filtering(), "按下：只看收藏")
	t.check(shelf.matches(sword) and not shelf.matches(plank), "长剑亮、木板压灰")
	t.eq(shelf.match_count(0), 1, "页签写 1 件")
	t.check(not tools.clear_btn.disabled, "「清除」亮")
	tools.clear()
	t.check(not shelf.filter_fav and not tools.fav_btn.button_pressed, "清除：一起清")
	screen.set_sell_mode(true)
	t.check(screen.sell_sheet().skipped_text().contains(UiText.t("meta.sell_skip_fav") % 1), "268：出售单写跳过收藏 1 件（%s）" % screen.sell_sheet().skipped_text())
	screen.set_sell_mode(false)
	screen.show_tab("codex")
	t.eq(screen.codex_filter(), "all", "图鉴默认全部")
	screen.show_codex_filter("fav")
	var shown: Array = screen.codex_tiles().filter(func(tl): return (tl as CodexTile).visible and (tl as CodexTile).get_parent() == screen._codex_grids[0]).map(func(tl): return (tl as CodexTile).def.id)
	t.eq(shown, [&"longsword"], "收藏档只露长剑")
	f.meta.toggle_favorite(&"hardwood_plank")
	shown = screen.codex_tiles().filter(func(tl): return (tl as CodexTile).visible and (tl as CodexTile).get_parent() == screen._codex_grids[0]).map(func(tl): return (tl as CodexTile).def.id)
	t.check(shown.has(&"hardwood_plank"), "收藏了木板：跟着露")
	screen.show_codex_filter("all")
	screen.free()
	Records._cleanup()
