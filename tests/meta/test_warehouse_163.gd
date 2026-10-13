## 163（作者定）：仓库扩建加页不加行 —— 每页一块独立的格子（10 × 8），自动放按页序；只删末尾的空页；存档逐页，老档（一块）按页切；
## 界面：左边竖排页签（一、二、三……，没解锁的灰着带锁），切页只换视图的容器；拖着东西停在页签上 0.4 秒切页；双击置入落到哪页翻到哪页
extends RefCounted

const META := "user://test_163_meta.json"
const SETTINGS := "user://test_163_settings.json"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _fill_page(w: Warehouse, db: ItemDatabase, page: int, id: StringName) -> int:
	var n := 0
	var p := w.page(page)
	while true:
		var inst := ItemInstance.create(db.get_def(id))
		if not p.try_add(inst):
			break
		n += 1
	return n


static func run_pages(t: TestCase) -> void:
	t.begin("163 · Warehouse：每页一样大、各自独立；自动放按页序（第一页满了落第二页）；读取 / 移除跨页；只删末尾的空页")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var w := Warehouse.new(Vector2i(10, 8), MetaState.WAREHOUSE_ID, 3)
	t.eq(w.page_count(), 3, "三页")
	for i in 3:
		t.eq(w.page(i).size, Vector2i(10, 8), "第 %d 页 10 × 8" % (i + 1))
	t.eq(w.size, Vector2i(10, 8), "老接口 size 是一页的大小")
	t.check(w.page(0).id != w.page(1).id and w.page(1).id != MetaState.BOARD_ID, "页的 id 各不同、不和带回来的棋盘撞")
	var n := _fill_page(w, db, 0, &"steel_ingot")
	t.check(n > 0, "第一页塞满了 %d 块钢锭" % n)
	var extra := ItemInstance.create(db.get_def(&"steel_ingot"))
	t.check(w.try_add(extra), "再放一块")
	t.eq(w.page_of(extra.uid), 1, "落在第二页")
	t.eq(w.item_count(), n + 1, "件数跨页数")
	t.eq(w.get_item(extra.uid), extra, "get_item 跨页")
	t.check(w.can_admit(extra.def), "还收")
	t.eq(w.remove(extra.uid), extra, "remove 跨页")
	t.eq(w.page_of(extra.uid), -1, "拿走了")
	var fired := [0]
	w.changed.connect(func(): fired[0] += 1)
	w.page(2).try_add(ItemInstance.create(db.get_def(&"knife")))
	t.check(fired[0] >= 1, "任一页变了仓库发 changed")
	t.check(w.owns(w.page(1)) and w.owns(w) and not w.owns(GridInventory.new()), "owns 认得自己的页")
	t.eq(w.set_page_count(1), 3, "第三页有东西：一页也删不掉（只删末尾的空页）")
	w.page(2).clear()
	t.eq(w.set_page_count(1), 1, "后两页空了：删到一页")
	t.eq(w.set_page_count(5), 5, "加页：后面加空页")
	t.eq(w.page(4).item_count(), 0, "新页是空的")
	w.accept_filter = MetaState.keeps
	t.check(not w.accepts(db.get_def(&"bag_small")), "准入同步到每一页：包不收")
	t.check(not w.page(4).accepts(db.get_def(&"bag_small")), "新加的页也不收包")


static func run_save(t: TestCase) -> void:
	t.begin("163 · 存档逐页：来回一样；页数给了按给的（多出的页里的东西挪进前面的页）；老档（一块 10 × 14）按页切：前 8 行原位、下面的按页序重摆")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var size := Vector2i(10, 8)
	var w := Warehouse.new(size, MetaState.WAREHOUSE_ID, 2)
	var a := ItemInstance.create(db.get_def(&"knife"))
	var b := ItemInstance.create(db.get_def(&"steel_ingot"))
	t.check(w.place(a, Vector2i(3, 2), 0, 0) and w.place(b, Vector2i(5, 5), 0, 1), "第一页、第二页各放一件")
	var d := w.to_dict()
	t.eq((d["pages"] as Array).size(), 2, "存了两页")
	var back := Warehouse.from_dict(d, db, size)
	t.eq(back.page_count(), 2, "读回两页")
	t.check(back.page_of(b.uid) == 1 and back.get_item(b.uid).origin == Vector2i(5, 5), "第二页那件原页原位")
	t.check(back.page_of(a.uid) == 0 and back.get_item(a.uid).origin == Vector2i(3, 2), "第一页那件原页原位")
	var one := Warehouse.from_dict(d, db, size, 1)
	t.eq(one.page_count(), 1, "给了一页")
	t.eq(one.item_count(), 2, "第二页那件挪进第一页，一件不丢")

	# 老档：一块 10 × 14
	var old := GridInventory.new(Vector2i(10, 14), MetaState.WAREHOUSE_ID, false)
	var top := ItemInstance.create(db.get_def(&"knife"))
	var low := ItemInstance.create(db.get_def(&"steel_ingot"))
	old.place(top, Vector2i(2, 1))
	old.place(low, Vector2i(0, 12))
	var legacy := Warehouse.from_dict(old.to_dict(), db, size)
	t.eq(legacy.page_count(), 2, "14 行按 8 行一页切成两页")
	t.check(legacy.page_of(top.uid) == 0 and legacy.get_item(top.uid).origin == Vector2i(2, 1), "前 8 行里的原位")
	t.check(legacy.has_item(low.uid), "第 12 行那件还在（重摆了）")
	t.eq(legacy.item_count(), 2, "一件不丢")


static func run_tech(t: TestCase) -> void:
	t.begin("163 · 科技：仓库扩建每级加一页，满级七页；推算只删空页；界面的计划（最多几页、每级几页）")
	var defs := GameFlow.load_techs()
	var plan := TechWarehousePages.plan_of(defs)
	t.eq(int(plan.get("max", 0)), 7, "满级 1 + 6 = 7 页")
	t.eq(int(plan.get("per_level", 0)), 1, "每级一页")
	t.eq(TechWarehousePages.plan_of([]), {}, "没有这个科技：空")
	var m := MetaState.new(GameFlow.load_meta_rules())
	m.tech_levels["warehouse"] = 6
	TechService.derive(m, defs)
	t.eq(m.warehouse.page_count(), 7, "6 级：七页")
	var def := TechService.find(defs, &"warehouse")
	t.eq(def.effect.describe_level(2), "仓库共 3 页", "每级说明")
	m.warehouse.page(6).try_add(ItemInstance.create(_db().get_def(&"knife")))
	m.tech_levels["warehouse"] = 1
	TechService.derive(m, defs)
	t.eq(m.warehouse.page_count(), 7, "降级：最后一页有东西，不删")


static func run_meta_across_pages(t: TestCase) -> void:
	t.begin("163 · 局外跨页：发放、一键出售预览、一键置入都按全仓库算")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	m.warehouse.set_page_count(2)
	var n := _fill_page(m.warehouse, db, 0, &"steel_ingot")
	t.eq(m.grant([db.get_def(&"knife")]), 1, "第一页满了也发得进")
	t.eq(m.warehouse.page(1).item_count(), 1, "落在第二页")
	var p := m.sell_preview(-1, 0.5)
	t.eq(int(p["count"]), n + 1, "一键出售预览跨页数件")


static func frame_widget(t: TestCase, root: Window) -> void:
	t.begin("163 · 分页组件：页签竖排「一」「二」…、没解锁的灰着；切页换视图的容器；双击置入落到哪页翻到哪页；拖着东西停在页签上 0.4 秒切页")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var w := Warehouse.new(Vector2i(10, 8), MetaState.WAREHOUSE_ID, 2)
	var drag := DragLayer.new()
	root.add_child(drag)
	var pages := WarehousePages.new()
	root.add_child(pages)
	pages.setup(w, UiPalette.cjk_font(), drag, {"max": 4, "per_level": 1, "name": "仓库扩建"})
	t.eq(pages.tab_count(), 4, "四个页签（两页解锁、两页锁着）")
	t.check(pages.tab_box is VBoxContainer, "页签竖排")
	t.check(pages.tab(0).text.begins_with("一") and pages.tab(1).text.begins_with("二"), "页名是中文数字：%s / %s" % [pages.tab(0).text, pages.tab(1).text])
	t.check(pages.tab(2).disabled and pages.is_locked(2), "第三页锁着、灰的")
	t.check(pages.tab(2).tooltip_text.contains("第 2 级"), "悬停写要扩建到第几级：%s" % pages.tab(2).tooltip_text)
	t.check(not pages.show_page(2), "锁着的页切不过去")
	t.eq(pages.current(), 0, "默认第一页")
	t.eq(pages.view.inventory, w.page(0), "视图看第一页")
	t.check(pages.tab(0).button_pressed and not pages.tab(1).button_pressed, "选中的页签按下")
	var view_before := pages.view
	t.check(pages.show_page(1), "切到第二页")
	t.eq(pages.view, view_before, "视图不重建")
	t.eq(pages.view.inventory, w.page(1), "视图换成第二页")
	var knife := ItemInstance.create(db.get_def(&"knife"))
	w.page(0).try_add(knife)
	t.check(pages.tab(0).text.contains("1件"), "页签下面写件数：%s" % pages.tab(0).text.replace("\n", " "))
	t.check(pages.show_item(knife.uid) and pages.current() == 0, "show_item：翻到那件所在的页")
	w.set_page_count(3)
	t.check(not pages.is_locked(2) and not pages.tab(2).disabled, "扩建了：第三页解锁")
	# 拖着东西停在页签上
	t.check(not pages.hover_tab(1, 0.2), "停在第二个页签 0.2 秒：还没切")
	t.check(not pages.hover_tab(2, 0.3), "换到第三个页签：重新计时")
	t.check(not pages.hover_tab(1, 0.2), "回到第二个：又从零算")
	t.check(pages.hover_tab(1, 0.25), "累计 0.45 秒：切了")
	t.eq(pages.current(), 1, "切到第二页")
	t.check(not pages.hover_tab(3, 1.0), "锁着的页签停多久都不切")
	t.eq(pages.drag_hover(Vector2(-999, -999), 1.0), false, "不在页签上：不切")
	pages.queue_free()
	drag.queue_free()


static func frame_setup_and_result(t: TestCase, root: Window) -> void:
	t.begin("163 · 开局第二页与结算屏都用分页仓库；第一页满了，放回 / 置入落到第二页且翻过去；整理只动当前页")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	f.meta.tech_levels["warehouse"] = 1
	f.derive_techs()
	var n := _fill_page(f.meta.warehouse, db, 0, &"steel_ingot")
	f.meta.board = GridInventory.new(Vector2i(6, 4), MetaState.BOARD_ID, false)
	var k := ItemInstance.create(db.get_def(&"knife"))
	f.meta.board.try_add(k)
	var panel = load("res://ui/game/warehouse_panel.gd").new()
	root.add_child(panel)
	panel.setup(f, UiPalette.cjk_font())
	var shelf: WarehousePages = panel.shelf()
	t.not_null(shelf, "结算屏的面板自己建了分页仓库")
	t.eq(shelf.tab_count(), 7, "列出七个页签（满级七页）")
	t.check(panel.quick_move(panel.board_view(), k.uid), "双击带回来的那件：置入")
	t.eq(f.meta.warehouse.page_of(k.uid), 1, "第一页满了，落第二页")
	t.eq(shelf.current(), 1, "翻到第二页")
	# 作者 2026-10-13：搬空了带回来的背包也留着（结算屏不跳位）—— 再双击仓库的那件就放回去；这里放回再置入，后面照旧
	t.check(panel.quick_move(shelf.view, k.uid), "带回来的背包搬空了还在：再双击仓库的那件放回去")
	t.check(panel.quick_move(panel.board_view(), k.uid), "再置入一次")
	shelf.show_page(0)
	var before: Array = []
	for inst in f.meta.warehouse.page(1).items():
		before.append((inst as ItemInstance).origin)
	panel.tidy()
	var after: Array = []
	for inst in f.meta.warehouse.page(1).items():
		after.append((inst as ItemInstance).origin)
	t.eq(after, before, "整理第一页：第二页不动")
	t.eq(f.meta.warehouse.page(0).item_count(), n, "第一页件数不变")
	panel.queue_free()
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
