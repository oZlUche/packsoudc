## 报告 377 第一批：万神院 —— 新档教程后第 3 次成功撤离结算时来营地；没来之前这一局没有信仰（不铺神召、没有神坛祷告、
## 掉落不出信物与赐福道具、随机来源锁上信物）；来了以后在万神院选神，出征时信物自动进背包、定这一局的神，局结束信物不带回仓库；
## 一档三位神、二档全开、三档奉神经验 +10%、四档神坛有赐福；献祭 / 修行两种新目标；老档迁移只做一次（算已到来、奉过的神都能选、信物折钱）
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "pantheon_377"


## 新档（建档门槛开着、迁移标过）+ 教程记成通过
static func _new_flow(c: TestSupport.Content) -> GameFlow:
	var f := Support.flow(c, PREFIX)
	f.meta = GameFlow.new_meta(f.meta_rules)
	Support.pass_tutorials(f)
	return f


## 走一步再撤离（算一局有实际探索的正式出征），结算
static func _extract_once(f: GameFlow, c: TestSupport.Content, seed_: int) -> RunState:
	f.result = null
	f._settled = false
	var s := f.begin_direct(c.chapter, seed_)
	if s == null:
		return null
	if s.phase == RunState.Phase.PICK_SPAWN:
		f.pick_spawn(s.map.entry_ids[0])
	var moves := s.travel.available_moves()
	if not moves.is_empty():
		s.travel.step_to(moves[0])
	s.force_extract()
	f._settle_run()
	return s


static func run_content(t: TestCase) -> void:
	t.begin("377 · 万神院的数据：第 3 次撤离来、两档各三位神、三四五档的服务、三份剧情到 25、许可单")
	var f := Pantheon.faction()
	t.not_null(f, "有万神院")
	if f == null:
		return
	t.eq([f.arrives, f.arrive_after], [Commissions.ARRIVES_EXTRACTIONS, 3], "教程后第 3 次成功撤离")
	t.eq(Pantheon.gods(FaithDef.load_all()), [&"brute", &"skill", &"sun", &"earth", &"hunt", &"nature"] as Array[StringName], "先一档再二档，新教不列")
	t.eq([Pantheon.god_tier(&"sun"), Pantheon.god_tier(&"nature")], [0, 1], "日神一档、自然二档")
	t.eq([int(f.services[String(Pantheon.SERVICE_XP)]), int(f.services[String(Pantheon.SERVICE_BLESS)]), int(f.services[String(Pantheon.SERVICE_OPENING)])], [2, 3, 4], "三四五档")
	var total := 0
	for d in Commissions.of_faction(Pantheon.FACTION):
		total += Commissions.reputation_of(d)
	t.eq(total, 25, "剧情加起来 25（到三档）")
	t.eq(f.permit, &"pantheon_permit", "许可单")
	for nm in ["emblem_pantheon", "pin_pantheon"]:
		t.check(UiTheme.has_art("commission/" + nm), "占位图 %s" % nm)


static func run_arrival(t: TestCase) -> void:
	t.begin("377 · 新档：前两次撤离没有信仰；第 3 次撤离结算时万神院来，营地后勤列出它")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := _new_flow(c)
	t.check(not f.faith_open(), "新档一开始没有信仰")
	t.check(not f.pantheon_listed(), "万神院不列")
	var s := _extract_once(f, c, 31)
	t.not_null(s, "第一局")
	if s == null:
		Support.cleanup(PREFIX)
		return
	t.check(not s.faith_enabled and not s.faith_bless, "没来之前这一局没有信仰")
	var group_left := 0
	for id in s.map.node_ids():
		if String(s.map.get_node(id).content.get("event", "")).begins_with("faith_call"):
			group_left += 1
	t.eq(group_left, 0, "不铺神召事件")
	t.eq(f.meta.commissions.formal_extractions, 1, "记了一次成功撤离")
	t.check(not Pantheon.arrived(f.meta), "一次：还没来")
	_extract_once(f, c, 32)
	t.check(not Pantheon.arrived(f.meta), "两次：还没来")
	_extract_once(f, c, 33)
	t.check(Pantheon.arrived(f.meta), "第三次：来了")
	t.check(f.last_arrived.has(Pantheon.FACTION), "这一回到的里面有万神院")
	t.check(f.faith_open() and f.pantheon_listed(), "有信仰了，后勤列出万神院")
	t.eq(Pantheon.tier(f.meta), 0, "信赖一档")
	f.sync_commissions()
	t.eq(f.meta.commissions.state_of(&"pantheon_first_rite"), CommissionBook.TAKEN, "首单自动接上")
	var back := MetaState.from_dict(f.meta.to_dict(), c.items, GameFlow.load_meta_rules())
	t.check(back != null and back.commissions.formal_extractions == 3 and Pantheon.arrived(back), "存档往返")
	Support.cleanup(PREFIX)


static func run_choose_and_depart(t: TestCase) -> void:
	t.begin("377 · 选神：一档只开三位；出征时信物进背包、定这一局的神；局结束信物不回仓库；记下奉过")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode", PackedStringArray(["faiths", "characters"]))
	var f := _new_flow(c)
	f.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	t.check(not f.choose_god(&"nature"), "自然之神二档才开")
	t.check(f.choose_god(&"sun"), "日神一档就能选")
	t.eq(f.meta.pantheon_choice, &"sun", "记下了")
	f.result = null
	f._settled = false
	var s := f.begin_direct(c.chapter, 41)
	t.not_null(s, "开局")
	if s == null:
		Support.cleanup(PREFIX)
		return
	t.check(s.faith_enabled, "有信仰")
	t.check(not s.faith_bless, "一档：神坛上还没有赐福")
	t.eq(s.faith_xp_bonus, 0.0, "一档：不加经验")
	var charm := Pantheon.charm_of(c.items, &"sun")
	t.check(s.board.items().any(func(i: ItemInstance) -> bool: return i.def == charm), "日神的信物在背包里")
	t.eq(s.selected_faith, &"sun", "这一局奉日神")
	t.check(f.meta.gods_worshipped.has(&"sun"), "记下奉过日神")
	if s.phase == RunState.Phase.PICK_SPAWN:
		f.pick_spawn(s.map.entry_ids[0])
	s.force_extract()
	f._settle_run()
	var home: Array = f.meta.warehouse.items() + (f.meta.board.items() if f.meta.board != null else [])
	t.check(not home.any(func(i: ItemInstance) -> bool: return Pantheon.is_charm(i.def)), "信物不带回仓库")
	t.check(f.choose_god(&""), "可以改回以人为本")
	f.result = null
	f._settled = false
	var s2 := f.begin_direct(c.chapter, 42)
	t.eq(s2.selected_faith if s2 != null else &"?", &"", "以人为本：不奉神")
	t.check(s2 != null and not s2.board.items().any(func(i: ItemInstance) -> bool: return i.def.is_anchor()), "背包里没有信物")
	Support.cleanup(PREFIX)


static func run_tiers(t: TestCase) -> void:
	t.begin("377 · 信赖：二档全部神可选；三档奉神经验 ×1.1（以人为本不加）；四档神坛上有赐福")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode", PackedStringArray(["faiths", "characters"]))
	var f := _new_flow(c)
	var book := f.meta.commissions
	book.arrived[String(Pantheon.FACTION)] = 0
	book.rep[String(Pantheon.FACTION)] = 10
	t.check(Pantheon.god_open(f.meta, &"nature"), "二档：自然之神能选")
	t.eq(Pantheon.access(f.meta)["xp_bonus"], 0.0, "二档还不加经验")
	book.rep[String(Pantheon.FACTION)] = 25
	t.eq(Pantheon.access(f.meta)["xp_bonus"], Pantheon.XP_BONUS, "三档加 10%")
	t.check(not bool(Pantheon.access(f.meta)["bless"]), "三档还没有赐福")
	book.rep[String(Pantheon.FACTION)] = 50
	t.check(bool(Pantheon.access(f.meta)["bless"]), "四档有赐福")
	f.choose_god(&"earth")
	f.result = null
	f._settled = false
	var s := f.begin_direct(c.chapter, 51)
	if s == null:
		t.check(false, "开局")
		Support.cleanup(PREFIX)
		return
	var lv := LevelModule.of(s)
	var base := lv.rules().mult(s.difficulty.level if s.difficulty != null else 0)
	t.check(s.active_faith_id() == &"earth" and is_equal_approx(lv.mult(), base * (1.0 + Pantheon.XP_BONUS)), "奉神：经验系数 ×1.1")
	s.selected_faith = &""
	t.check(is_equal_approx(lv.mult(), base), "以人为本：不加")
	s.faith_bless = false
	s.selected_faith = &"earth"
	var altar := AltarModule.of(s)
	t.check(not altar.actions().any(func(p: FaithPerk) -> bool: return p is AltarBlessPerk), "四档以下：神坛上没有赐福这一项")
	s.faith_bless = true
	var has_bless_perk := s.active_faith().perks_at(s.active_faith_tier()).any(func(p: FaithPerk) -> bool: return p is AltarBlessPerk)
	t.eq(altar.actions().any(func(p: FaithPerk) -> bool: return p is AltarBlessPerk), has_bless_perk, "四档：有就列")
	var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and back.faith_enabled and back.faith_bless and is_equal_approx(back.faith_xp_bonus, Pantheon.XP_BONUS), "局内存档带着信仰开关")
	Support.cleanup(PREFIX)


static func run_no_faith_run(t: TestCase) -> void:
	t.begin("377 · 没有信仰的局：没有神坛祷告、不换赐福版、掉落里拿掉信物与赐福道具、随机来源锁上")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := _new_flow(c)
	var s := f.begin_direct(c.chapter, 61)
	if s == null:
		t.check(false, "开局")
		Support.cleanup(PREFIX)
		return
	var lv := LevelModule.of(s)
	t.eq(lv.prayers_left(s.current_node() if s.current_node() != null else s.map.get_node(s.map.entry_ids[0])), 0, "休息点没有神坛可以祷告")
	var ids: Array[StringName] = [&"knife", &"shortsword"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	t.eq(AltarModule.of(s).bless_substitute(ids, 1.0, 1.0, rng), ids, "战利品不换赐福版")
	var rolled := {"dropped": [&"charm_sun", &"knife"] as Array[StringName], "treasure": [&"blessed_longbow"] as Array[StringName]}
	s.events._strip_faith(rolled)
	t.eq([rolled["dropped"], rolled["treasure"]], [[&"knife"], []], "掉落拿掉信物与赐福道具")
	t.check(c.items.is_locked(&"charm_sun") and c.items.is_locked(&"thorn_seed"), "随机来源锁上归神的东西")
	f.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	f.apply_item_locks()
	t.check(not c.items.is_locked(&"charm_sun"), "万神院来了就解锁")
	Support.cleanup(PREFIX)


static func run_goals(t: TestCase) -> void:
	t.begin("377 · 新目标：神坛献祭每座记一次（现场算）；奉神升级每级记一次（撤离才算）；以人为本升级不记")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode", PackedStringArray(["faiths", "characters"]))
	var f := _new_flow(c)
	f.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	f.sync_commissions()
	t.eq(f.meta.commissions.state_of(&"pantheon_first_rite"), CommissionBook.TAKEN, "首单接着")
	t.eq(Commissions.def(&"pantheon_first_rite").stages[0].where, CommissionStage.CARRY, "修行要带回")
	f.choose_god(&"brute")
	f.result = null
	f._settled = false
	var s := f.begin_direct(c.chapter, 71)
	if s == null:
		t.check(false, "开局")
		Support.cleanup(PREFIX)
		return
	var cm := CommissionModule.of(s)
	t.check(cm != null and not cm.waiting(&"faith_levels").is_empty(), "首单带进了局")
	var lv := LevelModule.of(s)
	lv.gain((float(lv.rules().total_for(4)) + 0.01) / lv.mult(), LevelModule.SRC_BATTLE)
	t.eq(cm.progress(&"pantheon_first_rite", 0), 3, "奉神升三级：记三次")
	if s.phase == RunState.Phase.PICK_SPAWN:
		f.pick_spawn(s.map.entry_ids[0])
	s.force_extract()
	f._settle_run()
	t.eq(f.meta.commissions.state_of(&"pantheon_first_rite"), CommissionBook.READY, "撤离：可以交了")
	f.claim_commission(&"pantheon_first_rite")
	t.eq(f.meta.commissions.state_of(&"pantheon_first_rite"), CommissionBook.DONE, "点【完成】：办成")
	t.eq(f.meta.commissions.rep_of(Pantheon.FACTION), 10, "+10 到二档")
	t.check(Pantheon.god_open(f.meta, &"hunt"), "二档：狩猎之神能选")
	Support.cleanup(PREFIX)


static func run_legacy(t: TestCase) -> void:
	t.begin("377 · 老档迁移：通过过序章三 / 仓库有信物 / 奉过神 —— 算已到来、奉过的神都能选、信物折钱；只做一次；什么都没有的不来")
	var c := TestSupport.load_content("free_mode")
	var m := MetaState.new(GameFlow.load_meta_rules())
	m.grant_unlock(&"prologue3_done")
	m.history.append({"faith_top": {"id": "nature", "power": 40}})
	m.codex["charm_hunt"] = 1
	var charm := ItemInstance.create(c.items.get_def(&"charm_sun"))
	m.warehouse.try_add(charm, true)
	var funds := m.funds
	var got := Pantheon.migrate_legacy(m, c.items)
	t.check(bool(got["arrived"]) and Pantheon.arrived(m), "算已到来")
	t.check(m.gods_worshipped.has(&"nature") and m.gods_worshipped.has(&"hunt"), "奉过的、点亮过信物的神都记上")
	t.check(Pantheon.god_open(m, &"nature"), "一档也能选二档的自然之神（奉过）")
	t.eq(m.funds - funds, ItemValue.of(charm.def), "仓库里的信物折成金币")
	t.check(not m.warehouse.items().any(func(i: ItemInstance) -> bool: return i.def.is_anchor()), "仓库里不再有信物")
	t.eq(Pantheon.migrate_legacy(m, c.items)["refund"], 0, "只做一次")
	var fresh := MetaState.new(GameFlow.load_meta_rules())
	t.check(not bool(Pantheon.migrate_legacy(fresh, c.items)["arrived"]), "什么都没有的老档不来")
	var nm := GameFlow.new_meta(GameFlow.load_meta_rules())
	t.eq(nm.flag(Pantheon.MIGRATED), 1, "新档建档就标过")
