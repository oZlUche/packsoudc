## 285（作者 2026-11-07 14:46）：开局预设扩充 —— 中栏竖排挂牌；免费 / 收费（出发时付钱、算带入预算）/ 高级（清单每件都得在仓库，选了从仓库拉）
extends RefCounted

const Setup := preload("res://tests/ui/test_setup_180.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "presets_285"


static func run_data(t: TestCase) -> void:
	t.begin("285 · 数据：七套预设（免费 2 / 收费 3 / 高级 2），免费在前；导入校验 tier")
	var flow := GameFlow.new()
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
	t.eq(flow.preset_price(_find(sets, &"preset_steel")), 0, "高级的不付钱")
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
	t.check(_errors({"id": "x", "preset": true, "tier": "advanced", "items": ["poxiao_token"]}, flow).contains("poxiao_token"), "高级清单不许有独一件")
	t.eq(_errors({"id": "x", "preset": true, "tier": "paid", "items": ["salve"]}, flow), "", "收费的正常清单过")
	t.eq(_errors({"id": "x", "preset": true, "items": ["salve"]}, flow), "", "不写 tier = 免费（老数据不改也对）")


static func _errors(data: Dictionary, flow: GameFlow) -> String:
	var ctx := ContentImporter.Context.new()
	for id in data["items"]:
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
	t.begin("285 · 高级预设：缺件灰锁选不了、悬停缺的红字；齐了从仓库拉；拖回去就是放回；换套放回仓库；序章不列")
	var game = Setup._game(root, PREFIX + "_adv")
	var flow: GameFlow = game.flow
	var setup = game.base()
	_free_mode(setup)
	setup.show_page(1)
	var sets: Array[LoadoutDef] = setup._preset_list()
	var steel := _find(sets, &"preset_steel")
	var si := sets.find(steel)
	# 先清掉仓库里清单上的东西
	for inst in flow.meta.warehouse.items():
		if steel.items.has((inst as ItemInstance).def.id):
			flow.meta.warehouse.remove((inst as ItemInstance).uid)
	setup._rebuild_presets()
	var tag: PresetTag = setup._preset_btns[si + 1]
	t.check(tag.disabled, "缺件：灰着")
	t.check(tag.short_label != null and tag.short_label.text.contains(str(steel.items.size())), "「缺 %d 件」" % steel.items.size())
	t.check(not setup.choose_preset(si), "缺件选不了")
	t.eq(setup.preset_index, -1, "还是不带")
	# 只缺最后那件伤药
	var uids: Array[int] = []
	for k in steel.items.size() - 1:
		var inst := ItemInstance.create(flow.items.get_def(steel.items[k]), 0)
		inst.uid = flow.meta.allocate_uid()
		t.check(flow.meta.warehouse.try_add(inst, true), "仓库放进 %s" % steel.items[k])
		uids.append(inst.uid)
	t.eq(setup.preset_missing_of(steel).size(), 1, "缺一件")
	setup._rebuild_presets()
	tag = setup._preset_btns[si + 1]
	var flags: Array[bool] = tag.missing_flags()
	t.eq(flags.count(true), 1, "悬停只有一行红字")
	t.check(flags[flags.size() - 1], "红的是最后那件伤药")
	var tip: RichTextLabel = tag._make_custom_tooltip("")
	t.check(tip != null and tip.text.contains("[color="), "悬停是富文本、缺的上色")
	t.check(not setup.choose_preset(si), "缺一件也选不了")
	var last := ItemInstance.create(flow.items.get_def(steel.items[steel.items.size() - 1]), 0)
	last.uid = flow.meta.allocate_uid()
	flow.meta.warehouse.try_add(last, true)
	uids.append(last.uid)
	t.eq(setup.preset_missing_of(steel).size(), 0, "齐了")
	var n: int = flow.meta.warehouse.item_count()
	t.check(setup.choose_preset(si), "齐了能选")
	var pulled: int = setup._advanced_uids.size()
	t.check(pulled > 0, "从仓库拉了 %d 件（包里放不下的留在仓库、状态栏说）" % pulled)
	t.eq(flow.meta.warehouse.item_count(), n - pulled, "仓库少了拉走的那几件")
	t.eq(setup.preset_items().size(), 0, "高级的不是新造的")
	t.eq(setup.carried().size(), pulled, "拉上来的就是普通带入")
	var v := 0
	for inst in setup.carried():
		v += ItemValue.of((inst as ItemInstance).def)
	t.eq(setup.carry_value(), v, "算带入预算（同手拖）")
	t.eq(setup.preset_missing_of(steel).size(), 0, "选着的那套不算缺")
	t.check(setup.carry_out(setup.carried()[0].uid), "拖回仓库 = 放回")
	t.eq(flow.meta.warehouse.item_count(), n - pulled + 1, "回了一件")
	setup.choose_preset(-1)
	t.eq(flow.meta.warehouse.item_count(), n, "换回不带：拉上来的都放回仓库")
	t.eq(setup.carried().size(), 0, "棋盘上没有了")
	t.check(setup.choose_preset(si), "再选一次")
	# 换到序章：高级的不列，自动换回不带、东西放回仓库
	for gi in setup._chapters.size():
		if not setup._chapters[gi].allow_carry_in:
			setup.choose_chapter(gi)
			t.eq(setup._preset_list().size(), 2, "序章只列免费两套")
			t.is_null(setup.preset(), "高级的换回不带")
			t.eq(flow.meta.warehouse.item_count(), n, "东西都回了仓库")
			break
	game.queue_free()


static func _free_mode(setup) -> void:
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)


static func _find(sets: Array[LoadoutDef], id: StringName) -> LoadoutDef:
	for s in sets:
		if s.id == id:
			return s
	return null
