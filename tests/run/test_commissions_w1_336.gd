## 336 W1（阵营与委托，报告 335 第四节）：三张原型单走真实的路 —— 出征带进去、任务信发进背包；撤离点事件的「查验」「交信」只在该出现时出现；
## 交信当场成立、之后败退也算；查验两处不同出口办成；同一处不重复；打造照选的配方记账；委托物不能卖 / 献祭 / 赐福 / 合成、不带回仓库；
## 教程没完 / 切片不显示；结算屏写清谁收到了什么、还差什么
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const T110 := preload("res://tests/meta/test_tech.gd")
const ResultScreenScript := preload("res://ui/game/result_screen.gd")
const PREFIX := "commissions_w1_336"
const TWO := &"legion_two_routes"
const LETTER := &"greylamp_unsigned_letter"
const COPY := &"society_copy_recipe"


static func _flow(c: TestSupport.Content) -> GameFlow:
	var f := Support.flow(c, PREFIX)
	f.chapters = [c.chapter] as Array[ChapterDef]
	return f


static func _extracts(run: RunState, free_only: bool = false) -> Array[MapNode]:
	var out: Array[MapNode] = []
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if n.type == &"extract" and (not free_only or PaidExtracts.fee_of(n) <= 0):
			out.append(n)
	return out


static func _letter_on(run: RunState) -> bool:
	for c in [run.board, run.storage]:
		for inst in c.items():
			if (inst as ItemInstance).def.id == &"commission_letter":
				return true
	return false


static func run_loop(t: TestCase) -> void:
	t.begin("336 W1 · 第四节的循环：同时接《两条回路》和《无人署名的信》→ 信发进背包 → 交信当场成立 → 查一处出口后败退 → 回营灰灯已办成、军士还差一处，结算各写一句")
	var c := TestSupport.load_content("free_mode")
	var f := _flow(c)
	t.check(f.commissions_visible(), "没有教程章、不是切片：委托簿露出来")
	t.eq(f.take_commission(TWO), "", "接《两条回路》")
	t.eq(f.take_commission(LETTER), "", "接《无人署名的信》")
	t.eq(f.take_commission(COPY, &"x"), Commissions.WHY_SLOTS, "第三份没位")
	var s := f.begin_direct(c.chapter, 23)
	t.not_null(s, "开局")
	if s == null:
		return
	var mod := CommissionModule.of(s)
	t.not_null(mod, "委托模块装上了")
	t.eq(mod.tracked.size(), 2, "两份都带进来")
	t.check(_letter_on(s), "任务信发进背包（或脚下）")
	var exits := _extracts(s)
	var free := _extracts(s, true)
	t.check(exits.size() >= 2 and not free.is_empty(), "图上至少两处撤离点、有免费的")
	if exits.size() < 2 or free.is_empty():
		return
	var other: MapNode = null
	for n in exits:
		if n != free[0]:
			other = n
			break
	# 交信：事件选项只在能交时出现
	var ctx_hooks := s.hooks
	t.check(ctx_hooks.commission_can(CommissionModule.DELIVER, free[0]), "免费撤离点、信在身上：能交信")
	if other != null and PaidExtracts.fee_of(other) > 0:
		t.check(not ctx_hooks.commission_can(CommissionModule.DELIVER, other), "付费撤离点不收信")
	var got := ctx_hooks.commission_act(CommissionModule.DELIVER, free[0])
	t.eq(got.size(), 1, "交了一封")
	t.check(not _letter_on(s), "信从身上拿走了")
	t.check(not ctx_hooks.commission_can(CommissionModule.DELIVER, free[0]), "交过就不再出现")
	# 查验：同一处只记一次
	t.check(ctx_hooks.commission_can(CommissionModule.INSPECT, free[0]), "能查验")
	ctx_hooks.commission_act(CommissionModule.INSPECT, free[0])
	t.check(not ctx_hooks.commission_can(CommissionModule.INSPECT, free[0]), "这处查过，不再出现")
	t.eq(mod.progress(TWO, 0), 1, "查了一处")
	var line := mod.lines().filter(func(r: Dictionary) -> bool: return String(r["id"]) == String(TWO))
	t.eq([int(line[0]["done"]), int(line[0]["need"])] if not line.is_empty() else [], [1, 2], "小牌：1 / 2")
	# 读档：进度跟这一局的存档走
	var saved := s.to_dict()
	var back := CommissionModule.new()
	back.restore((saved["modules"] as Dictionary).get("commission", {}))
	t.eq(back.rows.size(), 2, "读档回来两条进度都在")
	# 败退
	s.fail(&"time_out")
	f._settle_run()
	var book := f.meta.commissions
	t.check(book.is_done(LETTER), "灰灯：交了就算，败退也办成")
	t.eq(book.rep_of(&"greylamp"), 1, "灰灯声望 +1")
	t.eq(book.state_of(TWO), CommissionBook.TAKEN, "军团：还接着")
	t.eq(int(book.entry(TWO)["progress"]), 1, "军团：记了一处")
	var lines: Array[String] = ResultScreenScript.commission_lines(f.last_commissions, f.meta)
	t.eq(lines.size(), 2, "结算两句")
	t.check(lines.has(UiText.t("commission.rcpt_done") % Names.of(Commissions.def(LETTER))), "写「无人署名的信：办成了」")
	t.check(lines.has(UiText.t("commission.res_left") % [Names.of(Commissions.def(TWO)), 1]), "写「两条回路：还差 1 处」")
	f._settle_run()
	t.eq(int(book.entry(TWO)["progress"]), 1, "重复结算不重复记账")
	# 第二局：换一处出口查完
	var s2 := f.begin_direct(c.chapter, 23)
	t.not_null(s2, "第二局")
	if s2 == null:
		return
	t.check(not _letter_on(s2), "信送到了：不再发")
	var exits2 := _extracts(s2)
	var picked: MapNode = exits2[1] if exits2.size() > 1 else exits2[0]
	s2.hooks.commission_act(CommissionModule.INSPECT, picked)
	s2.fail(&"time_out")
	f.result = null
	f._settled = false
	f._settle_run()
	t.check(book.is_done(TWO), "军团：两处查完办成")
	t.eq(book.rep_of(&"legion"), 2, "军团声望 +2")


static func run_event_options(t: TestCase) -> void:
	t.begin("336 W1 · 撤离点事件：没带委托时只有「撤离」「再看看」；带着查验的委托多一项「查验这处出口」，选了记一处、回到同一个事件")
	var ev := load("res://data/events/extract_default.tres") as EventDef
	t.not_null(ev, "撤离点事件")
	if ev == null:
		return
	t.eq(ev.options.size(), 5, "五项（后三项不满足就不显示；第五项是托付）")
	t.check(ev.options[2].hide_when_locked and ev.options[3].hide_when_locked, "查验 / 交信不满足就不显示")
	t.check(ev.options[1].outcomes.any(func(o) -> bool: return o is RevisitLater), "第二项仍是「再看看」")
	var c := TestSupport.load_content("free_mode")
	var f := _flow(c)
	var s := f.begin_direct(c.chapter, 31)
	var node := _extracts(s)[0]
	var ctx := EventContext.new()
	ctx.node = node
	ctx.hooks = s.hooks
	t.check(not ev.options[2].requires[0].check(ctx), "没带委托：查验不显示")
	var f2 := _flow(c)
	f2.take_commission(TWO)
	var s2 := f2.begin_direct(c.chapter, 31)
	ctx.hooks = s2.hooks
	ctx.node = _extracts(s2)[0]
	t.check(ev.options[2].requires[0].check(ctx), "带着《两条回路》：查验显示")
	t.check(not ev.options[3].requires[0].check(ctx), "没带信：交信不显示")
	for o in ev.options[2].outcomes:
		(o as EventOutcome).apply(ctx)
	t.eq(CommissionModule.of(s2).progress(TWO, 0), 1, "选了记一处")
	t.eq(ctx.next_event, &"extract_default", "回到同一个事件（还能撤）")
	t.check(not ctx.log.is_empty(), "结果页写一句")


static func run_forge_credit(t: TestCase) -> void:
	t.begin("336 W1 · 《照抄也要做得出》：接单时只能选现在打得出的配方；打的是选的那张才算，成品归玩家，酬金只补劳动")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := _flow(c)
	f.smith_recipes = SmithRecipeDef.load_all()
	t.eq(f.take_commission(COPY), Commissions.WHY_PICK, "没选配方不能接")
	f.meta.funds = 100000
	var picks := f.commission_picks()
	if picks.is_empty():
		# 仓库里塞齐第一张配方的料
		var r0: SmithRecipeDef = f.sorted_smith_recipes()[0] if not f.sorted_smith_recipes().is_empty() else null
		if r0 != null:
			for key in r0.inputs:
				for _i in int(r0.inputs[key]):
					T110._add(f.meta, c.items, StringName(String(key)))
		picks = f.commission_picks()
	t.check(not picks.is_empty(), "有能打的配方（%d 张）" % picks.size())
	if picks.is_empty():
		return
	t.eq(f.take_commission(COPY, &"no_such_recipe"), Commissions.WHY_PICK, "选的不在能打的里不能接")
	t.eq(f.take_commission(COPY, picks[0]), "", "选一张能打的接下")
	var funds0 := f.meta.funds
	var before := f.meta.warehouse.item_count()
	t.eq(f.forge(picks[0]), "", "照选的那张打一次")
	t.check(f.meta.commissions.is_done(COPY), "办成")
	t.eq(f.meta.commissions.rep_of(&"society"), 1, "协会声望 +1")
	var r := SmithRecipeDef.find(f.smith_recipes, picks[0])
	t.eq(f.meta.funds - funds0, Commissions.def(COPY).funds - r.funds, "酬金只补劳动（扣掉工钱再加酬金）")
	t.check(f.meta.warehouse.item_count() > 0 and before >= 0, "成品进了仓库")


static func run_quest_item_rules(t: TestCase) -> void:
	t.begin("336 W1 · 委托物：不能卖、不献祭、不赐福、不合成、不进随机来源、不带回仓库")
	var c := TestSupport.load_content("free_mode")
	var def := c.items.get_def(&"commission_letter")
	t.not_null(def, "任务信有定义")
	if def == null:
		return
	t.check(def.is_commission(), "带委托物标签")
	t.eq(def.description, "", "说明留空给作者写")
	t.check(not c.items.ids().has(&"commission_letter"), "不进随机来源")
	var inst := ItemInstance.create(def)
	t.check(ItemActions.sell(inst, 10, func(_u): return 0).enabled == false, "出售键灰着")
	t.check(not Blessings.eligible(def), "不受赐福")
	var rule := OfferingRule.new()
	t.check(not rule.matches(def), "献祭规则不认它")
	var f := _flow(c)
	f.take_commission(LETTER)
	var s := f.begin_direct(c.chapter, 41)
	var crafting := CraftingModule.of(s)
	var letter: ItemInstance = null
	for inst2 in s.board.items() + s.storage.items():
		if (inst2 as ItemInstance).def.id == &"commission_letter":
			letter = inst2
	t.not_null(letter, "信在身上")
	if letter == null:
		return
	if crafting != null:
		t.check(not crafting.partner_ok(letter, letter), "不参与合成")
	s.boss_cleared = true
	t.check(s.extract_after_boss(), "撤离（借 BOSS 倒下的直撤）")
	var r := RunResult.settle(s)
	t.check(not r.carried.any(func(i: ItemInstance) -> bool: return i.def.is_commission()), "不带回仓库")


static func run_hidden(t: TestCase) -> void:
	t.begin("336 W1 · 统一教程没走完、试玩切片：委托簿不露、出征不带委托")
	var c := TestSupport.load_content("free_mode")
	var f := _flow(c)
	var tut := ChapterDef.new()
	tut.id = &"t336_tut"
	tut.hidden_by_unlock = &"t336_done"
	f.chapters = [c.chapter, tut] as Array[ChapterDef]
	t.check(not f.commissions_visible(), "教程没走完：不露")
	t.eq(f.take_commission(LETTER), Commissions.WHY_HIDDEN, "接不了")
	f.meta.grant_unlock(&"t336_done")
	t.check(f.commissions_visible(), "教程走完：露出来")
	f.profile = SliceProfile.SLICE
	t.check(not f.commissions_visible(), "切片档案：不露")
	t.check(not SliceProfile.keeps_tab(SliceProfile.SLICE, "commissions"), "切片基地不列委托页")
