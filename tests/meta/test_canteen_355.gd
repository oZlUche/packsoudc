## 355 第一批：灰灯食堂 —— 灰灯到受托（25）+ 剧情《开伙》开后勤「食堂」，带食材仓库与锅（只收「食材」）；
## 一锅 = 四类各管一种属性、固定值和百分比分开相加、主食给饱腹；出征吃掉一锅（[MealModule]），每到新节点饱腹减 1，归零加成失效
## （负重那份多留一步）；水果的回血是独立一项（[member CombatantSpec.meal_regen_hp]）
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const Support := preload("res://tests/run/flow_support.gd")
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const PREFIX := "canteen_355"


static func _done(book: CommissionBook, ids: Array) -> void:
	for id in ids:
		book.entries[String(id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}


## 灰灯到受托、许可单办过，办《开伙》
static func _open(f: GameFlow) -> void:
	_done(f.meta.commissions, [&"greylamp_unsigned_letter", &"greylamp_check_scale", &"greylamp_check_medkits", &"greylamp_permit"])
	f.meta.commissions.rep["greylamp"] = 25
	f.sync_commissions()
	f.report_commission(&"greylamp_canteen")


static func _inst(db: ItemDatabase, id: StringName, uid: int) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id))
	inst.uid = uid
	return inst


static func run_content(t: TestCase) -> void:
	t.begin("355 · 内容：食材表导得进来、带「食材」标签的都在表里；成品食物不是食材；锅 4/4/4/5/6、仓库 6×6/8×8/10×8；《开伙》要受托、开食堂")
	var r := Canteen.load_rules()
	t.eq(r.id, CanteenRules.ID, "规矩资产导出来了")
	t.eq(r.entries.size(), 16, "第一批 16 件（每类一格、两格各两件，固定值、百分比各一件）")
	var db := T110._db()
	var tagged: Array = []
	for id in db.ids(true):
		if Canteen.is_ingredient(db.get_def(id)):
			tagged.append(String(id))
	tagged.sort()
	var keys: Array = r.entries.keys()
	keys.sort()
	t.eq(tagged, keys, "带「食材」标签的 = 表里的")
	for id in [&"ration", &"salted_meat", &"field_rations", &"wolf_heart", &"dried_herbs"]:
		t.check(not Canteen.is_ingredient(db.get_def(id)), "%s 不是食材" % id)
	for cat in CanteenRules.CATEGORIES:
		var flat := 0
		var pct := 0
		for k in r.entries:
			if StringName(String(r.entries[k]["category"])) == cat:
				if (r.entries[k] as Dictionary).has("flat"):
					flat += 1
				else:
					pct += 1
		t.eq([flat, pct], [2, 2], "%s：固定值两件、百分比两件" % cat)
	t.eq([r.pot_size(2), r.pot_size(3), r.pot_size(4)], [Vector2i(4, 4), Vector2i(5, 5), Vector2i(6, 6)], "锅：受托 4×4、信赖 5×5、代言 6×6")
	t.eq([r.store_size(2), r.store_size(3), r.store_size(4)], [Vector2i(6, 6), Vector2i(8, 8), Vector2i(10, 8)], "食材仓库：6×6、8×8、10×8")
	t.eq(float(r.entry(&"wild_berry")["flat"]), 0.5, "野莓每秒 0.5（作者 16:41）")
	var bad := ImportReport.new()
	ContentImporter.import_canteen_rules({"id": "canteen", "entries": {"x": {"category": "soup", "flat": 1, "pct": 2}}}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "不认识的类别、固定值百分比都写：导入报错")
	var d := Commissions.opener_of(Canteen.ID)
	t.eq(d.id if d != null else &"", &"greylamp_canteen", "食堂由《开伙》开")
	t.eq(Commissions.required_tier(d), 2, "要受托")
	t.eq(Commissions.validate_all(Commissions.defs(), Commissions.factions()), [] as Array[String], "前置、阵营查得过")


static func run_meal(t: TestCase) -> void:
	t.begin("355 · 一锅：同属性固定值相加、百分比相加；主食给饱腹；不是食材的不算；终值 = 基数 ×（1 + Σ%）+ Σ固定")
	var db := T110._db()
	var pot: Array = [_inst(db, &"sour_wheat", 1), _inst(db, &"black_bean", 2), _inst(db, &"mountain_yam", 3), _inst(db, &"mountain_yam", 4),
		_inst(db, &"fowl_leg", 5), _inst(db, &"meat_scrap", 6), _inst(db, &"wild_berry", 7), _inst(db, &"wild_berry", 8),
		_inst(db, &"honey_jar", 9), _inst(db, &"mint_bundle", 10), _inst(db, &"ration", 11)]
	var meal := Canteen.meal_of(pot)
	t.eq(int(meal["count"]), 10, "口粮不算")
	t.eq(int(meal["satiety"]), 5 + 5 + 11 + 11, "饱腹 = 主食之和")
	t.eq(float(meal["flat"]["carry"]), 7.0, "负重 +1 +3 +3")
	t.eq(float(meal["pct"]["carry"]), 2.0, "负重 +2%")
	t.eq([float(meal["flat"]["max_stamina"]), float(meal["pct"]["max_stamina"])], [1.0, 5.0], "耐力上限 +1、+5%")
	t.eq(float(meal["pct"]["regen_stamina"]), 2.5, "耐力回复 +2.5%")
	t.eq([float(meal["flat"]["regen_hp"]), float(meal["pct"]["regen_hp"])], [1.0, 1.0], "每秒回血 0.5 × 2、生命上限 1%")
	t.eq(Canteen.final_value(60.0, meal, BattleStats.MAX_STAMINA), 64.0, "60 × 1.05 + 1")
	t.eq(Canteen.line_of(meal, BattleStats.MAX_STAMINA), UiText.t("canteen.line") % [UiText.t("canteen.stat_max_stamina"), "+1" + UiText.t("tip.list_sep") + "+5%"], "纸条一行")
	var many: Array = []
	for i in 3000:
		many.append(_inst(db, &"rice_sack", 100 + i))
	t.eq(float(Canteen.meal_of(many)["pct"]["carry"]), Canteen.CAP_PCT, "百分比叠到很高：封顶，不溢出")
	t.eq(Canteen.meal_of([])["count"], 0, "空锅")


static func run_store(t: TestCase) -> void:
	t.begin("355 · 食材仓库和锅：只收食材；升档只长不缩、东西原位不动；存档读回来一样（老档没有 = 空的）")
	var db := T110._db()
	var c := Canteen.new()
	t.check(not c.pot.try_add(_inst(db, &"ration", 1)), "口粮下不了锅")
	t.check(not c.store.try_add(_inst(db, &"iron_ore", 2)), "铁矿石进不了食材仓库")
	var yam := _inst(db, &"mountain_yam", 3)
	t.check(c.pot.place(yam, Vector2i(3, 2)), "山薯摆在锅的右下角")
	t.check(c.store.try_add(_inst(db, &"sour_wheat", 4)), "酸麦进食材仓库")
	t.check(c.fit(2).is_empty() and c.pot.size == Vector2i(4, 4), "受托：4×4 不动")
	t.check(c.fit(4).is_empty(), "代言：没有放不下的")
	t.eq([c.pot.size, c.store.size], [Vector2i(6, 6), Vector2i(10, 8)], "锅 6×6、仓库 10×8")
	t.eq(c.pot.get_item(3).origin, Vector2i(3, 2), "山薯原位")
	c.fit(1)
	t.eq(c.pot.size, Vector2i(6, 6), "掉档不缩")
	var m := T110._meta()
	m.canteen = c
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.check(back != null and back.canteen.pot.has_item(3) and back.canteen.store.has_item(4), "存档读回来，锅和仓库的东西都在")
	t.eq(back.canteen.pot.size, Vector2i(6, 6), "大小照存档")
	t.check(not back.canteen.pot.accepts(db.get_def(&"ration")), "读回来照样只收食材")
	var old := m.to_dict()
	old.erase("canteen")
	var b2 := MetaState.from_dict(old, db, GameFlow.load_meta_rules())
	t.check(b2 != null and b2.canteen.pot.item_count() == 0 and b2.canteen.store.size == Vector2i(6, 6), "老档：空的")


static func run_module(t: TestCase) -> void:
	t.begin("355 · 一局：每到新节点饱腹减 1，剩 1 提醒一次；到 0 加成失效，负重那份多留一步；回血独立；存读不重扣")
	var mod := MealModule.new()
	mod.meal = {"flat": {"carry": 3.0, "max_stamina": 4.0, "regen_hp": 0.5}, "pct": {"regen_stamina": 6.0, "regen_hp": 2.0}, "satiety": 3, "count": 4, "ids": {}}
	mod.satiety = 3
	var warns: Array = []
	var ends: Array = []
	mod.warned.connect(func(left: int): warns.append(left))
	mod.ended.connect(func(): ends.append(1))
	var ctx := RunContext.new()
	mod.modify(ctx)
	t.eq([ctx.carry_capacity_bonus, float(ctx.stat_bonus[BattleStats.MAX_STAMINA]), float(ctx.stat_mult[BattleStats.REGEN_STAMINA])], [3, 4.0, 6.0], "负重、耐力上限、耐力回复都加上")
	t.eq(mod.regen_hp(), Vector2(0.5, 2.0), "回血单独一项")
	t.eq(mod.step(), 2, "新节点：3 → 2")
	t.check(warns.is_empty(), "还没提醒")
	t.eq(mod.step(), 1, "2 → 1")
	t.eq(warns, [1], "剩 1：提醒一次")
	t.eq(mod.step(), 0, "1 → 0")
	t.eq(ends.size(), 1, "吃完了")
	ctx = RunContext.new()
	mod.modify(ctx)
	t.check(ctx.carry_capacity_bonus == 3 and not ctx.stat_bonus.has(BattleStats.MAX_STAMINA), "归零这一步：负重还在，别的没了")
	t.eq(mod.regen_hp(), Vector2.ZERO, "回血没了")
	var saved := mod.to_dict()
	var again := MealModule.new()
	again.restore(saved)
	t.check(again.carry_grace and again.satiety == 0 and again.warned_once, "读档：照存的（不重扣、不再提醒）")
	mod.step()
	ctx = RunContext.new()
	mod.modify(ctx)
	t.eq(ctx.carry_capacity_bonus, 0, "下一个新节点：负重也卸了")
	t.eq(warns, [1], "只提醒过一次")
	t.eq(MealModule.new().to_dict(), {}, "没吃饭：不存")


static func run_regen(t: TestCase) -> void:
	t.begin("355 · 战斗中回血：水果那份按秒加上，不被燃血这类打折，不进属性表")
	var spec := CombatantSpec.new()
	spec.max_hp = StatMath.from_float(100.0)
	spec.baseline = StatSet.new()
	spec.meal_regen_hp = 0.5
	spec.meal_regen_hp_pct = 2.0
	var rt := CombatantRuntime.from_spec(spec, 0)
	t.eq(rt.meal_hp_rate(), StatMath.from_float(0.5 + 2.0), "每秒 0.5 + 100 × 2%")
	t.eq(rt.stat(BattleStats.REGEN_HP), 0, "属性表里没有")
	var codec := BattleInputCodec.decode(BattleInputCodec.encode(spec, [] as Array[AbilityRule], {}), [] as Array[AbilityRule])
	t.eq([codec.meal_regen_hp, codec.meal_regen_hp_pct], [0.5, 2.0], "诊断包编得回来")


static func run_flow(t: TestCase) -> void:
	t.begin("355 · 开放与出征：受托时《开伙》接上，办成开食堂；老的薄荷叶束搬进食材仓库；带回的食材先进食材仓库；出发吃掉一锅，走新节点扣饱腹；读档照旧")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	Support.pass_tutorials(f)
	var mint := T110._add(f.meta, c.items, &"mint_bundle")
	t.check(not f.canteen_listed(), "灰灯没到受托：不列")
	_done(f.meta.commissions, [&"greylamp_unsigned_letter", &"greylamp_check_scale", &"greylamp_check_medkits", &"greylamp_permit"])
	f.meta.commissions.rep["greylamp"] = 25
	f.sync_commissions()
	t.eq(f.meta.commissions.state_of(&"greylamp_canteen"), CommissionBook.TAKEN, "受托：《开伙》接上")
	t.check(f.canteen_listed() and not f.canteen_open(), "受托：列出来，没开")
	f.report_commission(&"greylamp_canteen")
	t.check(f.canteen_open(), "办成：开了")
	t.check(f.meta.canteen.store.has_item(mint.uid) and not f.meta.warehouse.has_item(mint.uid), "薄荷叶束搬进食材仓库")
	# 带回来的棋盘：食材先进食材仓库
	f.meta.board = GridInventory.new(Vector2i(4, 4), MetaState.BOARD_ID, false)
	var berry := _inst(c.items, &"wild_berry", f.meta.allocate_uid())
	var ore := _inst(c.items, &"iron_ore", f.meta.allocate_uid())
	f.meta.board.try_add(berry)
	f.meta.board.try_add(ore)
	f.meta.store_all()
	t.check(f.meta.canteen.store.has_item(berry.uid) and f.meta.warehouse.has_item(ore.uid), "野莓进食材仓库、铁矿石进主仓库")
	# 摆一锅
	var yam := _inst(c.items, &"mountain_yam", f.meta.allocate_uid())
	t.check(f.meta.canteen.pot.try_add(yam), "山薯下锅")
	f.meta.canteen.store.remove(berry.uid)
	t.check(f.meta.canteen.pot.try_add(berry), "野莓下锅")
	var kit: LoadoutDef = NodeScreens._kit(c)
	var run := f.begin(c.chapter, kit, 7)
	t.not_null(run, "开得了局")
	if run == null:
		Support.cleanup(PREFIX)
		return
	var mod := MealModule.of(run)
	t.check(mod != null and mod.has_meal() and mod.satiety == 11, "吃了：饱腹 11")
	t.eq(f.meta.canteen.pot.item_count(), 0, "锅空了")
	t.eq(run.buff_context().carry_capacity_bonus, 3, "负重上限 +3")
	t.eq(run.compile_player().meal_regen_hp, 0.5, "每秒回血 0.5")
	if run.phase == RunState.Phase.PICK_SPAWN and not run.map.entry_ids.is_empty():
		run.pick_spawn(run.map.entry_ids[0])
	Support.settle(f)
	t.eq(mod.satiety, 11, "出生点不扣")
	var moves: Array = run.travel.available_moves()
	if not moves.is_empty():
		f.step_to(int(moves[0]))
		Support.settle(f)
		if not run.is_over():
			t.eq(mod.satiety, 10, "走到新节点：11 → 10")
	Support.cleanup(PREFIX)


## 后勤「食堂」：灰灯在就列；没办《开伙》是说明板；开了两块盘（都套框）、纸条写这一锅；字不裸
static func frame_page(t: TestCase, root: Window) -> void:
	t.begin("355 · 后勤「食堂」：没开是说明板；开了食材仓库和锅两块盘（套框）、右边纸条写这一锅和饱腹；右边主仓库收起；字不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	Support.pass_tutorials(f)
	var s: Control = W178._screen(f, root)
	t.check(not (s.sub_tab_buttons() as Dictionary).has("canteen"), "灰灯没到受托：没有食堂键")
	s.queue_free()
	_done(f.meta.commissions, [&"greylamp_unsigned_letter", &"greylamp_check_scale", &"greylamp_check_medkits", &"greylamp_permit"])
	f.meta.commissions.rep["greylamp"] = 25
	f.sync_commissions()
	s = W178._screen(f, root)
	t.check((s.sub_tab_buttons() as Dictionary).has("canteen"), "受托：有食堂键")
	s.show_tab("canteen")
	t.check(s.locked_page().visible, "没办《开伙》：说明板")
	s.queue_free()
	f.report_commission(&"greylamp_canteen")
	var yam := _inst(f.items, &"mountain_yam", f.meta.allocate_uid())
	f.meta.canteen.pot.try_add(yam)
	s = W178._screen(f, root)
	s.show_tab("canteen")
	var p = s.canteen_panel()
	t.check(p != null and p.is_visible_in_tree() and not s.locked_page().visible, "开了：食堂页")
	t.check(p.store_view != null and p.pot_view != null, "两块盘")
	t.check(p.store_view.get_parent() is BoardFrame and p.pot_view.get_parent() is BoardFrame, "都套了外框")
	t.eq(p._satiety.text, UiText.t("canteen.satiety") % 11, "饱腹 11")
	t.eq(p._lines.get_child_count(), 1, "一条：负重上限")
	t.eq(Bare.audit(p, "canteen355"), [] as Array[String], "字不裸")
	s.queue_free()
	W178._cleanup()
