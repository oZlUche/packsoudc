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


static func run_pick_panel(t: TestCase) -> void:
	t.begin("377（作者 22:53 改）· 出征时的选神界面：第一项是无信者，没解锁的神写「？？？？」、不露神像、点不了；营地那一页只看、没有无信者")
	var c := TestSupport.load_content("free_mode", PackedStringArray(["faiths"]))
	var f := _new_flow(c)
	f.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	var PP: GDScript = load("res://ui/game/pantheon_panel.gd")
	var pick = PP.new()
	pick.setup(f, PP.PICK)
	var got: Array = []
	pick.picked.connect(func(fid: StringName): got.append(fid))
	t.not_null(pick.find_child("Shrine_none", true, false), "选神界面有无信者")
	var nature: Control = pick.find_child("Shrine_nature", true, false)
	t.check(nature != null and (nature.find_child("Name", true, false) as Label).text == UiText.t("pantheon.unknown"), "没解锁的写？？？？")
	t.check(nature != null and (nature.find_child("Image", true, false) as TextureRect).texture == null, "不露神像")
	t.check(not pick.choose(&"nature") and got.is_empty(), "点不了")
	t.check(pick.choose(&"skill") and got == [&"skill"] and f.meta.pantheon_choice == &"skill", "选技巧之神")
	t.check(pick.choose(&"") and f.meta.pantheon_choice == &"", "选无信者")
	var view = PP.new()
	view.setup(f)
	t.check(view.find_child("Shrine_none", true, false) == null and view.find_child("Choose_skill", true, false) == null, "营地那一页：没有无信者、没有选的键")
	pick.free()
	view.free()
	Support.cleanup(PREFIX)


## 第二批：序章三删了 —— 教程只剩两段，常规图接序章二
static func run_prologue3_gone(t: TestCase) -> void:
	t.begin("377 第二批 · 序章三删了：教程两段、自由模式 / 切片 / 机关沙漏都要序章二通关；切片基地清单没有信物；教程章没有信仰")
	var chs := GameFlow.load_chapters()
	t.check(not chs.any(func(ch: ChapterDef) -> bool: return ch.id == &"prologue_3"), "没有序章三")
	for id in [&"free_mode", &"clockwork_hourglass"]:
		var ch: ChapterDef = load(ContentPaths.asset_file("chapters", String(id)))
		t.eq(ch.requires_unlock, &"prologue2_done", "%s 要序章二通关" % id)
	var p2: ChapterDef = load(ContentPaths.asset_file("chapters", "prologue_2"))
	t.eq(p2.next_chapter, &"", "序章二后面没有教程了")
	var slice := FileAccess.get_file_as_string("res://data/manifests/slice_base.json")
	t.check(not slice.contains("charm_"), "切片基地清单没有信物")
	var c := TestSupport.load_content("prologue", PackedStringArray(["faiths", "characters"]))
	var f := Support.flow(c, PREFIX)
	f.meta = GameFlow.new_meta(f.meta_rules)
	f.chapters = GameFlow.load_chapters()
	var s := f.begin_direct(f.chapter_of(&"prologue"), 3)
	t.check(s != null and not s.faith_enabled, "新档的序章一没有信仰（万神院没来）")
	Support.cleanup(PREFIX)


## 第二批：信仰没开时百科不列讲神 / 信物 / 祭坛的页；开了列，「万神院与选神」配中英两套截图
static func run_help_gate(t: TestCase) -> void:
	t.begin("377 第二批 · 百科：万神院没来不列神、信物、祭坛那几页（经验值与等级照列）；来了列，选神那页有截图，中英各一套")
	var c := TestSupport.load_content("free_mode", PackedStringArray(["faiths"]))
	var f := _new_flow(c)
	f.help_pages = GameFlow.load_help_pages()
	t.check(not f.faith_open(), "新档：信仰没开")
	var book := f.encyclopedia()
	t.check(not book.has_page("god_brute") and not book.has_page("pantheon_choose") and not book.has_page("altar_offering"), "不列神、选神、神坛献祭")
	t.check(book.has_page("faith_power_and_tiers"), "经验值与等级照列")
	f.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	book = f.encyclopedia()
	t.check(book.has_page("god_brute") and book.has_page("pantheon_choose"), "万神院来了：列出来（百科重造）")
	var page := f.help_page(&"pantheon_choose")
	t.check(page != null and page.needs_faith and Array(page.shots) == ["pantheon_pick"], "选神那页挂一张截图")
	for lang in ["zh", "en"]:
		var paths := page.shot_paths(lang) if page != null else [] as Array[String]
		t.check(paths.size() == 1 and paths[0].contains("/%s/" % lang) and ResourceLoader.exists(paths[0]), "%s 的截图在（%s）" % [lang, str(paths)])
	Support.cleanup(PREFIX)


## 第二批：图鉴在信仰没开时不列信物这类归神的道具
static func frame_codex_gate(t: TestCase, root: Window) -> void:
	t.begin("377 第二批 · 图鉴：万神院没来不列信物（赐福版也不进异体）；来了列")
	var c := TestSupport.load_content("free_mode", PackedStringArray(["faiths"]))
	var f := _new_flow(c)
	var W178: GDScript = load("res://tests/ui/test_base_warehouse_178.gd")
	for arrived in [false, true]:
		if arrived:
			f.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
		var screen: Control = W178._screen(f, root)
		screen.show_tab("codex")
		var ids: Array = screen.codex_tiles().map(func(tl): return (tl as CodexTile).def.id)
		var variants: Array = []
		for tl in screen.codex_tiles():
			for v in (tl as CodexTile).variants:
				if (v as ItemDef).has_faith():
					variants.append((v as ItemDef).id)
		if arrived:
			t.check(ids.has(&"charm_brute"), "来了：列信物")
		else:
			t.check(not ids.is_empty() and not ids.has(&"charm_brute") and not ids.has(&"charm_sun"), "没来：不列信物")
			t.check(variants.is_empty(), "没来：异体里没有归神的（%d）" % variants.size())
		screen.queue_free()
	Support.cleanup(PREFIX)


## 第二批：第一次选神 —— 先翻开「万神院与选神」，合上后教练层指三处，看完记住；第二次不再放。
## 383：选神从【开始探索】跳出的弹窗挪到开局第一屏的信仰横条：万神院刚到后的第一次出征，信仰横条自己展开一次
static func frame_first_god_pick(t: TestCase, root: Window) -> void:
	t.begin("377 第二批 / 383 · 第一次选神：开局第一屏信仰横条自己展开，先翻开选神那页（带截图），合上放教练层（神龛、无信者、奉祂），看完记住，第二次直接选")
	var c := TestSupport.load_content("free_mode", PackedStringArray(["faiths"]))
	var f := _new_flow(c)
	f.help_pages = GameFlow.load_help_pages()
	f.meta.commissions.arrived[String(Pantheon.FACTION)] = 0
	f.meta.set_flag(StringName("arrival_seen_" + String(Pantheon.FACTION)))
	var W178: GDScript = load("res://tests/ui/test_base_warehouse_178.gd")
	var screen: Control = W178._screen(f, root)
	t.check(screen.find_children("*", "", true, false).all(func(n): return n.name != "GodPick"), "383：基地不再有选神弹窗")
	screen.queue_free()
	var setup: Control = load("res://ui/game/setup_screen.gd").new()
	setup.screen = GameFlow.Screen.SETUP
	setup.flow = f
	setup.font = ThemeDB.fallback_font
	root.add_child(setup)
	setup.open({})
	t.check(setup.bar(setup.BAR_FAITH).open, "信仰横条自己展开了")
	var book = setup.god_book()
	t.check(book != null and book.current_page() == "pantheon_choose", "翻开的是选神那页")
	t.check(book != null and book.shot_count() == 1, "页头一张截图")
	t.check(setup.escape() and setup.god_book() == null and setup.page() == 0, "Esc 先合上书，还在第一屏")
	setup._show_god_coach()
	var coach: CoachOverlay = setup.god_coach()
	t.check(coach != null and coach.steps.size() == 3, "教练层三步")
	if coach != null:
		for i in 3:
			t.check(setup.god_target(setup.faith_panel(), StringName(String((coach.steps[i] as Dictionary).get("target", "")))) is Rect2, "第 %d 步有目标" % (i + 1))
		for i in 3:
			coach.next()
	t.check(f.meta.coach_seen.has("god_pick"), "看完记住")
	setup.queue_free()
	setup = load("res://ui/game/setup_screen.gd").new()
	setup.screen = GameFlow.Screen.SETUP
	setup.flow = f
	setup.font = ThemeDB.fallback_font
	root.add_child(setup)
	setup.open({})
	t.check(not setup.bar(setup.BAR_FAITH).open, "第二次：横条折叠着")
	setup.open_bar(setup.BAR_FAITH)
	t.check(setup.god_book() == null, "展开也不再翻书")
	setup._show_god_coach()
	t.is_null(setup.god_coach(), "也不再放教练层")
	setup.queue_free()
	Support.cleanup(PREFIX)


## 第二批：第一次升级弹牌时讲一遍三选一（三张、换牌、剔牌），看完记住
static func frame_first_level_pick(t: TestCase, root: Window) -> void:
	t.begin("377 第二批 · 第一次升级：选牌窗上放教练层（三张牌、换牌、剔牌），看完记住，再升级不放")
	var NodeScreens: GDScript = load("res://tests/ui/test_node_screens.gd")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("pantheon_lv")
	var game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	game.save_path = String(Support.paths("pantheon_lv")["run"])
	game.meta_path = String(Support.paths("pantheon_lv")["meta"])
	game.settings_path = String(Support.paths("pantheon_lv")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	var run := flow.begin(c.chapter, kit, 5)
	if run == null:
		t.check(false, "开局")
		game.queue_free()
		Support.cleanup("pantheon_lv")
		return
	if run.phase == RunState.Phase.PICK_SPAWN:
		flow.pick_spawn(run.map.entry_ids[0])
	var lv := LevelModule.of(run)
	lv.gain(500.0, &"test")
	var map = game.base()
	t.check(lv.pending() > 0 and map.has_method("show_level_pick"), "欠着选牌（%d）" % lv.pending())
	if not map.level_pick_open():
		map.show_level_pick()
	t.check(CoachOverlay.due(flow, &"level_pick"), "还没讲过")
	map._show_level_coach()
	var coach: CoachOverlay = map.coach()
	t.check(coach != null and coach.steps.size() == 3, "教练层三步")
	var panel: LevelPickPanel = map.level_pick_panel()
	t.check(panel != null and panel.coach_rect(&"nothing") == Rect2(), "不认得的目标给空矩形")
	if coach != null:
		for i in 3:
			coach.next()
	t.check(flow.meta.coach_seen.has("level_pick") and map.coach() == null, "看完记住、收掉")
	t.check(map.level_pick_open(), "选牌窗还开着")
	map._show_level_coach()
	t.is_null(map.coach(), "第二次不放")
	game.queue_free()
	Support.cleanup("pantheon_lv")
