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
	r.visited = 12
	r.steps = 37
	r.battles_won = 5
	r.elite_won = 1
	r.battles_lost = 1
	r.searches = 4
	r.crafts = 2
	return r


static func _buttons(screen: Node, prefix: String) -> Array[Button]:
	var out: Array[Button] = []
	for b: Button in screen.find_children("*", "Button", true, false):
		if b.text.begins_with(prefix):
			out.append(b)
	return out


static func frame_result_steps(t: TestCase, root: Window) -> void:
	t.begin("177 / 224 · 结算屏：撤离第 1 步是逐行账单（十一行 + 合计，全显前「继续」不可点）+ 保险箱、没有仓库；「继续」→ 第 2 步有仓库；战败一步、没有保险箱")
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
	var ledger: LedgerView = screen.ledger()
	t.not_null(ledger, "有账单")
	var keys: Array = []
	for row in ledger.rows():
		keys.append(row["key"])
	t.eq(keys, ["visited", "steps", "defeated", "elite", "boss", "lost", "search_craft", "lit", "carried", "rarity", "coins", "total"], "十一行 + 合计（224 补充二：击败的敌人 / 精英 / 首领分三行）")
	var nums: Dictionary = screen.numbers()
	t.eq(nums.get("走过的点"), "12", "走过的点")
	t.eq(nums.get("走了多少步"), "37", "步数")
	t.eq(nums.get("击败的敌人"), "4", "击败的敌人 = 5 场胜 − 1 精英 − 0 首领")
	t.eq(nums.get("击败的精英"), "1", "精英一行")
	t.eq(nums.get("击败的首领"), "0", "首领一行")
	t.eq(nums.get("翻过的搜索点 · 合成"), "4 · 2", "搜索点 · 合成")
	t.eq(nums.get("图鉴新点亮"), "7", "图鉴新点亮")
	t.eq(nums.get("带出的东西"), "2 件 · 保险箱 1 件", "带出的东西一行写件数")
	t.eq(nums.get("最高稀有度"), ItemTooltip.rarity_name(gun.rarity), "最高稀有度写稀有度名")
	t.eq(nums.get("带出金币"), "153", "带出金币")
	t.eq(nums.get("总分"), "993", "总分 = 953 + 40（177 待定 1 选 A；224 补充三改名）")
	t.check(not ledger.is_revealed() and not ledger.rows()[0]["shown"], "进屏时还没显出")
	var plate := screen.find_child("TitlePlate", true, false) as TextureRect
	t.check(plate != null and plate.texture != null, "224（作者 16:32）：标题刻在标题牌上")
	t.check(screen.continue_button() != null and screen.continue_button().disabled, "全显之前「继续」不可点")
	t.eq(LedgerView.text_at(ledger._rows[0], 0.5), "6", "数字从零滚到实值（一半时 6）")
	ledger.reveal_all()
	t.check(ledger.is_revealed() and ledger.rows()[11]["shown"], "点一下：全显")
	t.check(not screen.continue_button().disabled, "全显后「继续」可点")
	t.eq(screen.get("_wh"), null, "第 1 步没有仓库面板")
	t.check(screen.safe_view() != null and screen.find_child("SafeFrame", true, false) != null, "224 补充二：第 1 步账单右边有保险箱（皮带框）")
	t.eq(_buttons(screen, "继续").size(), 1, "一个「继续」")
	var before: int = f.screen
	_buttons(screen, "继续")[0].pressed.emit()
	t.eq(f.screen, before, "第 1 步的继续不离开这一屏")
	t.eq(screen.step(), 2, "按「继续」→ 第 2 步")
	t.check(screen.get("_wh") != null, "第 2 步有仓库面板")
	t.eq(screen.safe_view(), null, "224 补充二：第 2 步不再有保险箱格")
	t.eq(screen.find_children("*", "HSeparator", true, false).size(), 0, "224 补充二：中间的分隔横线删了")
	t.check(screen.numbers().is_empty(), "第 2 步没有账单")
	var wh = screen.get("_wh")
	var bare := []
	for l: Label in screen.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text.contains("993"):
			bare.append(l.text)
	t.eq(bare, [], "224（作者 16:32）：顶上那行账删了")
	t.check(not "_line" in wh and not "_size_label" in wh and not "_board_label" in wh, "224 / 226 批二：两块棋盘上面与底下的说明字删了")
	var cont := _buttons(screen, "继续")
	t.eq(cont.size(), 1, "第 2 步一个离开的按钮")
	if cont.size() == 1:
		var row := cont[0].get_parent()
		t.check(row is HBoxContainer and _buttons(row, "一键置入").size() == 1 and _buttons(row, "整理").size() == 1, "224：一键置入、整理、继续同一行")
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
	t.eq(lost.numbers().get("带出的东西"), "保险箱 1 件", "224：战败同一张账单，带出的东西只有保险箱那半句")
	t.eq(lost.numbers().get("总分"), "40", "总分 = 保险箱")
	t.eq(lost.numbers().get("带出金币"), "0", "钱没了")
	t.eq(lost.safe_view(), null, "224 补充二：战败不显示保险箱")
	var said: Array = []
	for l: Label in lost.find_children("*", "Label", true, false):
		if l.text.contains("全都留在") or l.text.contains("保险箱带出"):
			said.append(l.text)
	t.eq(said, [], "224 补充二：战败没有「全丢了」「保险箱带出」那两句")
	lost.to_step(2)
	t.check(lost.ledger() != null and lost.safe_view() == null, "战败没有第 2 步：还是那一屏")
	lost.queue_free()
	# 224 补充二：战败但带回来的背包里有东西（保险箱放不下仓库的）→ 也不开第 2 步，基地「仓库」页清
	f.meta.board = GridInventory.new(Vector2i(3, 3), 0, false)
	f.meta.board.try_add(ItemInstance.create(gun), true)
	var lost2 = load("res://ui/game/result_screen.gd").new()
	lost2.flow = f
	lost2.font = UiPalette.cjk_font()
	root.add_child(lost2)
	lost2.open({"result": d})
	t.check(not lost2._has_store_step(), "战败 + 带回来的背包有东西：仍然没有第 2 步")
	lost2.queue_free()
	f.meta.board = null
	Support.cleanup("s177r")
