## 342 B3 第二步：河滩垦户社与苗圃 —— 和地图协会同一次来营地；《第一畦》营地办理 +10、开苗圃；《试种》《收获》《登记留种》到 25。
## 苗圃：一次有实际探索的正式出征结算推进一格（胜败都算，同一局不推两次）；熟了留在地里，仓库放得下才收，放不下整体退回；
## 局外存档 v7，老档一片空地
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const PREFIX := "growers_342b3"


static func _done(book: CommissionBook, ids: Array) -> void:
	for id in ids:
		book.entries[String(id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}


static func _open(f: GameFlow) -> void:
	var book := f.meta.commissions
	book.arrived["growers"] = 1
	book.arrived["cartographers"] = 1
	f.sync_commissions()
	f.report_commission(&"growers_first_bed")


static func _count(m: MetaState, id: StringName) -> int:
	return m.warehouse.items().filter(func(i: ItemInstance) -> bool: return i.def.id == id).size()


static func run_content(t: TestCase) -> void:
	t.begin("342 B3 · 垦户社：和地图协会同一次来；首单开苗圃 +10；四份加起来 25；许可单要用自家干草药种一株苦叶草")
	var f := Commissions.faction(&"growers")
	t.check(f != null and f.arrives == Commissions.ARRIVES_FIRST_RUN, "第一次正式探索结算时来")
	t.eq(Commissions.opener_of(&"nursery").id, &"growers_first_bed", "苗圃由《第一片地》开")
	var total := 0
	for c in Commissions.of_faction(&"growers"):
		total += Commissions.reputation_of(c)
	t.eq(total, 25, "到 25")
	t.eq(String(Commissions.def(&"growers_permit").stages[0].params.get("crop", "")), "bitter_leaf", "许可单：苦叶草")
	t.eq(Commissions.validate_all(Commissions.defs(), Commissions.factions()), [] as Array[String], "前置、阵营查得过")


static func run_cycle(t: TestCase) -> void:
	t.begin("342 B3 · 苗圃一轮：开苗圃 → 种绳麻（不要种苗）→ 三局正式探索后熟 → 收一卷麻绳；剧情跟着记；同一局不推两次")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	t.eq(f.sow_crop(0, &"rope_hemp"), Nursery.WHY_UNKNOWN, "没开：种不了")
	_open(f)
	t.check(f.facility_open(&"nursery"), "办成《第一片地》：苗圃开了")
	t.eq(f.meta.commissions.rep_of(&"growers"), 10, "+10")
	t.eq(f.meta.commissions.state_of(&"growers_trial_sow"), CommissionBook.TAKEN, "《试种》自动接上")
	t.eq(f.sow_crop(0, &"bitter_leaf"), Nursery.WHY_SEED, "苦叶草要一束干草药，仓库没有")
	t.eq(f.sow_crop(0, &"rope_hemp"), "", "绳麻：种上")
	t.check(Commissions.is_ready(f.meta.commissions, &"growers_trial_sow"), "《试种》办成了，等点【完成】")
	t.eq(f.meta.commissions.state_of(&"growers_first_harvest"), "", "没点完成：下一份还没出来")
	f.claim_commission(&"growers_trial_sow")
	t.check(f.meta.commissions.is_done(&"growers_trial_sow"), "点【完成】结案")
	t.eq(f.meta.commissions.state_of(&"growers_first_harvest"), CommissionBook.TAKEN, "完成一个出现下一个：《收获》接上")
	t.eq(f.sow_crop(0, &"rope_hemp"), "", "这一片还摆得下：再种一株绳麻")
	t.eq(f.meta.nursery.plants(0).size(), 2, "地里两株")
	t.check(Nursery.advance(f.meta, "r1"), "一局")
	t.check(not Nursery.advance(f.meta, "r1"), "同一局不推第二次")
	Nursery.advance(f.meta, "r2")
	t.check(not f.nursery_ripe(), "两局：还没熟")
	t.eq(String(f.harvest_crop(0)["why"]), Nursery.WHY_UNRIPE, "没熟收不了")
	Nursery.advance(f.meta, "r3")
	t.check(f.nursery_ripe(), "三局：熟了")
	var got := f.harvest_crop(0)
	t.eq([String(got["why"]), int(got["items"])], ["", 2], "两株各收一件")
	t.eq(_count(f.meta, &"rope_coil"), 2, "仓库里两卷麻绳")
	t.check(f.meta.nursery.is_empty(0), "地空了")
	f.claim_commission(&"growers_first_harvest")
	t.check(f.meta.commissions.is_done(&"growers_first_harvest"), "《收获》办成")
	var herb := ItemInstance.create(c.items.get_def(&"dried_herbs"))
	herb.uid = f.meta.allocate_uid()
	f.meta.warehouse.try_add(herb)
	t.eq(f.sow_crop(0, &"bitter_leaf"), "", "苦叶草：扣一束干草药种上")
	t.eq(_count(f.meta, &"dried_herbs"), 0, "种苗扣了")
	f.claim_commission(&"growers_permit")
	t.check(f.meta.commissions.is_done(&"growers_permit"), "《登记留种》办成")
	t.eq(f.meta.commissions.rep_of(&"growers"), 25, "垦户社到受托")
	var back := MetaState.from_dict(f.meta.to_dict(), c.items, GameFlow.load_meta_rules())
	t.check(back != null and back.nursery.to_dict() == f.meta.nursery.to_dict(), "存档往返")
	Support.cleanup(PREFIX)


static func run_full_warehouse(t: TestCase) -> void:
	t.begin("342 B3 · 库满：收获整体退回、地里照旧，腾出地方再收")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	_open(f)
	var herb := ItemInstance.create(c.items.get_def(&"dried_herbs"))
	herb.uid = f.meta.allocate_uid()
	f.meta.warehouse.try_add(herb)
	f.sow_crop(0, &"bitter_leaf")
	Nursery.advance(f.meta, "a")
	Nursery.advance(f.meta, "b")
	var filler: Array[int] = []
	var stone := c.items.get_def(&"flint")
	var guard := 0
	while guard < 2000:
		guard += 1
		var x := ItemInstance.create(stone)
		x.uid = f.meta.allocate_uid()
		if not f.meta.warehouse.try_add(x):
			break
		filler.append(x.uid)
	f.meta.warehouse.remove(filler.pop_back())     # 只剩一格：两束放不下
	var before := f.meta.warehouse.item_count()
	t.eq(String(f.harvest_crop(0)["why"]), Nursery.WHY_FULL, "放不下")
	t.eq(f.meta.warehouse.item_count(), before, "一件没多")
	t.check(f.meta.nursery.is_ripe(0), "还在地里")
	f.meta.warehouse.remove(filler.pop_back())
	t.eq(int(f.harvest_crop(0)["items"]), 2, "腾出地方：收两束")
	Support.cleanup(PREFIX)


static func run_settle(t: TestCase) -> void:
	t.begin("342 B3 · 结算推进：走出过起点的正式出征推一格（败退也算），空跑不推，重复结算不推")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	_open(f)
	f.sow_crop(0, &"rope_hemp")
	var s := f.begin_direct(c.chapter, 31)
	s.fail(&"time_out")
	f._settle_run()
	t.eq(_left(f.meta), 3, "空跑：不推")
	f.result = null
	f._settled = false
	var s2 := f.begin_direct(c.chapter, 32)
	if s2.phase == RunState.Phase.PICK_SPAWN:
		f.pick_spawn(s2.map.entry_ids[0])
	var moves := s2.travel.available_moves()
	t.check(not moves.is_empty() and s2.travel.step_to(moves[0]), "走了一步")
	s2.fail(&"time_out")
	f._settle_run()
	t.eq(_left(f.meta), 2, "败退也推一格")
	f._settled = false
	f._settle_run()
	t.eq(_left(f.meta), 2, "重复结算：不推")
	Support.cleanup(PREFIX)


static func run_migration(t: TestCase) -> void:
	t.begin("342 B3 · 局外 v6 → v7：老档一片空地；认不得的作物当空地")
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/meta_v6.json")
	var src: Dictionary = JSON.parse_string(raw)
	t.eq(int(src.get("version", 0)), 6, "冻结样本是 v6")
	var m := MetaSave.from_text(raw, W178._flow().items, GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.check(m != null and m.nursery.fields.size() == Nursery.PLOTS and m.nursery.is_empty(0), "一片空地")
	var n := Nursery.from_dict({"plots": [{"crop": "no_such_crop", "left": 2}]})
	t.check(n.fields.size() == 1 and n.legacy_count() == 0, "认不得的作物：空地")
	W178._cleanup()


static func frame_page(t: TestCase, root: Window) -> void:
	t.begin("342 B3 · 后勤「苗圃」：垦户社没来不列；来了没办首单是说明板；开了能种，熟了后勤页签挂「可收获」；字不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	Support.pass_tutorials(f)
	var s: Control = W178._screen(f, root)
	t.check(not (s.sub_tab_buttons() as Dictionary).has("nursery"), "没来：没有苗圃键")
	s.queue_free()
	f.meta.commissions.arrived["growers"] = 1
	s = W178._screen(f, root)
	t.check((s.sub_tab_buttons() as Dictionary).has("nursery"), "来了：有苗圃键")
	s.show_tab("nursery")
	t.check(s.locked_page().visible, "没办首单：说明板")
	s.queue_free()
	f.sync_commissions()
	f.report_commission(&"growers_first_bed")
	f.sow_crop(0, &"rope_hemp")
	for k in 3:
		Nursery.advance(f.meta, "x%d" % k)
	s = W178._screen(f, root)
	s.show_tab("nursery")
	t.check(not s.locked_page().visible and s.nursery_panel().is_visible_in_tree(), "开了：苗圃页")
	var tab := (s._tab_btns as Dictionary).get("logistics", null) as Button
	var mark := tab.get_node_or_null("RipeMark") as TextureRect if tab != null else null
	t.check(mark != null and mark.visible and mark.texture != null, "后勤页签挂「可收获」小图")
	t.eq(tab.tooltip_text, UiText.t("nursery.ripe"), "悬停写「可收获」")
	var p = s.nursery_panel()
	t.check(p != null and p.find_child("Harvest_0", true, false) != null, "有【收获】")
	t.eq(Bare.audit(p, "nursery342"), [] as Array[String], "字不裸")
	p.harvest(0)
	t.check(not mark.visible, "收了：标记没了")
	s.queue_free()
	W178._cleanup()


static func frame_commission_keys(t: TestCase, root: Window) -> void:
	t.begin("作者 2026-11-21 · 委托键：营地报到点【完成】直接办成并跳到开的那页；种地类【前往】苗圃；办成了留在卡上点【完成】才结案，下一份才出来")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	Support.pass_tutorials(f)
	f.meta.commissions.arrived["growers"] = 1
	f.sync_commissions()
	var s: Control = W178._screen(f, root)
	s.show_tab("commissions")
	var cp = s.commission_panel()
	cp.show_faction(&"growers")
	t.not_null(cp.find_child("Finish_growers_first_bed", true, false), "《第一片地》卡上是【完成】")
	t.check(bool(cp.finish(&"growers_first_bed")["done"]), "点【完成】办成")
	t.check(s.nursery_panel() != null and s.nursery_panel().is_visible_in_tree(), "直接跳到苗圃页")
	s.show_tab("commissions")
	cp.show_faction(&"growers")
	var go := cp.find_child("GoTo_growers_trial_sow", true, false) as Button
	t.check(go != null and go.text == UiText.t("commission.go"), "《试种》卡上是【前往】")
	if go != null:
		go.pressed.emit()
	t.check(s.nursery_panel().is_visible_in_tree(), "【前往】跳到苗圃页")
	f.sow_crop(0, &"rope_hemp")
	s.show_tab("commissions")
	cp.show_faction(&"growers")
	t.check(cp.find_child("GoTo_growers_trial_sow", true, false) == null, "种上了：没有【前往】")
	t.not_null(cp.find_child("Card_growers_trial_sow", true, false), "办成了卡还在（不自动消失）")
	t.not_null(cp.find_child("Finish_growers_trial_sow", true, false), "卡上是【完成】")
	t.check(cp.find_child("Card_growers_first_harvest", true, false) == null, "下一份还没出来")
	cp.finish(&"growers_trial_sow")
	t.check(cp.find_child("Card_growers_trial_sow", true, false) == null, "点完：卡收走")
	t.not_null(cp.find_child("Card_growers_first_harvest", true, false), "下一份《收获》出来了")
	t.eq(f.meta.commissions.rep_of(&"growers"), 15, "声望点完成才加")
	s.queue_free()
	W178._cleanup()


## 第一片地里第一株还差几局（没种 = -1）
static func _left(meta: MetaState) -> int:
	var ps := meta.nursery.plants(0)
	return meta.nursery.left_of(ps[0].uid) if not ps.is_empty() else -1
