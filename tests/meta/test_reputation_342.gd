## 342 B2（报告 348）：五档声望的地基 —— 旧档声望折算；新档教程走完后铁匠铺、科技、集市要三份引导剧情开放（营地一步办完，各 +10）；
## 老档、切片、教程没走完都不门控；剧情自动接上、不占位；委托页三子页；没开放的设施点进去是说明板，有键直达那份剧情。
## 第二步：每方两份基础剧情 + 一份许可单各 +5 到 25；营地交货、击败、到访三种目标；常规委托要受托 + 许可单
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const T110 := preload("res://tests/meta/test_tech.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const CP := preload("res://ui/game/commission_panel.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "reputation_342"

const OPENERS := {&"smithy": &"legion_forge_token", &"tech": &"society_first_survey", &"market": &"greylamp_check_scale"}


static func run_migration(t: TestCase) -> void:
	t.begin("342 B2 · v5 → v6：声望折算 0 → 0、2 ～ 4 → 10、5 ～ 8 → 25、9 起 → 50，办成过的那方至少 10；老档不门控；回执不动")
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/meta_v5.json")
	var src: Dictionary = JSON.parse_string(raw)
	t.eq(int(src.get("version", 0)), 5, "冻结样本是 v5")
	var up := MetaMigrations.upgrade(src)
	t.eq(int(up["version"]), MetaState.SAVE_VERSION, "升到当前版本")
	var rep: Dictionary = up["commissions"]["rep"]
	t.eq([int(rep["legion"]), int(rep["society"]), int(rep["greylamp"])], [10, 10, 50], "军团 3 → 10；协会 1 但办成过 → 10；灰灯 9 → 50")
	var m := MetaSave.from_text(raw, T110._db(), GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.not_null(m, "读得进来")
	if m == null:
		return
	t.check(not m.commissions.gated, "老档不门控")
	t.eq(m.commissions.receipts.size(), 1, "回执原样")
	t.check(m.commissions.is_done(&"greylamp_unsigned_letter"), "办成的照旧算办成")


static func run_content(t: TestCase) -> void:
	t.begin("342 B2 · 三份引导剧情：各开一处设施、+10、营地当场办；三方改名、各记着开哪处")
	for fac in OPENERS:
		var d := Commissions.opener_of(fac)
		t.check(d != null and d.id == OPENERS[fac], "%s 由《%s》开放" % [fac, Names.of(d) if d != null else "?"])
		if d == null:
			continue
		t.check(Commissions.is_story(d) and Commissions.reputation_of(d) == 10 and Commissions.required_tier(d) == 0, "剧情、+10、初识就能接")
		t.check(d.stages.size() == 1 and d.stages[0].goal == &"camp_report" and d.stages[0].where == CommissionStage.CAMP, "营地一步")
		var f := Commissions.faction(d.faction)
		t.check(f != null and StringName(String(f.facilities.get(String(fac), ""))) == d.id, "阵营上记着这处设施")
	t.eq(Names.of(Commissions.faction(&"legion")), "后勤部队", "军团接应队改名后勤部队")
	t.eq(Names.of(Commissions.faction(&"society")), "魔法师协会", "考据所改名魔法师协会")


static func _gated_flow() -> GameFlow:
	var f := W178._flow()
	f.meta.commissions.gated = true
	return f


static func run_gating(t: TestCase) -> void:
	t.begin("342 B2 · 门控：新档教程走完三处都关着 → 自动接上三份引导单 → 各办一次：+10、开放、回执；老档 / 切片不门控")
	var f := _gated_flow()
	for fac in OPENERS:
		t.check(not f.facility_open(fac), "%s 关着" % fac)
	var got := f.sync_commissions()
	for fac in OPENERS:
		t.check(got.has(OPENERS[fac]), "《%s》自动接上" % OPENERS[fac])
	t.eq(f.sync_commissions(), [] as Array[StringName], "再进不重复接")
	var r := f.report_commission(&"legion_forge_token")
	t.check(bool(r["done"]), "办理一次就办成")
	t.check(f.facility_open(&"smithy") and not f.facility_open(&"market"), "铁匠铺开了，集市还关着")
	t.eq(f.meta.commissions.rep_of(&"legion"), 10, "后勤部队 +10")
	t.eq(Commissions.tier_of(f.meta.commissions, Commissions.faction(&"legion")), 1, "到熟面")
	t.check(not bool(f.report_commission(&"legion_forge_token")["ok"]), "办成的不能再办")
	var old := W178._flow()
	t.check(OPENERS.keys().all(func(fac: StringName) -> bool: return old.facility_open(fac)), "老档（不是新档开始的）三处都开着")
	var sl := _gated_flow()
	sl.profile = SliceProfile.SLICE
	t.check(sl.facility_open(&"tech"), "切片不门控")
	W178._cleanup()


static func frame_panel(t: TestCase, root: Window) -> void:
	t.begin("342 B2 · 委托页三子页：教程走完的新档进基地落在剧情；卡上【办理】；声望页列设施；没开放的集市点进去是说明板、键直达剧情；字不裸")
	ItemInstance.reset_uid_counter()
	var f := _gated_flow()
	var s: Control = W178._screen(f, root)
	t.eq(s.tab(), "commissions", "设施没开全：进基地落在委托页")
	var p = s.commission_panel()
	t.check(p != null and p.sub() == "story", "剧情子页")
	if p == null:
		s.queue_free()
		W178._cleanup()
		return
	p.show_faction(&"legion")
	var rb := p.find_child("Report_legion_forge_token", true, false) as Button
	t.not_null(rb, "《领炉牌》卡上有【办理】")
	t.check(bool(p.report(&"legion_forge_token")["done"]), "按【办理】办成")
	t.check(f.facility_open(&"smithy"), "铁匠铺开了")
	t.eq(s.notice_layer().current_text(), UiText.t("commission.opened") % UiText.t("smithy.title"), "新档：说一句「铁匠铺开放了」")
	p.show_sub("reputation")
	t.not_null(p.find_child("Go_smithy", true, false), "声望页：铁匠铺开了，有「去看看」")
	t.not_null(p.find_child("Story_market", true, false), "声望页：集市没开，有「去办」")
	t.eq(Bare.audit(p, "rep342"), [] as Array[String], "声望页字不裸")
	p.show_sub("regular")
	t.not_null(p.find_child("Regular_legion", true, false), "常规页每方一块")
	s.show_tab("market")
	t.check(s.locked_page().is_visible_in_tree(), "集市没开：说明板")
	t.check(not s._right.visible, "说明板和科技页一样不露右边的仓库")
	var go := s.locked_page().find_child("LockedGo", true, false) as Button
	t.not_null(go, "说明板上有直达键")
	if go != null:
		go.pressed.emit()
		t.check(s.tab() == "commissions" and p.sub() == "story" and p.faction() == &"greylamp", "直达灰灯的剧情")
	s.show_tab("smithy")
	t.check(not s.locked_page().is_visible_in_tree() and s.smithy_panel().is_visible_in_tree(), "铁匠铺开了：照常进")
	CP.last_sub = "story"     # 子页记忆是静态的：别带到别的测试里
	s.queue_free()
	W178._cleanup()



static func _done(book: CommissionBook, ids: Array) -> void:
	for id in ids:
		book.entries[String(id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}


static func run_followups(t: TestCase) -> void:
	t.begin("342 B2 · 后续剧情：每方开放单 10 + 两份基础 5 + 许可单 5 = 25；许可单要两份基础都办完；常规委托要受托且许可单办完")
	for f in Commissions.listed_factions():
		var permit := Commissions.def(f.permit)
		t.check(permit != null and permit.faction == f.id and Commissions.is_story(permit), "%s 有许可单" % Names.of(f))
		if permit == null:
			continue
		var total := 0
		for fac in f.facilities:
			total += Commissions.reputation_of(Commissions.def(StringName(String(f.facilities[fac]))))
		t.eq(permit.requires.size(), 2, "《%s》要两份基础剧情" % Names.of(permit))
		for r in permit.requires:
			var d := Commissions.def(r)
			total += Commissions.reputation_of(d) if d != null else 0
		total += Commissions.reputation_of(permit)
		t.eq(total, f.thresholds[Commissions.REGULAR_TIER], "%s 的剧情加起来正好到受托" % Names.of(f))
	var book := CommissionBook.new()
	var legion := Commissions.faction(&"legion")
	book.rep["legion"] = 25
	t.check(not Commissions.regular_open(book, legion), "受托了、许可单没办：常规不开")
	_done(book, [legion.permit])
	t.check(Commissions.regular_open(book, legion), "许可单办完：常规开")
	book.rep["legion"] = 20
	t.check(not Commissions.regular_open(book, legion), "没到受托：常规不开")


static func run_hand_in(t: TestCase) -> void:
	t.begin("342 B2 · 营地交货：《查验材料》要三件金属；按【办理】交仓库里合格的（没锁的、便宜的先交），可以分批；交够办成 +5")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	var book := f.meta.commissions
	_done(book, [&"legion_forge_token"])
	book.rep["legion"] = 10
	f.sync_commissions()
	var id := &"legion_check_materials"
	var d := Commissions.def(id)
	t.eq(book.state_of(id), CommissionBook.TAKEN, "开放单办完：《查验材料》自动接上")
	t.check(not Commissions.can_report(book, d, f.meta), "仓库里没有金属：不能办理")
	var a := T110._add(f.meta, c.items, &"iron_ore")
	var b := T110._add(f.meta, c.items, &"iron_ore")
	var locked := T110._add(f.meta, c.items, &"nail_keg")
	locked.set_locked(true)
	T110._add(f.meta, c.items, &"bandage")
	t.check(Commissions.can_report(book, d, f.meta), "有两件金属：能办理")
	var r := f.report_commission(id)
	t.eq(int(r.get("handed", 0)), 2, "交了两件（锁着的不交）")
	t.check(not bool(r["done"]), "还差一件")
	t.check(f.meta.warehouse.get_item(a.uid) == null and f.meta.warehouse.get_item(b.uid) == null and f.meta.warehouse.get_item(locked.uid) != null, "交的从仓库拿走，锁着的留着")
	t.eq(int(book.entry(id)["progress"]), 2, "进度 2 / 3")
	t.check(not Commissions.can_report(book, d, f.meta), "没有合格的了：不能办理")
	T110._add(f.meta, c.items, &"iron_ore")
	T110._add(f.meta, c.items, &"iron_ore")
	r = f.report_commission(id)
	t.eq(int(r.get("handed", 0)), 1, "只交还差的一件")
	t.check(bool(r["done"]) and book.is_done(id), "办成")
	t.eq(book.rep_of(&"legion"), 15, "后勤部队 +5")
	Support.cleanup(PREFIX)


static func run_field_goals(t: TestCase) -> void:
	t.begin("342 B2 · 局内两种新目标：《清出一条路》打赢普通的仗（精英、首领、输了不算；同一场只记一次）；《协会登记证》到访搜索点（同一局同一处只记一次）；败退也算")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	var book := f.meta.commissions
	_done(book, [&"legion_forge_token", &"society_first_survey", &"society_copy_recipe", &"society_identify_ore"])
	book.rep["legion"] = 10
	book.rep["society"] = 20
	f.sync_commissions()
	var road := &"legion_clear_road"
	var reg := &"society_permit"
	t.check(book.state_of(road) == CommissionBook.TAKEN and book.state_of(reg) == CommissionBook.TAKEN, "两份都自动接上")
	var s := f.begin_direct(c.chapter, 23)
	t.not_null(s, "开局")
	if s == null:
		Support.cleanup(PREFIX)
		return
	var mod := CommissionModule.of(s)
	mod.install(s)     # 再装一次也只接一次信号
	var node: MapNode = s.map.get_node(s.map.node_ids()[0])
	s.events.last_battle = {"type": "battle", "battle_id": "b1", "content": {"enemy": "brute"}}
	s.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(mod.progress(road, 0), 1, "打赢一场记一场")
	s.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(mod.progress(road, 0), 1, "同一场不重记")
	t.check(mod.on_battle(node, true, {"type": "elite", "battle_id": "b2"}).is_empty(), "精英不算普通敌人")
	t.check(mod.on_battle(node, false, {"type": "battle", "battle_id": "b3"}).is_empty(), "输了不算")
	t.eq(mod.on_battle(node, true, {"type": "search", "battle_id": "b4"}).size(), 1, "搜索里遇上的仗算")
	var searches: Array[MapNode] = []
	var other: MapNode = null
	for nid in s.map.node_ids():
		var n := s.map.get_node(nid)
		if NodeEvents.effective_type(n) == &"search":
			searches.append(n)
		elif other == null:
			other = n
	t.check(searches.size() >= 2, "图上至少两处搜索点")
	if searches.size() < 2:
		Support.cleanup(PREFIX)
		return
	t.eq(mod.on_visit(searches[0]).size(), 1, "到访一处搜索点")
	t.check(mod.on_visit(searches[0]).is_empty(), "同一处不重记")
	if other != null:
		t.check(mod.on_visit(other).is_empty(), "别的点不算")
	t.eq(mod.on_visit(searches[1]).size(), 1, "第二处")
	s.fail(&"time_out")
	f._settle_run()
	t.eq(int(book.entry(road)["progress"]), 2, "败退：打赢的两场照记")
	t.check(book.is_done(reg), "败退：两处到访照记，《协会登记证》办成")
	t.eq(book.rep_of(&"society"), 25, "魔法师协会到受托")
	t.check(Commissions.regular_open(book, Commissions.faction(&"society")), "协会的常规委托开了")
	Support.cleanup(PREFIX)


static func frame_old_save_no_toast(t: TestCase, root: Window) -> void:
	t.begin("342 B2 · 老档办《领炉牌》：铁匠铺本来就开着，不说「铁匠铺开放了」")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	var s: Control = W178._screen(f, root)
	s.notice_layer().clear()
	s._on_reported({"done": true, "got": {"opens": "smithy"}})
	t.check(s.notice_layer().current_text() == "", "不弹")
	s.queue_free()
	W178._cleanup()
