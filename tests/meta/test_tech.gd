## 110（作者定）：仓库扩建 = 第一项局外科技。1～3 级只要钱、每级仓库加一页（163：原来是 +3 行）且东西原地不动；
## 第 4 级起要建材，分批上交（上交即消耗、跨存档记着），交齐且钱够【升级】才亮，升完清上交记录；
## 存档 v2 → v3；读档按进度表推算页数（120：先算容量再装仓库）；整理先同类再大小；仓库滚动后拖拽只认露在外面的部分；基地「科技」页。
extends RefCounted

const META := "user://test_110_meta.json"
const SETTINGS := "user://test_110_settings.json"
const TECH_PANEL := "res://ui/game/tech_panel.gd"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _tech() -> TechDef:
	return load(ContentPaths.asset_file("techs", "warehouse")) as TechDef


static func _meta() -> MetaState:
	return MetaState.new(GameFlow.load_meta_rules())


static func _add(meta: MetaState, db: ItemDatabase, id: StringName) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id), meta.allocate_uid())
	return inst if meta.warehouse.try_add(inst, true) else null


static func run_content(t: TestCase) -> void:
	t.begin("110 · 内容：仓库扩建 6 级，前 3 级只要钱；三种建材蓝色、没有战斗属性、商店不卖")
	var def := _tech()
	t.not_null(def, "科技资产导出来了")
	if def == null:
		return
	t.eq(def.max_level(), 6, "6 级")
	t.check(def.effect is TechWarehousePages and (def.effect as TechWarehousePages).pages == 1, "163：每级加一页")
	for i in 3:
		t.check(def.tiers[i].items.is_empty() and def.tiers[i].funds > 0, "第 %d 级只要钱" % (i + 1))
	for i in range(3, 6):
		t.check(not def.tiers[i].items.is_empty(), "第 %d 级要建材" % (i + 1))
	var db := _db()
	for id in [&"steel_ingot", &"hardwood_plank", &"rivet_box"]:
		var item := db.get_def(id)
		t.not_null(item, "%s 在" % id)
		if item == null:
			continue
		t.eq(item.rarity, 2, "%s 是蓝色（稀有度 2）" % id)
		t.check(item.tags.has(&"supply") and item.tags.has(&"material"), "%s 带建材标签" % id)
		t.check(item.combat == null or item.combat.rules.is_empty(), "%s 没有战斗规则" % id)
	for eco in ["standard", "prologue"]:
		var rules := load(ContentPaths.asset_file("economy_rules", eco)) as EconomyRules
		t.check(rules.shop_exclude_tags.has(&"supply"), "%s 经济：商店不卖建材" % eco)
	t.not_null(load(ContentPaths.asset_file("tags", "supply")), "「建材」标签在")


static func run_money_levels(t: TestCase) -> void:
	t.begin("110 · 1～3 级只扣钱；每级仓库加一页（163），东西原地不动；钱不够不亮")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var def := _tech()
	var m := _meta()
	var pages0 := m.warehouse.page_count()
	var knife := _add(m, db, &"knife")
	var at := knife.origin
	t.check(not TechService.ready(m, def), "没钱：不能升")
	t.check(not TechService.upgrade(m, def), "没钱：升级什么也不动")
	t.eq(TechService.level(m, def.id), 0, "还是 0 级")
	m.funds = 100 + 200 + 400 + 5
	for lv in 3:
		t.check(TechService.needed(m, def).is_empty(), "第 %d 级不要材料" % (lv + 1))
		t.check(TechService.ready(m, def), "钱够就能升到 %d 级" % (lv + 1))
		t.check(TechService.upgrade(m, def), "升到 %d 级" % (lv + 1))
		t.eq(m.warehouse.page_count(), pages0 + lv + 1, "仓库 %d 页" % (pages0 + lv + 1))
	t.eq(m.funds, 5, "扣了 100 + 200 + 400")
	t.eq(TechService.level(m, def.id), 3, "3 级")
	t.check(m.warehouse.has_item(knife.uid) and knife.origin == at, "原来的那件原地不动")
	t.check(not TechService.ready(m, def), "第 4 级要建材：没交不能升")


static func run_deposits(t: TestCase) -> void:
	t.begin("110 · 第 4 级起分批上交：交一件记一件、存档读回还记着；不要的交不进；交齐 + 钱够才亮；升完清记录")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var def := _tech()
	var m := _meta()
	m.tech_levels["warehouse"] = 3
	m.warehouse.set_page_count(4)
	var plank := _add(m, db, &"hardwood_plank")
	t.check(not TechService.can_submit(m, def, plank.def), "第 4 级不要硬木板")
	t.check(not TechService.submit(m, def, plank.uid), "交不进")
	t.check(m.warehouse.has_item(plank.uid), "硬木板还在仓库")
	var a := _add(m, db, &"steel_ingot")
	var b := _add(m, db, &"steel_ingot")
	t.check(TechService.can_submit(m, def, a.def), "第 4 级要钢锭")
	t.check(TechService.submit(m, def, a.uid), "交第一块钢锭")
	t.check(not m.warehouse.has_item(a.uid), "上交即消耗：仓库里没了")
	t.eq(TechService.deposited(m, def.id, &"steel_ingot"), 1, "记了 1 块")
	t.eq(int(TechService.needed(m, def)["steel_ingot"]), 1, "还差 1 块")

	# 存档往返：上交记录与等级都在
	var back := MetaSave.from_text(MetaSave.to_text(m), db, GameFlow.load_meta_rules())
	t.not_null(back, "存档读得回来")
	if back == null:
		return
	t.eq(TechService.level(back, def.id), 3, "等级还是 3")
	t.eq(TechService.deposited(back, def.id, &"steel_ingot"), 1, "交过的 1 块还记着")
	m = back
	m.funds = 0
	t.check(TechService.submit(m, def, b.uid), "下一局回来再交一块（分批）")
	t.check(TechService.items_complete(m, def), "钢锭交齐了")
	t.check(not TechService.ready(m, def), "钱不够（要 600）：还不能升")
	t.check(not TechService.can_submit(m, def, b.def), "交齐了：再来钢锭不收")
	m.funds = 600
	t.check(TechService.ready(m, def), "交齐 + 钱够：能升")
	var pages := m.warehouse.page_count()
	t.check(TechService.upgrade(m, def), "升到 4 级")
	t.eq(TechService.level(m, def.id), 4, "4 级")
	t.eq(m.funds, 0, "扣了 600")
	t.check(not m.tech_deposits.has("warehouse"), "升级后清掉这一项的上交记录")
	t.eq(m.warehouse.page_count(), pages + 1, "仓库多一页")
	t.check(TechService.can_submit(m, def, plank.def), "第 5 级要硬木板了")


static func run_max_level(t: TestCase) -> void:
	t.begin("110 · 满级：next_tier 为 null、不能升、什么都不收")
	var db := _db()
	var def := _tech()
	var m := _meta()
	m.tech_levels["warehouse"] = def.max_level()
	m.funds = 99999
	t.is_null(TechService.next_tier(m, def), "满级没有下一级")
	t.check(not TechService.ready(m, def) and not TechService.upgrade(m, def), "满级不能升")
	t.check(not TechService.can_submit(m, def, db.get_def(&"steel_ingot")), "满级不收建材")
	t.eq(m.funds, 99999, "钱没动")


static func run_migration_and_heal(t: TestCase) -> void:
	t.begin("110 · v2 存档迁到 v3（补两个空字典）；读档时仓库页数按等级推算，多出来的空页收回")
	var db := _db()
	var text := FileAccess.get_file_as_string("res://tests/fixtures/meta_v2.json")
	var raw: Dictionary = JSON.parse_string(text)
	t.eq(int(raw["version"]), 2, "样本是 v2")
	var up := MetaMigrations.upgrade(raw)
	t.eq(int(up["version"]), MetaState.SAVE_VERSION, "升到当前版本")
	t.check(up["tech_levels"] is Dictionary and (up["tech_levels"] as Dictionary).is_empty(), "补了空的科技等级")
	t.check(up["tech_deposits"] is Dictionary and (up["tech_deposits"] as Dictionary).is_empty(), "补了空的上交记录")
	var m := MetaSave.from_text(text, db)
	t.not_null(m, "v2 的档读得回来")
	if m == null:
		return
	t.eq(m.funds, 120, "钱还在")
	t.eq(m.warehouse.item_count(), 1, "仓库那件还在")

	# 推算：等级 2 但仓库还是基础尺寸（手改存档 / 改了基础尺寸）
	var rules := GameFlow.load_meta_rules()
	var m2 := MetaState.new(rules)
	m2.tech_levels["warehouse"] = 2
	TechService.derive(m2, [_tech()])
	t.eq(m2.warehouse.page_count(), 3, "补到 1 + 2 页")
	TechService.derive(m2, [_tech()])
	t.eq(m2.warehouse.page_count(), 3, "再推算一次不再长")
	m2.warehouse.set_page_count(8)
	TechService.derive(m2, [_tech()])
	t.eq(m2.warehouse.page_count(), 3, "120：比期望多且多出的页是空的：收回到期望值")


## 120（作者定）：读档先读进度表、按科技算出仓库容量，再往里装东西；存档不存科技算出来的数
static func run_derive_on_load(t: TestCase) -> void:
	t.begin("120 / 163 · 读档先算容量再装仓库：一页的档 + 仓库扩建 2 级 → 仓库 3 页，东西还在原位")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var rules := GameFlow.load_meta_rules()
	var defs := GameFlow.load_techs()
	var m := MetaState.new(rules)
	var ingot := ItemInstance.create(db.get_def(&"steel_ingot"), m.allocate_uid())
	t.check(m.warehouse.place(ingot, Vector2i(0, 0), 0), "钢锭放在第一页左上")
	m.tech_levels["warehouse"] = 2
	var d := m.to_dict()
	t.eq(((d["warehouse"] as Dictionary)["pages"] as Array).size(), 1, "存档里仓库还是一页")
	var back := MetaState.from_dict(d, db, rules, defs)
	t.eq(back.warehouse.page_count(), 3, "读回来：1 + 2 页")
	t.check(back.warehouse.page_of(ingot.uid) == 0 and back.warehouse.get_item(ingot.uid).origin == Vector2i(0, 0), "钢锭还在原位")
	var legacy := MetaState.from_dict(d, db, rules)
	t.eq(legacy.warehouse.page_count(), 1, "没给科技定义：按存档里的页数（兜底）")

	t.begin("120 / 163 · 存档里仓库比科技算出的多页、后面的页有东西：读档挪进前面的页，页数 = 算出的，一件不丢")
	var big := MetaState.new(rules)
	big.warehouse.set_page_count(3)     # 存档里 3 页，但进度表里仓库扩建 0 级
	var low := ItemInstance.create(db.get_def(&"steel_ingot"), big.allocate_uid())
	t.check(big.warehouse.place(low, Vector2i(0, 4), 0, 2), "钢锭放在第三页")
	var back2 := MetaState.from_dict(big.to_dict(), db, rules, defs)
	t.eq(back2.warehouse.page_count(), 1, "仓库 = 算出的一页")
	t.check(back2.warehouse.page_of(low.uid) == 0, "那块钢锭挪进了第一页")
	t.eq(back2.warehouse.item_count(), 1, "一件不丢")

	t.begin("120 / 163 · 装不下（算出的页塞满了、还有越界的）：临时加页放下，件数不变；再推算有东西的页不删")
	var full := MetaState.new(rules)
	full.warehouse.set_page_count(2)
	var n := 0
	while true:
		var inst := ItemInstance.create(db.get_def(&"steel_ingot"), full.allocate_uid())
		if not full.warehouse.try_add(inst, true):
			break
		n += 1
	t.check(n > 0, "塞了 %d 件" % n)
	var back3 := MetaState.from_dict(full.to_dict(), db, rules, defs)
	t.eq(back3.warehouse.item_count(), n, "件数不变：%d" % n)
	t.eq(back3.warehouse.page_count(), 2, "临时加了一页（算出的是 1 页）")
	TechService.derive(back3, defs)
	t.eq(back3.warehouse.item_count(), n, "再推算一次：件数不变")
	t.eq(back3.warehouse.page_count(), 2, "有东西的页不删")

	t.begin("120 · 存档不存 tech_buffs / safe_bonus；带这两项的旧档读回来一样（派生值来自进度表）")
	var tm := MetaState.new(rules)
	tm.tech_levels["luck"] = 2
	tm.tech_levels["safe_box"] = 1
	TechService.derive(tm, defs)
	var td := tm.to_dict()
	t.check(not td.has("tech_buffs") and not td.has("safe_bonus"), "to_dict 里没有这两项")
	var fresh := MetaState.from_dict(td, db, rules, defs)
	var old := td.duplicate(true)
	old["tech_buffs"] = ["tech_luck_1", "tech_gone_9"]
	old["safe_bonus"] = [5, 5]
	var stale := MetaState.from_dict(old, db, rules, defs)
	t.eq(fresh.tech_buffs, [&"tech_luck_2"] as Array[StringName], "派生出幸运第 2 级那条")
	t.eq(stale.tech_buffs, fresh.tech_buffs, "旧档里存的 buff 不读")
	t.eq(stale.safe_bonus, fresh.safe_bonus, "旧档里存的保险箱加成不读")
	t.eq(fresh.safe_bonus, tm.safe_bonus, "保险箱加成 = 按级数算的")


static func run_shrink_rows(t: TestCase) -> void:
	t.begin("120 · shrink_rows：从底往上只删空行，碰到有东西的那一行停下")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var g := GridInventory.new(Vector2i(4, 6), 100, false)
	var inst := ItemInstance.create(db.get_def(&"steel_ingot"), 1)
	t.check(g.place(inst, Vector2i(0, 3), 0), "第 3 行放一块钢锭")
	var bottom := 3 + inst.def.shape.size_rotated(0).y
	var removed := g.shrink_rows(5)
	t.eq(g.size.y, bottom, "缩到钢锭最底下那一行为止")
	t.eq(removed, 6 - bottom, "只删了底下的空行")
	t.check(g.has_item(inst.uid), "钢锭还在")
	t.eq(g.resize_rows(bottom + 2), bottom + 2, "resize_rows 往大：长")


static func run_tidy_by_kind(t: TestCase) -> void:
	t.begin("110 · 整理：先同类（武器 → 防具 → 信仰 → 药剂 → 弹药 → 材料 → 珍宝 / 其他）再大小")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var g := GridInventory.new(Vector2i(8, 8), 100, false)
	var ids := [&"steel_ingot", &"bandage", &"knife", &"hardwood_plank"]
	for id in ids:
		t.check(g.try_add(ItemInstance.create(db.get_def(id)), true), "放 %s" % id)
	t.check(GridTidy.tidy(g), "整理")
	var order: Array = g.items().duplicate()
	order.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.origin.y < b.origin.y or a.origin.y == b.origin.y and a.origin.x < b.origin.x)
	var kinds: Array[int] = []
	for inst in order:
		kinds.append(GridTidy.kind_of((inst as ItemInstance).def))
	var sorted := kinds.duplicate()
	sorted.sort()
	t.eq(kinds, sorted, "从左上往右下，种类序不倒退：%s" % str(kinds))
	t.eq((order[0] as ItemInstance).def.id, &"knife", "武器排最前")
	t.eq(GridTidy.kind_of(db.get_def(&"steel_ingot")), GridTidy.kind_of(db.get_def(&"hardwood_plank")), "钢锭与硬木板同类（材料）")
	var mats: Array = order.filter(func(i: ItemInstance) -> bool: return i.def.tags.has(&"supply"))
	t.eq((mats[0] as ItemInstance).def.id, &"hardwood_plank", "同类里大的（2 格）在前")
	var plain := ItemDef.new()
	plain.id = &"odd"
	t.eq(GridTidy.kind_of(plain), GridTidy.KIND_ORDER.size() - 1, "没命中任何一类：排最后")


static func frame_scroll_drag(t: TestCase, root: Window) -> void:
	t.begin("110 · 仓库滚动：视图变高、滚走的部分不接落点、露在外面的部分照常命中")
	var inv := GridInventory.new(Vector2i(4, 20), 100, false)
	var view := InventoryView.new()
	view.inventory = inv
	var sc := ScrollBox.wrap(view, 5)
	root.add_child(sc)
	sc.position = Vector2(10, 10)
	sc.size = sc.custom_minimum_size
	t.eq(sc.custom_minimum_size.y, 5.0 * InventoryView.CELL, "窗口 5 行高")
	var drag := DragLayer.new()
	drag.register_view(view)
	var below := sc.global_position + Vector2(10, 6.0 * InventoryView.CELL)
	t.is_null(drag.view_at(below), "窗口下面（被裁掉的第 7 行）不命中")
	t.check(drag.view_at(sc.global_position + Vector2(10, 10)) == view, "窗口里命中")
	view.position.y = -3.0 * InventoryView.CELL     # 相当于往下滚了 3 行
	var hit := sc.global_position + Vector2(10, 10)
	t.check(drag.view_at(hit) == view, "滚过之后窗口顶上照样命中")
	t.eq(view.cell_at_global(hit).y, 3, "落点按当前位置换算：是第 4 行（下标 3）")
	inv.grow_rows(3)
	t.eq(view.custom_minimum_size.y, 23.0 * InventoryView.CELL, "格子长了 3 行：视图跟着变高")
	drag.free()
	sc.queue_free()


static func frame_tech_panel(t: TestCase, root: Window) -> void:
	t.begin("110 · 科技页：双击上交、不要的提示、拖进上交区记账、钱够才亮【升级】、升级后仓库多一页")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var m := _meta()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), m)
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	t.check(f.tech_defs.size() >= 1 and f.tech_of(&"warehouse") != null, "读到仓库扩建（118 起还有别的科技）")
	m.tech_levels["warehouse"] = 3
	f.derive_techs()
	var panel = load(TECH_PANEL).new()
	root.add_child(panel)
	panel.setup(f, UiPalette.cjk_font())
	t.check(panel.select(&"warehouse"), "118：树上选中仓库扩建，右板切到它")
	var btn: Button = panel.upgrade_button(&"warehouse")
	t.not_null(btn, "有【升级】按钮")
	if btn == null:
		panel.queue_free()
		return
	t.check(btn.disabled, "没交没钱：灰")

	var plank := _add(m, db, &"hardwood_plank")
	t.check(not panel.submit(plank.uid), "双击硬木板：第 4 级不要")
	t.check(panel.line_text().contains("不是它下一级要的"), "提示：%s" % panel.line_text())
	t.check(m.warehouse.has_item(plank.uid), "硬木板还在")

	var a := _add(m, db, &"steel_ingot")
	t.check(panel.submit(a.uid), "双击钢锭：交了")
	t.eq(TechService.deposited(m, &"warehouse", &"steel_ingot"), 1, "记了 1 块")
	t.check(MetaSave.exists(META), "交了就存盘")

	# 拖进上交区：等价于把一件放进那块格子
	var b := _add(m, db, &"steel_ingot")
	m.warehouse.remove(b.uid)
	t.check(panel.zone().place(b, Vector2i.ZERO, 0), "钢锭落进上交区")
	t.eq(panel.zone().item_count(), 0, "上交区当场清空（记账拿走）")
	t.eq(TechService.deposited(m, &"warehouse", &"steel_ingot"), 2, "记了 2 块")
	var c := _add(m, db, &"rivet_box")
	m.warehouse.remove(c.uid)
	t.check(not panel.zone().place(c, Vector2i.ZERO, 0), "上交区不收不要的（铆钉盒）")

	btn = panel.upgrade_button(&"warehouse")
	t.check(btn.disabled, "材料齐了但没钱：还是灰")
	m.funds = 600
	m.changed.emit()
	btn = panel.upgrade_button(&"warehouse")
	t.check(not btn.disabled, "交齐 + 钱够：亮")
	var pages_before := m.warehouse.page_count()
	btn.pressed.emit()
	t.eq(TechService.level(m, &"warehouse"), 4, "升到 4 级")
	t.eq(m.warehouse.page_count(), pages_before + 1, "仓库当场多一页")
	panel.queue_free()
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func frame_meta_tab(t: TestCase, root: Window) -> void:
	t.begin("110 · 基地多了第五个页签「科技」")
	var db := _db()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), _meta())
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	screen.show_tab("tech")
	t.eq(screen.tab(), "tech", "切到科技页")
	t.not_null(screen.tech_panel(), "科技页建好了")
	t.check(screen.tech_panel().visible, "科技页可见")
	screen.queue_free()
	MetaSave.remove(META)
