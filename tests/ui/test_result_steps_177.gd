## 177：结算屏拆两步（撤离：先大字看账，再置入仓库；战败一步）；补 1.1 一键置入放不下的跳过、接着放；
## 补 1.2 一键出售按标签筛（和稀有度取交集，下拉只列仓库里有的、给玩家看的标签）
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const WarehousePanel := preload("res://ui/game/warehouse_panel.gd")


static func _defs(c) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for id in c.items.all_ids():
		var d: ItemDef = c.items.get_def(id)
		if not d.is_bag:
			out.append(d)
	return out


static func _place(inv: Variant, def: ItemDef, at: Vector2i) -> ItemInstance:
	var inst := ItemInstance.create(def)
	return inst if inv.place(inst, at, 0) else null


static func run_store_skips(t: TestCase) -> void:
	t.begin("177 补 1.1 · 一键置入：中间那件放不下就跳过，后面的照放；全放不下名字全列；提示最多列三个")
	var c = NodeScreens._content()
	var small: ItemDef = null
	var big: ItemDef = null
	for d in _defs(c):
		var s := d.shape.size_rotated(0)
		if s == Vector2i.ONE and small == null:
			small = d
		elif s.x >= 2 and s.y >= 2 and big == null:
			big = d
	if small == null or big == null:
		t.check(false, "道具库里找不到 1×1 与 2×2 以上各一件")
		return
	var rules := MetaRules.new()
	rules.warehouse_size = Vector2i(2, 1)     # 只放得下两件 1×1
	var m := MetaState.new(rules)
	m.board = GridInventory.new(Vector2i(8, 4), 0, false)
	var a := _place(m.board, small, Vector2i(0, 0))
	var b := _place(m.board, big, Vector2i(1, 0))
	var cc := _place(m.board, small, Vector2i(5, 0))
	t.check(a != null and b != null and cc != null, "棋盘上一排三件：小、大、小")
	var got := m.store_all()
	t.eq(int(got["moved"]), 2, "放进两件小的")
	t.eq(int(got["left"]), 1, "剩一件")
	t.eq(got["stuck_names"], [Names.of_item(b)], "卡住的是大的那件")
	t.eq(String(got["stuck"]), Names.of_item(b), "stuck 仍是第一件放不下的名字")
	t.check(m.board != null and m.board.has_item(b.uid) and not m.board.has_item(cc.uid), "大的留在棋盘上，后面那件进了仓库")

	var full := MetaState.new(rules)
	full.board = GridInventory.new(Vector2i(10, 4), 0, false)
	var names: Array = []
	for i in 2:
		var inst := ItemInstance.create(big)
		if full.board.try_add(inst, false) and not names.has(Names.of_item(inst)):
			names.append(Names.of_item(inst))
	var none := full.store_all()
	t.eq(int(none["moved"]), 0, "全放不下：一件没进")
	t.eq(none["stuck_names"], names, "名字全列、不重复")
	t.check(full.board != null, "搬不动的棋盘照旧留着")

	var line := WarehousePanel.store_text({"moved": 1, "left": 5, "stuck": "甲", "stuck_names": ["甲", "乙", "丙", "丁"]})
	t.eq(line, "放进 1 件；仓库放不下 5 件（甲、乙、丙等）—— 挪一挪仓库，或者不要了", "最多列三个，多的写「等」")
	t.eq(WarehousePanel.store_text({"moved": 3, "left": 0, "stuck": "", "stuck_names": []}), "放进 3 件", "全放进：只说件数")


static func frame_sell_by_tag(t: TestCase, root: Window) -> void:
	t.begin("177 补 1.2 · 一键出售按标签筛：和稀有度取交集；下拉只列仓库里有的、给玩家看的标签；那类卖光了回「不限」")
	var c = NodeScreens._content()
	var f := Support.flow(c, "s177s", 10000.0)
	# 挑一个给玩家看的标签 X：两件带它、一件不带
	var tag: StringName = &""
	var with_tag: Array[ItemDef] = []
	var without: ItemDef = null
	for d in _defs(c):
		if d.shape.size_rotated(0) != Vector2i.ONE:
			continue
		var shown := TagRegistry.shown(d.tags)
		if tag == &"" and not shown.is_empty():
			tag = StringName(String(shown[0]))
		if tag != &"" and d.tags.has(tag) and with_tag.size() < 2:
			with_tag.append(d)
		elif tag != &"" and not d.tags.has(tag) and without == null:
			without = d
	if with_tag.size() < 2 or without == null:
		t.check(false, "道具库里找不到带同一标签的两件 1×1 与一件不带的")
		return
	for d in [with_tag[0], with_tag[1], without]:
		t.check(_place_any(f.meta.warehouse, d), "仓库里放进「%s」" % Names.of(d))
	var ratio := f.sell_ratio()
	t.eq(int(f.meta.sell_preview(-1, ratio, tag)["count"]), 2, "「全部」+ 标签：两件")
	t.eq(int(f.meta.sell_preview(-1, ratio)["count"]), 3, "不限标签：三件")
	for cap in range(0, 5):
		var expect := 0
		for d in with_tag:
			if d.rarity <= cap:
				expect += 1
		t.eq(int(f.meta.sell_preview(cap, ratio, tag)["count"]), expect, "稀有度 ≤ %d 且带标签：%d 件（交集）" % [cap, expect])
	var tags := f.meta.sell_tags()
	t.check(tags.has(tag), "下拉列出了 %s" % tag)
	var internal := false
	for x in tags:
		internal = internal or TagRegistry.is_internal(StringName(String(x)))
	t.check(not internal, "不列内部标签")
	var present := {}
	for inst in f.meta.warehouse.items():
		for x in TagRegistry.shown((inst as ItemInstance).def.tags):
			present[x] = true
	t.eq(tags.size(), present.size(), "只列仓库里有的（%d 个）" % present.size())

	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	screen.show_tab("sell")
	t.eq(screen.sell_filter_tag(), &"", "默认不限标签")
	t.eq(screen.sell_tag_options(), tags, "下拉的选项 = 仓库里有的标签，按大类排")
	screen.set_sell_filter(screen.SELL_FILTERS.size() - 1)
	screen.set_sell_tag(tag)
	t.eq(screen.sell_filter_tag(), tag, "选中标签")
	t.check(screen.sell_preview_text().contains("2 件"), "预览按标签（%s）" % screen.sell_preview_text())
	var sold: Dictionary = screen.sell_filtered()
	t.eq(int(sold["count"]), 2, "一键卖掉带标签的两件")
	t.eq(f.meta.warehouse.item_count(), 1, "不带的那件还在")
	t.eq(screen.sell_filter_tag(), &"" if not f.meta.sell_tags().has(tag) else tag, "那类卖光了：回「不限」")
	t.check(not screen.sell_tag_options().has(tag) or f.meta.sell_tags().has(tag), "下拉里也没了")
	screen.queue_free()
	Support.cleanup("s177s")


static func _place_any(inv: Variant, def: ItemDef) -> bool:
	var inst := ItemInstance.create(def)
	for y in inv.size.y:
		for x in inv.size.x:
			if inv.place(inst, Vector2i(x, y)):
				return true
	return false


static func _extracted_result(gun: ItemDef) -> RunResult:
	var r := RunResult.new()
	r.outcome = &"extracted"
	r.reason = &"extract"
	r.chapter_name = "自由模式"
	r.run_seed = 87326
	r.value = 953
	r.balance = 153
	r.carried = [ItemInstance.create(gun), ItemInstance.create(gun)] as Array[ItemInstance]
	r.safe_items = [ItemInstance.create(gun)] as Array[ItemInstance]
	r.safe_value = 40
	r.safe_layout = [{"def": gun, "origin": Vector2i.ZERO, "rotation": 0}] as Array[Dictionary]
	r.left_behind = 2
	r.left_value = 30
	return r


static func _buttons(screen: Node, prefix: String) -> Array[Button]:
	var out: Array[Button] = []
	for b: Button in screen.find_children("*", "Button", true, false):
		if b.text.begins_with(prefix):
			out.append(b)
	return out


static func frame_result_steps(t: TestCase, root: Window) -> void:
	t.begin("177 · 结算屏：撤离第 1 步三块大数（总价值 = 背出来 + 保险箱）、没有仓库；「继续」→ 第 2 步有仓库与保险箱格；战败一步")
	var c = NodeScreens._content()
	var f := Support.flow(c, "s177r", 10000.0)
	var gun: ItemDef = _defs(c)[0]
	var r := _extracted_result(gun)
	f.last_absorbed = {"lit": 7}
	var screen = load("res://ui/game/result_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.RESULT
	root.add_child(screen)
	screen.open({"result": r})
	t.eq(screen.step(), 1, "第 1 步")
	var nums: Dictionary = screen.numbers()
	t.eq(nums.keys(), ["总价值", "图鉴新点亮", "带出金币"], "三块大数")
	t.eq((nums.get("总价值") as Label).text if nums.has("总价值") else "", "993", "总价值 = 953 + 40（待定 1 选 A）")
	t.eq((nums.get("图鉴新点亮") as Label).text if nums.has("图鉴新点亮") else "", "7", "图鉴新点亮")
	t.eq((nums.get("带出金币") as Label).text if nums.has("带出金币") else "", "153", "带出金币")
	t.eq((nums["总价值"] as Label).get_theme_font_size("font_size"), screen.BIG_NUMBER_PX, "总价值用大号")
	t.eq((nums["带出金币"] as Label).get_theme_font_size("font_size"), screen.NUMBER_PX, "其余用中号")
	t.eq(screen.get("_wh"), null, "第 1 步没有仓库面板")
	t.eq(screen.safe_view(), null, "第 1 步没有保险箱格")
	t.check(screen._stash_line != null and screen._stash_line.text.contains("一键出售"), "遗落提示在第 1 步")
	t.eq(_buttons(screen, "继续").size(), 1, "一个「继续」")
	var before: int = f.screen
	_buttons(screen, "继续")[0].pressed.emit()
	t.eq(f.screen, before, "第 1 步的继续不离开这一屏")
	t.eq(screen.step(), 2, "按「继续」→ 第 2 步")
	t.check(screen.get("_wh") != null, "第 2 步有仓库面板")
	t.check(screen.safe_view() != null, "第 2 步有保险箱格")
	t.check(screen.numbers().is_empty(), "第 2 步不画大数")
	var head := false
	for l: Label in screen.find_children("*", "Label", true, false):
		head = head or l.text == "总价值 993 · 带出 153 币"
	t.check(head, "顶上回看一行账（待定 2 选 A）")
	var cont := _buttons(screen, "继续") + _buttons(screen, "进入下一张")
	t.eq(cont.size(), 1, "第 2 步一个离开的按钮")
	t.check(screen.store_all() is Dictionary, "store_all 可用")
	screen.queue_free()

	var d := RunResult.new()
	d.outcome = &"defeated"
	d.reason = &"vitality_depleted"
	d.safe_items = [ItemInstance.create(gun)] as Array[ItemInstance]
	d.safe_value = 40
	d.safe_layout = [{"def": gun, "origin": Vector2i.ZERO, "rotation": 0}] as Array[Dictionary]
	f.last_absorbed = {"lit": 0}
	var lost = load("res://ui/game/result_screen.gd").new()
	lost.flow = f
	lost.font = UiPalette.cjk_font()
	root.add_child(lost)
	lost.open({"result": d})
	t.eq(lost.numbers().keys(), ["保险箱带出"], "战败只画保险箱那块")
	t.check(lost.safe_view() != null and is_equal_approx(lost.safe_view().cell_px, 60.0), "保险箱居中放大，一步就有")
	lost.to_step(2)
	t.eq(lost.numbers().keys(), ["保险箱带出"], "战败没有第 2 步：还是那一屏")
	lost.queue_free()
	Support.cleanup("s177r")
