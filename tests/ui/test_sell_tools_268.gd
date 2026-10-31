## 268（作者 2026-10-30 15:23 定 C；补充一 15:27 / 15:28「快速出售」）：出售页删了 —— 仓库页工具列 筛选牌 / 账牌 中间一颗【快速出售】，
## 按下进出售模式（出售单：筛选 + 全选 + 两步出售；右边仓库单击勾选）；包架悬浮窗卖包；后勤只剩 集市 / 铁匠铺；老名字 "sell" 落仓库页
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const H164 := preload("res://tests/ui/test_base_home_164.gd")


static func frame_quick_sell(t: TestCase, root: Window) -> void:
	t.begin("268 补充一 · 快速出售：键在筛选牌与账牌之间、按下进模式（出售单露出、筛选牌 / 包架收起）；点格子勾 / 取消，锁定收藏勾不上并说原因；全选只勾筛中能卖的、再点全不选；页签写 勾了 / 本页；出售两步；卖完勾选清空留在模式；Esc 退出、筛选牌的筛选还原")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	var k1 := H164._put(f, &"knife")
	var k2 := H164._put(f, &"knife")
	var locked := H164._put(f, &"knife")
	locked.set_locked(true)
	var plank := H164._put(f, &"hardwood_plank")
	var sword := H164._put(f, &"longsword")
	f.meta.grant_bags([f.items.get_def(&"sack")])
	ItemFavorites.attach(f.meta)
	f.meta.toggle_favorite(&"longsword")
	var screen = W178._screen(f, root)
	screen.show_tab("warehouse")
	var tools: WarehouseTools = screen.warehouse_tools()
	var shelf: WarehousePages = screen.shelf()
	var key := tools.quick_btn
	t.not_null(key, "工具列有【快速出售】")
	t.check(tools.filter_plate.get_index() < key.get_index() and key == tools.get_child(tools.filter_plate.get_index() + 1), "在筛选牌正下面")
	t.eq(key.theme_type_variation, UiTheme.BUTTON_HOME_PRIMARY, "主档木牌")
	t.eq(key.custom_minimum_size, WarehouseTools.QUICK_SIZE, "228 × 56")
	t.check(key.toggle_mode and not key.button_pressed, "可按下，起初抬着")
	var sheet: SellSheet = screen.sell_sheet()
	t.check(not sheet.is_visible_in_tree(), "出售单起初藏着")
	tools.set_filter(&"", 0)     # 筛选牌先筛一档，退出模式要还原
	var saved_rarity := shelf.filter_rarity
	key.button_pressed = true
	key.pressed.emit()
	t.check(screen.sell_mode() and shelf.select_mode and shelf.view.select_mode, "按下：进出售模式")
	t.check(sheet.is_visible_in_tree() and key.button_pressed, "出售单露出、键按着")
	t.eq(sheet.get_index(), key.get_index() + 1, "出售单挂在键下面")
	t.check(not tools.filter_plate.visible and not screen._wh._rack_box.visible, "筛选牌、包架收起")
	t.eq(shelf.filter_rarity, -1, "出售单默认 不限 / 全部（独立于筛选牌）")
	t.eq(sheet.summary_text(), UiText.t("sell.picked") % 0, "已选 0 件")
	t.check(sheet.sell_btn.disabled, "0 件：【出售】压灰")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_HOME_PLAQUE), UiTheme.TONE_LIGHT, "木牌浅底")
	# 点格子
	shelf.view.item_picked.emit(shelf.view, k1.uid)
	t.check(shelf.selected.has(k1.uid), "点一下：勾上")
	t.eq(sheet.summary_text(), UiText.t("sell.picked") % 1, "已选 1 件")
	t.eq(sheet.coin_amount(), MetaState.sell_price_of(k1, f.sell_ratio()), "金币写卖价")
	t.check(not sheet.sell_btn.disabled, "有勾：【出售】亮")
	t.eq(shelf.tab(0).text.split("\n")[1], UiText.t("wh.tab_picked") % [1, f.meta.warehouse.page(0).item_count()], "页签写 勾了 / 本页")
	shelf.view.item_picked.emit(shelf.view, k1.uid)
	t.check(not shelf.selected.has(k1.uid), "再点：取消")
	shelf.view.item_picked.emit(shelf.view, locked.uid)
	t.check(not shelf.selected.has(locked.uid), "锁着的勾不上")
	t.eq(screen.notice_layer().current_text(), UiText.t("sell.no_locked") % Names.of(locked.def), "告示说锁着")
	shelf.view.item_picked.emit(shelf.view, sword.uid)
	t.check(not shelf.selected.has(sword.uid), "收藏的勾不上")
	t.eq(screen.notice_layer().current_text(), UiText.t("sell.no_fav") % Names.of(sword.def), "告示说是收藏")
	t.check(not bool(shelf.view.dim_filter.call(locked)) and not bool(shelf.view.dim_filter.call(sword)) and bool(shelf.view.dim_filter.call(k2)), "锁定 / 收藏的压灰")
	# 全选
	sheet.toggle_all()
	t.eq(shelf.selected.keys().size(), 3, "全选：两把刀 + 木板（锁着的刀、收藏的长剑不算）")
	t.check(sheet.skipped_text().contains(UiText.t("meta.sell_skipped") % 1) and sheet.skipped_text().contains(UiText.tn("meta.sell_skip_fav", 1) % 1), "小字写跳过锁定 1 / 收藏 1（%s）" % sheet.skipped_text())
	t.eq(sheet.all_btn.text, UiText.t("sell.select_none"), "都勾了：键写「全不选」")
	sheet.toggle_all()
	t.eq(shelf.selected.size(), 0, "再点：全不选")
	var knife_tag := StringName()
	for tag in f.meta.sell_tags():
		if k1.def.tags.has(tag) and not plank.def.tags.has(tag):
			knife_tag = tag
			break
	if knife_tag != &"":
		sheet.set_filter(knife_tag, -1)
		sheet.toggle_all()
		t.eq(shelf.selected.size(), 2, "按刀的标签全选：两把")
		t.check(not bool(shelf.view.dim_filter.call(plank)), "木板不合筛选：压灰")
		shelf.view.item_picked.emit(shelf.view, plank.uid)
		t.check(shelf.selected.has(plank.uid), "不合筛选的照样能点勾（筛选只管全选）")
		sheet.toggle_all()
		t.eq(shelf.selected.keys(), [plank.uid], "测试 v4.81：全不选只取消筛中的，筛选外勾的木板留着")
		sheet.toggle_all()
		t.eq(shelf.selected.size(), 3, "再全选：两把刀加回来，木板还在")
		sheet.set_filter(&"", -1)
	shelf.clear_selection()
	shelf.view.item_picked.emit(shelf.view, k2.uid)
	shelf.view.item_picked.emit(shelf.view, plank.uid)
	# 两步出售
	var funds := f.meta.funds
	t.eq(sheet.press_sell(), {}, "第一下不卖")
	t.check(sheet.confirming() and sheet.sell_btn.text == UiText.t("act.confirm"), "变「再点一次」")
	sheet.tick(SellSheet.CONFIRM_SEC + 0.1)
	t.check(not sheet.confirming() and sheet.sell_btn.text == UiText.t("sell.go"), "两秒不点：回弹")
	sheet.press_sell()
	var got: Dictionary = sheet.press_sell()
	t.eq(int(got["count"]), 2, "第二下：卖了勾的两件")
	t.eq(f.meta.funds, funds + int(got["funds"]), "钱进局外")
	t.check(not f.meta.warehouse.has_item(k2.uid) and not f.meta.warehouse.has_item(plank.uid) and f.meta.warehouse.has_item(k1.uid), "只卖勾了的")
	t.eq(screen.notice_layer().current_text(), UiText.t("meta.sold_many") % [2, int(got["funds"]), f.meta.funds], "告示：卖了几件得几币")
	t.eq(shelf.selected.size(), 0, "勾选清空")
	t.check(screen.sell_mode(), "留在出售模式")
	# 勾了的被右键卖掉：从勾选里去掉
	shelf.view.item_picked.emit(shelf.view, k1.uid)
	screen.sell(k1.uid)
	t.check(not shelf.selected.has(k1.uid), "右键卖掉的从勾选里去掉")
	# Esc
	shelf.view.item_picked.emit(shelf.view, H164._put(f, &"knife").uid)
	t.check(screen.escape(), "Esc 吃掉")
	t.check(not screen.sell_mode() and not shelf.view.select_mode, "Esc：退出售模式")
	t.eq(screen.tab(), "warehouse", "还在仓库页")
	t.check(not key.button_pressed and not sheet.is_visible_in_tree(), "键抬起、出售单藏起")
	t.check(tools.filter_plate.visible and screen._wh._rack_box.visible, "筛选牌、包架回来")
	t.eq(shelf.selected.size(), 0, "勾选全清")
	t.eq(shelf.filter_rarity, saved_rarity, "筛选牌的筛选还原")
	# 【取消】、切页也退
	screen.set_sell_mode(true)
	sheet.cancel_btn.pressed.emit()
	t.check(not screen.sell_mode(), "【取消】：退出")
	screen.set_sell_mode(true)
	screen.show_tab("logistics")
	t.check(not screen.sell_mode(), "切到别页：退出")
	screen.queue_free()
	ItemFavorites.attach(null)
	W178._cleanup()


static func frame_check_badge(t: TestCase, root: Window) -> void:
	t.begin("268 补充一 · 勾了的左下角画金勾（模式外不画）；视图在勾选模式里单击不抓、双击不发")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	var k := H164._put(f, &"knife")
	var r := ItemPainter.check_rect(k, 0, Vector2.ZERO, InventoryView.CELL)
	var cells := k.def.shape.cells_rotated(0)
	var bottom := 0
	for c in cells:
		bottom = maxi(bottom, c.y)
	t.check(r.size.x > 0.0 and is_equal_approx(r.end.y, (bottom + 1) * InventoryView.CELL - InventoryView.CELL * ItemPainter.LOCK_INSET), "勾在最下一排（%s）" % r)
	t.check(r.position.x < InventoryView.CELL * 0.5, "靠左")
	var view := InventoryView.new()
	view.inventory = f.meta.warehouse.page(0)
	root.add_child(view)
	var grabbed := []
	var picked := []
	var doubled := []
	view.grab_requested.connect(func(_v, uid, _p): grabbed.append(uid))
	view.item_picked.connect(func(_v, uid): picked.append(uid))
	view.item_double_clicked.connect(func(_v, uid): doubled.append(uid))
	view.select_mode = true
	var at := view.cell_origin_px(k.origin) + Vector2.ONE * 4.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	view._gui_input(press)
	var dbl := press.duplicate() as InputEventMouseButton
	dbl.double_click = true
	view._gui_input(dbl)
	t.eq(picked, [k.uid], "单击发一次勾选，双击的第二下不算")
	t.check(grabbed.is_empty() and doubled.is_empty(), "不抓、不发双击")
	view.select_mode = false
	view._gui_input(press)
	t.eq(grabbed, [k.uid], "模式外照常抓")
	view.queue_free()
	W178._cleanup()


static func frame_sell_page_gone(t: TestCase, root: Window) -> void:
	t.begin("268 · 出售页删了：后勤只剩集市 / 铁匠铺两颗小键；\"sell\" 落仓库页；仓库页双击仍是置入；包架悬浮窗能卖包，结算页的包架不卖")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	f.meta.grant_bags([f.items.get_def(&"sack")])
	var screen = W178._screen(f, root)
	t.eq(screen.sub_tab_buttons().keys(), ["market", "smithy"], "后勤两颗小键")
	t.check(not screen._pages.has("sell"), "没有出售页")
	screen.show_tab("sell")
	t.eq(screen.tab(), "warehouse", "老名字 sell → 仓库页")
	t.eq(screen.sub_tab(), "", "不在后勤")
	var rack: BagRackView = screen._wh.rack_view()
	var uid: int = rack.uid_at_local(rack.slot_rect(0).get_center())
	var acts: Array = rack.actions_for.call(uid)
	t.eq(acts.map(func(a): return (a as ItemActions.Action).id), [&"sell"], "包架悬浮窗：出售")
	var funds := f.meta.funds
	(acts[0] as ItemActions.Action).run.call()
	t.check(f.meta.funds > funds and f.meta.rack.count_of(&"sack") == 0, "卖了包进钱")
	t.check(screen.notice_layer().current_text() != "", "告示说了一句")
	screen.queue_free()
	var result_wh = load("res://ui/game/warehouse_panel.gd").new()
	root.add_child(result_wh)
	result_wh.setup(f, UiPalette.cjk_font())
	t.check(not result_wh.rack_view().actions_for.is_valid(), "结算页（自带仓库）的包架不卖")
	result_wh.queue_free()
	W178._cleanup()


static func frame_tools_fit(t: TestCase, root: Window) -> void:
	t.begin("268 · 工具列多了快速出售仍放得下：中英 × 三档字号，平常（包架 + 两块牌 + 键）与出售模式（键 + 出售单 + 账牌）都不超过屏高、不撑宽中列")
	var f := W178._flow()
	f.meta.grant_bags([f.items.get_def(&"sack")])
	for lang in ["zh", "en"]:
		UiText.lang = lang
		for tier in [&"small", &"medium", &"large"]:
			UiTheme.with_text_size(tier, func():
				var sc: Control = W178._screen(f, root)
				sc.show_tab("warehouse")
				sc.layout()
				var col: Control = sc._wh._rack_col
				var room: float = 1000.0 - 2.0 * sc.MARGIN
				t.check(col.get_combined_minimum_size().y <= room, "%s %s：工具列 %.0f 高放得进 %.0f" % [lang, tier, col.get_combined_minimum_size().y, room])
				sc.set_sell_mode(true)
				sc.layout()
				t.check(col.get_combined_minimum_size().y <= room, "%s %s：出售模式（键 + 出售单 + 账牌）%.0f 高放得进 %.0f" % [lang, tier, col.get_combined_minimum_size().y, room])
				var w: float = sc._wh.get_combined_minimum_size().x
				t.check(w <= sc.middle_width(Vector2(1600, 1000)), "%s %s：出售单不撑宽中列（%.0f ≤ %.0f）" % [lang, tier, w, sc.middle_width(Vector2(1600, 1000))])
				sc.free())
	UiText.lang = "zh"
	W178._cleanup()


static func frame_wood_drop_arrow(t: TestCase, root: Window) -> void:
	t.begin("press_home A 补：木牌下拉开着底变深，箭头换浅色 `kit/drop_arrow_pressed`，合上换回 `kit/drop_arrow`；石刻下拉不动")
	var up := UiTheme.art_cached("kit/drop_arrow")
	var down := UiTheme.art_cached("kit/drop_arrow_pressed")
	t.not_null(down, "有浅色箭头图")
	var ob := OptionButton.new()
	ob.add_item("A")
	ob.add_item("B")
	root.add_child(ob)
	UiTheme.dress_wood_option(ob)
	t.eq(ob.get_theme_icon("arrow"), up, "合上：原来的墨色箭头")
	ob.get_popup().about_to_popup.emit()
	t.eq(ob.get_theme_icon("arrow"), down, "开着：浅色箭头")
	ob.get_popup().popup_hide.emit()
	t.eq(ob.get_theme_icon("arrow"), up, "合上：换回墨色")
	var chip := OptionButton.new()
	root.add_child(chip)
	UiTheme.dress_chip_option(chip)
	chip.get_popup().about_to_popup.emit()
	t.check(chip.get_theme_icon("arrow") != down, "石刻下拉开着也不换")
	ob.free()
	chip.free()
