## 354 第一批：炼金术与万物之尘 —— 魔法师协会信赖（50）+ 剧情《万物可分》开后勤「炼金」；
## 素材丢进去按基础价 × (1 − 折损) 得尘（几件合起来向下取整、每件至少 1），折损 40%、代言 25%；
## 铁匠铺打造记下「打造过的配方」；局外存档 v8（老档尘 0、记录空）
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const Support := preload("res://tests/run/flow_support.gd")
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const PREFIX := "alchemy_354"


static func _done(book: CommissionBook, ids: Array) -> void:
	for id in ids:
		book.entries[String(id)] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}


## 协会到信赖、许可单办过，办《万物可分》
static func _open(f: GameFlow) -> void:
	_done(f.meta.commissions, [&"society_first_survey", &"society_copy_recipe", &"society_identify_ore", &"society_permit"])
	f.meta.commissions.rep["society"] = 50
	f.sync_commissions()
	f.report_commission(&"society_alchemy")


static func run_content(t: TestCase) -> void:
	t.begin("354 · 内容：炼金规矩导得进来、折损都在 20% 到 50%；《万物可分》要信赖、开炼金")
	var r := Alchemy.load_rules()
	t.eq(r.id, AlchemyRules.ID, "规矩资产导出来了")
	t.eq([r.loss_at(3), r.loss_at(4)], [0.4, 0.25], "信赖 40%、代言 25%")
	t.check(r.loss_by_tier.all(func(x: float) -> bool: return x >= 0.2 and x <= 0.5), "都在作者说的范围里")
	var bad := ImportReport.new()
	ContentImporter.import_alchemy_rules({"id": "alchemy", "loss_by_tier": [0.6]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "折损 60%：导入报错")
	var d := Commissions.opener_of(Alchemy.ID)
	t.eq(d.id if d != null else &"", &"society_alchemy", "炼金由《万物可分》开")
	t.eq(Commissions.required_tier(d), 3, "要信赖")
	t.eq(Commissions.validate_all(Commissions.defs(), Commissions.factions()), [] as Array[String], "前置、阵营查得过")


static func run_rules(t: TestCase) -> void:
	t.begin("354 第七节 · 能丢什么：什么都能（素材、武器、剧情独有、珍宝、贵重品）；只有锁住的不能；尘值 = 价值（和出售同一个数）")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := T110._meta()
	var ore := T110._add(m, db, &"iron_ore")
	var knife := T110._add(m, db, &"knife")
	var core := T110._add(m, db, &"jimie_core_fire")
	var shard := T110._add(m, db, &"pale_shard")
	t.eq(Alchemy.why_not(ore), "", "铁矿石：能")
	t.eq(Alchemy.dust_value(ore.def), ItemValue.of(ore.def), "尘值 = 基础价")
	t.eq(Alchemy.dust_value(ore.def), 24, "铁矿石 24")
	t.eq(Alchemy.why_not(knife), "", "武器：能")
	t.eq(Alchemy.why_not(core), "", "火之核（剧情独有）：能")
	t.eq(Alchemy.why_not(shard), "", "灰白色的金属碎片（珍宝）：能")
	for id in [&"antidote_kit", &"bitter_root", &"wooden_idol", &"ticket_standard"]:
		var x := T110._add(m, db, id)
		t.check(x != null and Alchemy.can_dissolve(x), "%s：能" % id)
	t.check(not Alchemy.guarded(m, ore) and not Alchemy.guarded(m, knife), "铁矿石、刀：不用危险确认")
	t.check(Alchemy.guarded(m, core) and Alchemy.guarded(m, shard), "火之核、碎片：要危险确认")
	t.eq(Alchemy.dust_value_of(knife), ItemValue.of_instance(knife), "尘值 = 这一件的价值")
	knife.state["value"] = 3
	t.eq(Alchemy.dust_value_of(knife), 3, "价值记在这一件上：照它")
	ore.set_locked(true)
	t.eq(Alchemy.why_not(ore), Alchemy.WHY_LOCKED, "锁住的：不能")


static func run_auto(t: TestCase) -> void:
	t.begin("354 第七节 · 一键炼金：跳过锁定、收藏、剧情独有、委托这一步要交的、出征携带（按件数）；预览数和实得一致")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := T110._meta()
	var pool: Array = []
	for id in [&"iron_ore", &"iron_ore", &"iron_ore", &"knife", &"knife", &"jimie_core_fire", &"dried_herbs", &"dried_herbs", &"dried_herbs", &"oak_log"]:
		pool.append(T110._add(m, db, id))
	(pool[0] as ItemInstance).set_locked(true)
	m.toggle_favorite(&"oak_log")
	m.last_carry = [{"id": "knife", "origin": [0, 0], "rot": 0}]
	m.commissions.entries["greylamp_check_medkits"] = {"state": CommissionBook.TAKEN, "stage": 0, "progress": 0, "keys": [], "times": 0, "pick": "", "seq": 1}
	t.eq(Alchemy.hand_in_uids(m).size(), 2, "核对药包要两件草药：两件挡着")
	var plan := Alchemy.auto_picks(m, pool)
	t.eq(int(plan["skipped"]), 6, "跳过 6 件")
	t.eq(plan["why"], {Alchemy.SKIP_LOCKED: 1, Alchemy.SKIP_FAVORITE: 1, Alchemy.SKIP_GUARDED: 3, Alchemy.SKIP_CARRY: 1}, "锁定 1、收藏 1、独有 + 委托 3、携带 1")
	t.eq((plan["uids"] as Array).size(), 4, "炼 4 件：两件铁矿石、一把刀、一件草药")
	var p := Alchemy.preview(m, plan["uids"])
	var got := Alchemy.dissolve(m, plan["uids"])
	t.eq([int(got["count"]), int(got["dust"])], [int(p["count"]), int(p["dust"])], "实得 = 预览")
	t.check(m.warehouse.has_item((pool[5] as ItemInstance).uid), "火之核还在")
	t.eq(Alchemy.guarded_of(m, [(pool[5] as ItemInstance).uid, (pool[0] as ItemInstance).uid]).size(), 1, "手动勾火之核：要危险确认（锁着的不算勾上）")


static func run_dissolve(t: TestCase) -> void:
	t.begin("354 · 分解：预览 = 实得；几件合起来向下取整、每件至少 1；代言 25%；不能丢的不动")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := T110._meta()
	var ores: Array = []
	for k in 5:
		ores.append(T110._add(m, db, &"iron_ore").uid)
	var knife := T110._add(m, db, &"knife")
	knife.set_locked(true)
	t.eq(Alchemy.loss(m), 0.4, "协会初识：40%")
	var p := Alchemy.preview(m, ores + [knife.uid, ores[0]])
	t.eq([int(p["count"]), int(p["value"]), int(p["dust"])], [5, 120, 72], "五件铁矿石 120 → 72（重复的、锁着的刀不算）")
	t.eq(int(p["funds"]), 5 * MetaState.sell_price_of(m.warehouse.get_item(int(ores[0]))), "顺带写出售价")
	var got := Alchemy.dissolve(m, ores + [knife.uid])
	t.eq([int(got["count"]), int(got["dust"])], [5, 72], "实得和预览一样")
	t.eq(m.dust, 72, "尘 72")
	t.check(m.warehouse.has_item(knife.uid), "刀还在")
	t.eq(m.warehouse.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"iron_ore").size(), 0, "铁矿石都没了")
	t.eq(Alchemy.dissolve(m, [knife.uid]), {"count": 0, "dust": 0}, "只有锁着的刀：什么也不动")
	t.eq(Alchemy.yield_of(5, 1, 0.4), 3, "一件 5 → 3")
	t.eq(Alchemy.yield_of(3, 2, 0.4), 2, "两件合 3 → 1.8 取整 1，每件至少 1 → 2")
	m.commissions.rep["society"] = 100
	m.commissions.signed["society"] = true
	t.eq(Alchemy.loss(m), 0.25, "代言：25%")
	var w := T110._add(m, db, &"iron_ore")
	t.eq(int(Alchemy.dissolve(m, [w.uid])["dust"]), 18, "24 → 18")


static func run_flow(t: TestCase) -> void:
	t.begin("354 · 开放：没开分不了；信赖时《万物可分》自动接上，办成开炼金、后勤列出；分了存档")
	ItemInstance.reset_uid_counter()
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	Support.pass_tutorials(f)
	var ore := ItemInstance.create(c.items.get_def(&"iron_ore"))
	ore.uid = f.meta.allocate_uid()
	f.meta.warehouse.try_add(ore)
	t.check(not f.alchemy_listed(), "协会没到信赖：不列")
	t.eq(int(f.dissolve_items([ore.uid])["count"]), 0, "没开：分不了")
	_done(f.meta.commissions, [&"society_first_survey", &"society_copy_recipe", &"society_identify_ore", &"society_permit"])
	f.meta.commissions.rep["society"] = 50
	f.sync_commissions()
	t.eq(f.meta.commissions.state_of(&"society_alchemy"), CommissionBook.TAKEN, "信赖：《万物可分》接上")
	t.check(f.alchemy_listed() and not f.alchemy_open(), "列出来了，还没开")
	f.report_commission(&"society_alchemy")
	t.check(f.alchemy_open(), "办成：开了")
	t.eq(int(f.dissolve_items([ore.uid])["dust"]), 14, "铁矿石 24 → 14")
	var back := MetaSave.from_text(FileAccess.get_file_as_string(String(Support.paths(PREFIX)["meta"])), c.items, c.meta_rules)
	t.check(back != null and back.dust == 14, "存了档")
	Support.cleanup(PREFIX)


static func run_forged_record(t: TestCase) -> void:
	t.begin("354 · 「打造过的配方」：打一次记下（不重复）；存档往返；老档 v7 → 尘 0、记录空；358：v8 → v9 按图鉴补打造过")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := T110._meta()
	m.facility_levels[Smithy.ID] = 1
	m.funds = 500
	var r := SmithRecipeDef.new()
	r.id = &"t_shortsword"
	r.output = &"shortsword"
	r.inputs = {"iron_ore": 1}
	r.funds = 10
	r.level = 1
	t.check(not m.has_forged(r.id), "没打过")
	for k in 2:
		T110._add(m, db, &"iron_ore")
		Smithy.forge(m, r, db)
	t.check(m.has_forged(r.id), "打过了")
	t.eq(m.forged_recipes.size(), 1, "不重复记")
	m.dust = 9
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.check(back != null and back.dust == 9 and back.has_forged(r.id), "存档往返")
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/meta_v7.json")
	var src: Dictionary = JSON.parse_string(raw)
	t.eq(int(src.get("version", 0)), 7, "冻结样本是 v7")
	var up := MetaMigrations.upgrade(src)
	t.eq([int(up["version"]), int(up["dust"]), (up["forged_recipes"] as Array).size()], [MetaState.SAVE_VERSION, 0, 0], "升到当前版：尘 0、记录空（图鉴空）")
	var v8: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/meta_v8.json"))
	t.eq(int(v8.get("version", 0)), 8, "冻结样本是 v8")
	var up8 := MetaMigrations.upgrade(v8)
	t.eq(int(up8["version"]), MetaState.SAVE_VERSION, "v8 升到当前版")
	t.check((up8["forged_recipes"] as Array).has("smith_warhammer"), "358：图鉴里亮了战锤 —— 战锤算打造过")
	t.check((up8["forged_recipes"] as Array).has("smith_leather_armor"), "原来记着的皮甲还在")
	t.eq(int(up8["dust"]), 5, "尘不动")
	var m8 := MetaSave.from_text(FileAccess.get_file_as_string("res://tests/fixtures/meta_v8.json"), db, GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.check(m8 != null and m8.has_forged(&"smith_warhammer"), "读档：战锤能用尘补")
	var old := MetaSave.from_text(raw, db, GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.check(old != null and old.dust == 0 and old.forged_recipes.is_empty() and String(old.nursery.plot(0)["crop"]) == "rope_hemp", "老档读得回来，苗圃照旧")


static func frame_page(t: TestCase, root: Window) -> void:
	t.begin("354 · 后勤「炼金」：没到信赖不列；到了没办是说明板；开了右边仓库什么都勾得上（锁的不行），【炼化】两步；勾了独有件写拿不回来；一键炼金没选标签暗着；离开页清勾选；字不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	Support.pass_tutorials(f)
	var s: Control = W178._screen(f, root)
	t.check(not (s.sub_tab_buttons() as Dictionary).has("alchemy"), "没到信赖：没有炼金键")
	s.queue_free()
	_done(f.meta.commissions, [&"society_first_survey", &"society_copy_recipe", &"society_identify_ore", &"society_permit"])
	f.meta.commissions.rep["society"] = 50
	f.sync_commissions()
	s = W178._screen(f, root)
	t.check((s.sub_tab_buttons() as Dictionary).has("alchemy"), "信赖：有炼金键")
	s.show_tab("alchemy")
	t.check(s.locked_page().visible, "没办《万物可分》：说明板")
	s.queue_free()
	f.report_commission(&"society_alchemy")
	var ore := T110._add(f.meta, f.items, &"iron_ore")
	var knife := T110._add(f.meta, f.items, &"knife")
	s = W178._screen(f, root)
	s.show_tab("alchemy")
	var p = s.alchemy_panel()
	t.check(p != null and p.is_visible_in_tree() and not s.locked_page().visible, "开了：炼金页")
	t.check(s.alchemy_mode() and not s.sell_mode(), "右边仓库在炼金勾选里（不是出售）")
	var shelf: WarehousePages = s.shelf()
	t.check(shelf.toggle_select(ore.uid), "勾上铁矿石")
	knife.set_locked(true)
	t.check(not shelf.toggle_select(knife.uid), "锁着的刀勾不上")
	t.check(p.auto_btn.disabled, "没选标签：一键炼金暗着")
	t.eq(int(p.preview()["dust"]), 14, "预览 14")
	t.check(not p._band.visible, "铁矿石：不画警告带")
	t.check(p._center.visible, "勾了：阵心画尘")
	var more: Array = []
	for k in 3:
		var x := T110._add(f.meta, f.items, &"oak_log")
		shelf.toggle_select(x.uid)
		more.append(x)
	var groups: Array = p.corners()
	t.eq([(groups[0] as Array).size(), (groups[1] as Array).size(), (groups[2] as Array).size()], [2, 1, 1], "四件轮流分到三个角")
	t.check(p._nodes[0].get_node_or_null("Count") != null, "两件的角下写 ×n")
	for x in more:
		shelf.toggle_select((x as ItemInstance).uid)
	t.eq(Bare.audit(p, "alchemy354"), [] as Array[String], "字不裸")
	t.check((p.press_go() as Dictionary).is_empty(), "第一下只是「再点一次」")
	t.eq(int((p.press_go() as Dictionary).get("dust", 0)), 14, "第二下炼了")
	t.eq(f.meta.dust, 14, "尘 14")
	t.check(not f.meta.warehouse.has_item(ore.uid) and f.meta.warehouse.has_item(knife.uid), "铁矿石没了，刀还在")
	var core := T110._add(f.meta, f.items, &"jimie_core_fire")
	t.check(shelf.toggle_select(core.uid), "火之核勾得上")
	t.check(p._band.visible and p._danger.text == Names.of(core.def), "纸条警告带：火之核")
	t.check(p._nodes.any(func(n: Control) -> bool: return n.get_node_or_null("GuardRing") != null), "火之核那一角套红圈")
	t.eq(p._danger_text([core, core]), UiText.t("alchemy.guard") % (Names.of(core.def) + " ×2"), "同名的合成「×2」")
	var warned: Array = []
	p.said.connect(func(text: String, is_warn: bool): warned.append([text, is_warn]))
	p.press_go()
	t.check(not warned.is_empty() and bool(warned[0][1]), "第一下【炼化】再说一遍（警告）")
	p._reset_confirm()
	shelf.clear_selection()
	for k in 2:
		T110._add(f.meta, f.items, &"iron_ore")
	shelf.set_filter(&"material", -1)
	t.eq(String(p.tag_pick.get_item_metadata(p.tag_pick.selected)), "material", "筛选行跟着")
	t.check(not p.auto_btn.disabled, "选了标签：一键炼金亮")
	var plan: Dictionary = p.auto_plan()
	p.one_click()
	t.check(shelf.selected.size() == (plan["uids"] as Array).size() and shelf.selected.size() >= 2, "一键：勾上合筛选能炼的（至少两件铁矿石）")
	t.check(not shelf.selected.has(core.uid), "火之核不在内")
	t.check(p._skip.visible, "纸条写跳过几件")
	t.eq(p.auto_btn.text, UiText.t("sell.select_none"), "再点 = 全不选")
	p.one_click()
	t.check(shelf.selected.is_empty(), "全不选了")
	shelf.set_filter(&"", -1)
	s.show_tab("warehouse")
	t.check(not shelf.select_mode, "离开炼金页：勾选模式关了")
	s.queue_free()
	W178._cleanup()


static func run_dust_forge(t: TestCase) -> void:
	t.begin("354 第二批 · 以尘代料：没打造过不能补；只补缺的；尘按尘值全额扣、工钱照付；尘不够不打；魔晶石格、传说格不能补；材料格按最便宜的合格品收")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := T110._meta()
	m.facility_levels[Smithy.ID] = 1
	m.funds = 500
	m.dust = 100
	var r := SmithRecipeDef.new()
	r.id = &"t_shortsword"
	r.output = &"shortsword"
	r.inputs = {"iron_ore": 2, "hardwood_plank": 1}
	r.funds = 40
	r.level = 1
	T110._add(m, db, &"iron_ore")
	var full := {"iron_ore": 1, "hardwood_plank": 1}
	t.eq(Smithy.can_forge(m, r, db, full), UiText.t("smithy.dust_not_forged"), "没打造过：不能补")
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.missing"), "不补：缺素材")
	m.mark_forged(r.id)
	t.eq(Alchemy.line_cost(r, "iron_ore", db), 24, "铁矿石一件 24 尘")
	t.eq(Alchemy.line_cost(r, "hardwood_plank", db), 60, "硬木板一件 60 尘")
	t.eq(Smithy.can_forge(m, r, db, {"iron_ore": 2, "hardwood_plank": 1}), UiText.t("smithy.dust_no"), "有一件铁矿石：只能补一件")
	t.eq(Smithy.can_forge(m, r, db, {"iron_ore": 1}), UiText.t("smithy.missing"), "只补铁矿石：还缺硬木板")
	m.dust = 83
	t.eq(Smithy.can_forge(m, r, db, full), UiText.t("smithy.no_dust"), "84 尘，只有 83：不打")
	m.dust = 100
	t.eq(Smithy.can_forge(m, r, db, full), "", "补齐了")
	var got := Smithy.forge(m, r, db, full)
	t.check(got != null and got.def.id == &"shortsword", "打出来了")
	t.eq([m.dust, m.funds], [16, 460], "扣 84 尘、40 币工钱")
	t.eq(m.warehouse.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"iron_ore").size(), 0, "那件真铁矿石扣了")
	var maul := SmithRecipeDef.find(SmithRecipeDef.load_all(), &"forge_flame_meteor_maul")
	var crys := SmithRecipeDef.new()     # 359 起配方里没有魔晶石格了，规则仍在
	crys.material_slots = [{"material": "crystal:fire", "min": 3, "count": 1}] as Array[Dictionary]
	t.eq(Alchemy.line_cost(crys, "slot:0", db), -1, "火系魔晶石格：不能补")
	t.check(Alchemy.line_cost(maul, "slot:0", db) > 0 and Alchemy.line_cost(maul, "slot:1", db) > 0, "359：晶石素材格、金属格都能补")
	t.eq(Alchemy.line_cost(maul, "fire_gland", db), -1, "359：火焰腺（属性素材）不能补")
	var imperial := SmithRecipeDef.find(SmithRecipeDef.load_all(), &"forge_imperial_sword")
	t.eq(Alchemy.line_cost(imperial, "slot:0", db), -1, "传说金属格：不能补")
	var armor := SmithRecipeDef.find(SmithRecipeDef.load_all(), &"smith_leather_armor")
	t.eq(Alchemy.line_cost(armor, "slot:0", db), 24, "皮革 ≥优良：按最便宜的合格品（熟皮革 24），不按一格 12")


static func frame_smithy_dust(t: TestCase, root: Window) -> void:
	t.begin("354 第二批 · 铁匠铺：钱牌下露尘数；打造过的配方点一样缺的素材切换用尘补，数牌写「有几+补几 / 要几」、工钱下写尘；打了扣尘")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	Support.pass_tutorials(f)
	_open(f)
	f.meta.dust = 100
	f.meta.funds = 200
	f.meta.mark_forged(&"smith_warhammer")
	f.smith_recipes = SmithRecipeDef.load_all()
	var s: Control = W178._screen(f, root)
	s.show_tab("smithy")
	var sp = s.smithy_panel()
	sp.open_recipe(&"smith_warhammer")
	t.check(sp._dust_have.visible and sp._dust_have_label.text == "100", "钱牌下：尘 100")
	sp.toggle_dust("iron_ore")
	sp.toggle_dust("oak_log")
	t.eq(sp.dust_choice(), {"iron_ore": 2, "oak_log": 1}, "缺的全用尘补")
	var lines: Array[String] = sp.recipe_scroll().material_lines()
	t.check(lines.has("0+2 / 2") and lines.has("0+1 / 1"), "数牌写「有几+补几 / 要几」")
	t.check(sp.recipe_scroll()._dust_row.visible and sp.recipe_scroll()._dust_label.text == "63", "工钱下：尘 63")
	t.eq(sp.forge(&"smith_warhammer"), "", "打了")
	t.eq(f.meta.dust, 37, "扣了 63 尘")
	t.check(sp.dust_choice().is_empty(), "打完清掉")
	s.queue_free()
	W178._cleanup()
