## 285（作者 2026-11-07 14:46 / 14:56）：开局预设扩充 —— 中栏竖排挂牌；免费 / 收费（出发时付钱、算带入预算）/ 高级（一张券换一套，出发时扣券）
extends RefCounted

const Setup := preload("res://tests/ui/test_setup_180.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "presets_285"


static func run_data(t: TestCase) -> void:
	t.begin("285 · 数据：七套预设（免费 2 / 收费 3 / 高级 2），免费在前；导入校验 tier")
	var flow := GameFlow.new(TestSupport.load_content("free_mode").items)
	flow.loadouts = GameFlow.load_loadouts()
	flow.chapters = GameFlow.load_chapters()
	var sets := flow.presets()
	var tiers: Array[StringName] = []
	for s in sets:
		tiers.append(s.tier)
	t.eq(sets.size(), 7, "七套")
	t.eq(tiers, [LoadoutDef.TIER_FREE, LoadoutDef.TIER_FREE, LoadoutDef.TIER_PAID, LoadoutDef.TIER_PAID, LoadoutDef.TIER_PAID,
			LoadoutDef.TIER_ADVANCED, LoadoutDef.TIER_ADVANCED] as Array[StringName], "免费 → 收费 → 高级")
	for s in sets:
		t.eq(Names.description_of(s) if s.tier != LoadoutDef.TIER_FREE else "", "", "%s 说明空着给作者" % s.id)
		for id in s.items:
			t.not_null(flow.items.get_def(id), "%s 的 %s 是现有道具" % [s.id, id])
	var ranger := _find(sets, &"preset_ranger")
	var want := 0
	for id in ranger.items:
		want += Market.price_of(flow.market(), flow.items.get_def(id))
	t.check(want > 0, "收费的有价钱")
	t.eq(flow.preset_price(ranger), want, "价钱 = 清单集市价之和")
	t.eq(flow.preset_price(_find(sets, &"preset_offense")), 0, "免费的 0")
	var standard := _find(sets, &"preset_standard")
	t.eq(flow.preset_price(standard), 0, "高级的不付钱")
	t.eq(flow.preset_value(standard), 0, "高级的不算预算")
	t.eq(standard.ticket, &"ticket_standard", "制式要制式券")
	t.eq(_find(sets, &"preset_elite").ticket, &"ticket_elite", "精锐要精锐券")
	for tid in [&"ticket_standard", &"ticket_elite"]:
		var tk := flow.items.get_def(tid)
		t.check(tk != null and tk.is_ticket() and tk.shape.cells.size() == 1 and tk.description == "", "%s：券、1×1、说明空着" % tid)
		t.check(not flow.items.ids().has(tid), "%s 不进掉落池与商店" % tid)
		var inst := ItemInstance.create(tk, 0)
		t.check(not ItemActions.sell(inst, 5, func(_u: int): pass).enabled, "%s 不能卖" % tid)
	t.eq(flow.preset_value(_find(sets, &"preset_offense")), 0, "免费的不算预算")
	var prologue: ChapterDef = null
	for c in flow.chapters:
		if not c.allow_carry_in:
			prologue = c
	if prologue != null:
		t.eq(flow.presets(prologue).size(), 2, "序章只列免费两套")
	# 导入校验
	t.check(_errors({"id": "x", "preset": true, "tier": "gold", "items": ["salve"]}, flow) != "", "tier 只许三个值")
	t.check(_errors({"id": "x", "tier": "paid", "items": ["salve", "sack"]}, flow) != "", "收费 / 高级只给预设套")
	t.check(_errors({"id": "x", "preset": true, "tier": "advanced", "items": ["salve"]}, flow).contains("ticket"), "高级得写券")
	t.check(_errors({"id": "x", "preset": true, "tier": "advanced", "ticket": "salve", "items": ["salve"]}, flow).contains("不是券"), "券得是带 ticket 标签的道具")
	t.check(_errors({"id": "x", "preset": true, "tier": "paid", "ticket": "ticket_elite", "items": ["salve"]}, flow) != "", "收费的不写券")
	t.eq(_errors({"id": "x", "preset": true, "tier": "advanced", "ticket": "ticket_elite", "items": ["salve"]}, flow), "", "高级 + 券过")
	var by_id := {}
	for c in flow.chapters:
		by_id[c.id] = c
	t.eq((by_id[&"free_mode"] as ChapterDef).boss_ticket, &"ticket_standard", "魔法废墟的核心 BOSS 掉制式券")
	t.eq((by_id[&"clockwork_hourglass"] as ChapterDef).boss_ticket, &"ticket_elite", "机关沙漏掉精锐券")
	for c in flow.chapters:
		if not c.allow_carry_in:
			t.eq(c.boss_ticket, &"", "%s 不掉券" % c.id)
	t.eq(_errors({"id": "x", "preset": true, "tier": "paid", "items": ["salve"]}, flow), "", "收费的正常清单过")
	t.eq(_errors({"id": "x", "preset": true, "items": ["salve"]}, flow), "", "不写 tier = 免费（老数据不改也对）")


static func _errors(data: Dictionary, flow: GameFlow) -> String:
	var ctx := ContentImporter.Context.new()
	for id in data["items"] + ([data["ticket"]] if data.has("ticket") else []):
		ctx.items[StringName(id)] = flow.items.get_def(StringName(id))
	var report := ImportReport.new()
	ContentImporter.import_loadout(data, ctx, report)
	return report.to_text() if not report.errors.is_empty() else ""


static func frame_paid(t: TestCase, root: Window) -> void:
	t.begin("285 · 收费预设：挂牌写价钱；出发时扣钱、钱不够出发灰；算带入预算；换套不重复扣")
	var game = Setup._game(root, PREFIX + "_paid")
	var flow: GameFlow = game.flow
	var setup = game.base()
	_free_mode(setup)
	setup.show_page(1)
	var col: ScrollContainer = setup._preset_scroll
	t.check(col != null and col.visible and col.get_parent() == setup._board_host.get_parent().get_parent().get_parent(), "中栏一列挂牌（和行囊板、仓库框同一行）")
	t.eq(setup._preset_btns.size(), 8, "不带 + 七套")
	t.eq((setup._preset_btns[0] as Button).text, "", "挂牌字写在牌面里")
	t.eq((setup._preset_btns[0] as PresetTag).name_label.text, UiText.t("setup.no_preset"), "第一块是「不带预设」")
	var sets: Array[LoadoutDef] = setup._preset_list()
	var ri := sets.find(_find(sets, &"preset_ranger"))
	var ranger: LoadoutDef = sets[ri]
	var price := flow.preset_price(ranger)
	var tag: PresetTag = setup._preset_btns[ri + 1]
	t.check(tag.coin != null and tag.coin.amount == price, "收费挂牌写价钱 %d" % price)
	t.is_null((setup._preset_btns[1] as PresetTag).coin, "免费挂牌没有钱")
	t.eq(tag.tooltip_text.split("\n").size(), ranger.items.size(), "悬停 = 清单")
	# 钱不够
	flow.meta.funds = price - 1
	t.check(setup.choose_preset(ri), "钱不够也能点进去看")
	t.eq(setup.preset_items().size(), ranger.items.size(), "清单都放上了棋盘")
	t.check(tag.button_pressed, "选中那块按下")
	t.eq(setup.can_depart(), UiText.t("setup.preset_poor"), "出发不了：[coin_short]")
	t.eq(setup.status_text(), UiText.t("setup.preset_poor"), "状态行写 [coin_short]（没从仓库带东西也写）")
	setup.show_page(2)
	setup._refresh()
	t.check(setup._enter_btn.disabled, "第三页出发键灰着")
	t.eq(setup.preset_summary(), UiText.t("setup.summary_preset") % Names.of(ranger), "摘要多一行「预设：游猎」")
	t.check(setup._summary_coin.visible and setup._summary_coin.amount == price, "摘要那行跟着价钱")
	# 够了
	flow.meta.funds = price + 50
	setup._refresh()
	t.check(not setup._enter_btn.disabled or setup.needs_spawn(), "钱够了出发键亮")
	t.eq(setup.cash_cap(), 50, "带入现金只能在付完之后的余额里挑")
	t.eq(setup.carry_value(), flow.preset_value(ranger), "收费预设算带入预算")
	# 换套再换回来不扣钱（出发才扣）
	setup.show_page(1)
	setup.choose_preset(0)
	setup.choose_preset(ri)
	t.eq(flow.meta.funds, price + 50, "换套不扣钱")
	setup.set_carry_funds(999)
	t.eq(setup.carry_funds, 50, "带入现金封顶在余额减价钱")
	setup.set_carry_funds(0)
	setup.show_page(2)
	setup.choose_scale(&"")
	setup.set_run_seed(7)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var ids: Array[int] = pv.entry_ids()
	if not ids.is_empty():
		setup.pick_spawn(ids[0])
		setup.close_hint()
	t.check(Support.depart(setup), "出发（%s）" % setup.can_depart())
	t.eq(flow.meta.funds, 50, "出发那一刻扣了 %d" % price)
	var on_board := 0
	for inst in flow.run.board.items():
		if ranger.items.has((inst as ItemInstance).def.id):
			on_board += 1
	t.check(on_board >= ranger.items.size(), "一局的棋盘上有游猎那几件")
	game.queue_free()


static func frame_advanced(t: TestCase, root: Window) -> void:
	t.begin("285 · 高级预设：没券灰锁选不了；有券点了新造进包、不算预算；出发扣一张券、券不退；序章不列")
	var game = Setup._game(root, PREFIX + "_adv")
	var flow: GameFlow = game.flow
	var setup = game.base()
	_free_mode(setup)
	setup.show_page(1)
	var sets: Array[LoadoutDef] = setup._preset_list()
	var standard := _find(sets, &"preset_standard")
	var si := sets.find(standard)
	var tag: PresetTag = setup._preset_btns[si + 1]
	t.check(tag.disabled and tag.lock != null, "没券：灰着加小锁")
	t.check(tag.ticket_row != null and tag.coin == null, "下行是券、不是钱")
	var tk_name := Names.of(flow.items.get_def(&"ticket_standard"))
	t.check(tag.tooltip_text.contains(tk_name), "悬停写要哪张券")
	t.eq(tag.tooltip_text.split("\n").size(), standard.items.size() + 1, "清单 + 一行券")
	t.check(not setup.choose_preset(si), "没券选不了")
	t.eq(setup.preset_index, -1, "还是不带")
	# 发两张券
	for k in 2:
		var tk := ItemInstance.create(flow.items.get_def(&"ticket_standard"), 0)
		tk.uid = flow.meta.allocate_uid()
		t.check(flow.meta.warehouse.try_add(tk, true), "仓库放进一张制式券")
	setup._rebuild_presets()
	tag = setup._preset_btns[si + 1]
	t.check(not tag.disabled and tag.lock == null, "有券：挂牌亮了")
	var n: int = flow.meta.warehouse.item_count()
	t.check(setup.choose_preset(si), "有券能选")
	t.eq(setup.preset_items().size(), standard.items.size(), "整套新造进包")
	t.eq(flow.meta.warehouse.item_count(), n, "选的时候不扣券")
	t.eq(setup.carry_value(), 0, "不算带入预算")
	t.eq(setup.preset_summary(), UiText.t("setup.summary_preset") % Names.of(standard), "摘要多一行「预设：制式」")
	t.check(not setup._summary_coin.visible, "高级的摘要不写钱")
	setup.choose_preset(-1)
	setup.choose_preset(si)
	t.eq(flow.meta.warehouse.item_count(), n, "换套不扣券")
	var funds: int = flow.meta.funds
	setup.show_page(2)
	setup.choose_scale(&"")
	setup.set_run_seed(7)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var ids: Array[int] = pv.entry_ids()
	if not ids.is_empty():
		setup.pick_spawn(ids[0])
		setup.close_hint()
	t.check(Support.depart(setup), "出发（%s）" % setup.can_depart())
	var left := 0
	for inst in flow.meta.warehouse.items():
		if (inst as ItemInstance).def.id == &"ticket_standard":
			left += 1
	t.eq(left, 1, "出发扣了一张券")
	t.eq(flow.meta.funds, funds, "不扣钱")
	t.check(flow.run.board.items().any(func(i) -> bool: return (i as ItemInstance).def.id == &"longsword"), "一局的棋盘上有制式那把长剑")
	game.queue_free()


static func frame_prologue(t: TestCase, root: Window) -> void:
	t.begin("285 · 序章只列免费两套；挑着收费的换到序章 → 换回不带")
	var game = Setup._game(root, PREFIX + "_pro")
	var flow: GameFlow = game.flow
	var setup = game.base()
	_free_mode(setup)
	setup.show_page(1)
	var sets: Array[LoadoutDef] = setup._preset_list()
	t.check(setup.choose_preset(sets.find(_find(sets, &"preset_ranger"))), "挑游猎")
	for gi in setup._chapters.size():
		if not setup._chapters[gi].allow_carry_in:
			setup.choose_chapter(gi)
			t.eq(setup._preset_list().size(), 2, "序章只列免费两套")
			t.eq(setup._preset_btns.size(), 3, "挂牌三块")
			t.is_null(setup.preset(), "收费的换回不带")
			t.eq(setup.preset_items().size(), 0, "棋盘上没有游猎的东西")
			break
	t.check(flow != null, "")
	game.queue_free()


static func run_boss_ticket(t: TestCase) -> void:
	t.begin("285 · 核心 BOSS 打赢必掉一张这一章的券；别的点不掉")
	var c := TestSupport.load_content("free_mode")
	var events := NodeEvents.new(null)
	events.items = c.items
	events.boss_ticket = &"ticket_standard"
	var got: Array = []
	events.loot_ready.connect(func(_n: MapNode, corpse: GridInventory):
		for inst in corpse.items():
			got.append((inst as ItemInstance).def.id))
	var node := MapNode.new()
	node.id = 1
	events._settle_won(node, &"core", {"items": []})
	t.check(got.has(&"ticket_standard"), "核心：掉了制式券（%s）" % [got])
	got.clear()
	events._settle_won(node, &"battle", {"items": []})
	t.check(not got.has(&"ticket_standard"), "普通战斗不掉")


static func _free_mode(setup) -> void:
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)


static func _find(sets: Array[LoadoutDef], id: StringName) -> LoadoutDef:
	for s in sets:
		if s.id == id:
			return s
	return null


static func run_ticket_bulk_sell(t: TestCase) -> void:
	t.begin("285 测试 11-07 · 券的「出售同类 ×n」也灰着写「券不能出售」、不挂价钱")
	var db := TestSupport.load_content("free_mode").items
	var g := GridInventory.new(Vector2i(4, 4), 9, false)
	var a := ItemInstance.create(db.get_def(&"ticket_standard"))
	var b := ItemInstance.create(db.get_def(&"ticket_standard"))
	t.check(g.try_add(a, true) and g.try_add(b, true), "两张制式券")
	var sold := [0]
	var act := ItemActions.sell_same(a, g, func(_i: ItemInstance) -> int: return 30, func(_u: int) -> int:
		sold[0] += 1
		return 30)
	t.check(not act.enabled and act.reason == UiText.t("act.ticket"), "灰着：券不能出售（%s）" % act.reason)
	t.eq(act.coin, -1, "不挂价钱")


static func frame_locked_tag_ink(t: TestCase, root: Window) -> void:
	t.begin("285 · 锁着的预设挂牌：名字与 ×1 按 SETUP_TAB_LOCKED_INK 原色写在木牌上，不跟页面深浅压暗（UI设计 11-07）")
	var tag := PresetTag.make("精锐", 0, null, false, true)
	root.add_child(tag)
	t.check(tag.disabled, "没券：锁着")
	t.eq(tag.name_label.get_theme_color("font_color"), UiTheme.SETUP_TAB_LOCKED_INK, "名字原色")
	t.check(not tag.name_label.has_meta(&"dark_color"), "不挂语义色重算")
	tag.free()
