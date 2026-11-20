## 342 B2（报告 348）：五档声望的地基 —— 旧档声望折算；新档教程走完后铁匠铺、科技、集市要三份引导剧情开放（营地一步办完，各 +10）；
## 老档、切片、教程没走完都不门控；剧情自动接上、不占位；委托页三子页；没开放的设施点进去是说明板，有键直达那份剧情
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const T110 := preload("res://tests/meta/test_tech.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const CP := preload("res://ui/game/commission_panel.gd")

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
	p.show_sub("reputation")
	t.not_null(p.find_child("Go_smithy", true, false), "声望页：铁匠铺开了，有「去看看」")
	t.not_null(p.find_child("Story_market", true, false), "声望页：集市没开，有「去办」")
	t.eq(Bare.audit(p, "rep342"), [] as Array[String], "声望页字不裸")
	p.show_sub("regular")
	t.not_null(p.find_child("Regular_legion", true, false), "常规页每方一块")
	s.show_tab("market")
	t.check(s.locked_page().is_visible_in_tree(), "集市没开：说明板")
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

