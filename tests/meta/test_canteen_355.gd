## 355 第一批：灰灯食堂 —— 灰灯到受托（25）+ 剧情《开伙》开后勤「食堂」，带食材仓库与锅（只收「食材」）；
## 一锅 = 四类各管一种属性、固定值和百分比分开相加、主食给饱腹；出征吃掉一锅（[MealModule]），每到新节点饱腹减 1，归零加成失效
## （负重那份多留一步）；水果的回血是独立一项（[member CombatantSpec.meal_regen_hp]）
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const Support := preload("res://tests/run/flow_support.gd")
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const CS := preload("res://tests/run/test_character_setup.gd")
const G342 := preload("res://tests/meta/test_growers_342b3.gd")
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
	t.eq(r.entries.size(), 48, "48 件（报告 355 第五节 32 件 + 报告 394 的 12 件肉和狼心 + 395 的三件腺体）")
	var db := T110._db()
	var tagged: Array = []
	for id in db.ids(true):
		if Canteen.is_ingredient(db.get_def(id)):
			tagged.append(String(id))
	tagged.sort()
	var keys: Array = r.entries.keys()
	keys.sort()
	t.eq(tagged, keys, "带「食材」标签的 = 表里的")
	for id in [&"ration", &"salted_meat", &"field_rations", &"dried_herbs"]:
		t.check(not Canteen.is_ingredient(db.get_def(id)), "%s 不是食材" % id)
	var want := {CanteenRules.STAPLE: [4, 4], CanteenRules.MEAT: [15, 6], CanteenRules.VEG: [4, 3], CanteenRules.FRUIT: [3, 3]}
	for cat in CanteenRules.CATEGORIES:
		var flat := 0
		var pct := 0
		for k in r.entries:
			if StringName(String(r.entries[k]["category"])) == cat:
				if (r.entries[k] as Dictionary).has("flat"):
					flat += 1
				elif (r.entries[k] as Dictionary).has("pct"):
					pct += 1     # 395：器官两样都不写（下锅给特性）
		t.eq([flat, pct], want[cat], "%s：固定值、百分比各几件照第五节" % cat)
	t.eq([r.pot_size(), r.store_size()], [Vector2i(4, 4), Vector2i(6, 6)], "开放时锅 4×4、食材仓库 6×6")
	var gl := Commissions.faction(r.faction)
	t.eq(Commissions.nodes_of(gl).filter(func(n: Dictionary) -> bool: return String(n.get("effect", "")).begins_with("canteen_")).map(func(n: Dictionary) -> Array: return [int(n["rep"]), String(n["effect"]), [int(n["value"][0]), int(n["value"][1])]]),
		[[50, "canteen_pot", [5, 5]], [50, "canteen_store", [8, 8]], [100, "canteen_pot", [6, 6]], [100, "canteen_store", [10, 8]]], "389：50 锅 5×5、仓库 8×8；100 锅 6×6、仓库 10×8")
	t.eq(float(r.entry(&"wild_berry")["flat"]), 0.9, "野莓每秒 0.9（作者 16:41 定 0.5，403 回复 ×1.8）")
	var bad := ImportReport.new()
	ContentImporter.import_canteen_rules({"id": "canteen", "entries": {"x": {"category": "soup", "flat": 1, "pct": 2}}}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "不认识的类别、固定值百分比都写：导入报错")
	var d := Commissions.opener_of(Canteen.ID)
	t.eq(d.id if d != null else &"", &"greylamp_canteen", "食堂由《开伙》开")
	t.eq(Commissions.required_rep(d), 25, "要 25 声望")
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
	t.eq([float(meal["flat"]["regen_hp"]), float(meal["pct"]["regen_hp"])], [1.8, 1.0], "每秒回血 0.9 × 2、生命上限 1%")
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
	var m0 := T110._meta()
	m0.commissions.rep["greylamp"] = 49
	t.eq(Canteen.sizes(m0), {"pot": Vector2i(4, 4), "store": Vector2i(6, 6)}, "49：锅 4×4、仓库 6×6")
	m0.commissions.rep["greylamp"] = 50
	t.eq(Canteen.sizes(m0), {"pot": Vector2i(5, 5), "store": Vector2i(8, 8)}, "50：锅 5×5、仓库 8×8")
	m0.commissions.rep["greylamp"] = 25
	t.check(c.fit(Canteen.sizes(m0)).is_empty() and c.pot.size == Vector2i(4, 4), "25：4×4 不动")
	m0.commissions.rep["greylamp"] = 100
	t.check(c.fit(Canteen.sizes(m0)).is_empty(), "100（不用先做完结案）：没有放不下的")
	t.eq([c.pot.size, c.store.size], [Vector2i(6, 6), Vector2i(10, 8)], "锅 6×6、仓库 10×8")
	t.eq(c.pot.get_item(3).origin, Vector2i(3, 2), "山薯原位")
	c.fit({"pot": Vector2i(4, 4), "store": Vector2i(6, 6)})
	t.eq(c.pot.size, Vector2i(6, 6), "给小的不缩")
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


static func run_menus(t: TestCase) -> void:
	t.begin("355 第二批 · 收藏菜单：收的是种类和摆法；一键重做从食材仓库按原样取料，缺料的格标出来；改名、删除；最多 8 份；存档读回来一样")
	var db := T110._db()
	var c := Canteen.new()
	t.eq(c.save_menu(), -1, "空锅收藏不了")
	c.pot.place(_inst(db, &"mountain_yam", 1), Vector2i(0, 0), 0)
	c.pot.place(_inst(db, &"wild_berry", 2), Vector2i(2, 0), 0)
	c.pot.place(_inst(db, &"wild_berry", 3), Vector2i(3, 0), 0)
	t.eq(c.save_menu("  "), 0, "收藏第一份")
	t.eq(c.menu_name(), UiText.t("canteen.menu_default") % 1, "空名 = 「菜单 1」")
	t.eq(c.gaps(), [] as Array[Dictionary], "刚收藏：没缺")
	t.check(c.rename_menu(0, "进山饭这个名字很长很长很长"), "改名")
	t.eq(c.menu_name().length(), Canteen.NAME_MAX, "名字截到 %d 个字" % Canteen.NAME_MAX)
	t.check(not c.rename_menu(0, "   "), "空名不认")
	# 吃掉一锅（锅清空），仓库里只剩一个山薯、一个野莓
	c.pot.clear()
	t.eq(c.gaps().size(), 3, "锅空了：三格都缺")
	c.store.try_add(_inst(db, &"wild_berry", 4))
	c.store.try_add(_inst(db, &"mountain_yam", 5))
	c.store.try_add(_inst(db, &"sour_wheat", 6))
	var gaps := c.load_menu(0)
	t.eq(gaps.size(), 1, "一键重做：缺一个野莓")
	t.eq(c.pot.get_item(5).origin if c.pot.has_item(5) else Vector2i(-1, -1), Vector2i(0, 0), "山薯按原样摆在 (0, 0)")
	t.check(c.pot.has_item(4) and c.store.has_item(6), "野莓取进锅、酸麦留在仓库")
	t.eq(c.gaps().size(), 1, "锅上标一格缺料")
	# 换一样：锅里多放的酸麦回仓库；原位的留着
	c.store.remove(6)
	var wheat := _inst(db, &"sour_wheat", 6)
	c.pot.place(wheat, Vector2i(0, 3), 0)
	c.store.try_add(_inst(db, &"wild_berry", 7))
	t.eq(c.load_menu(0).size(), 0, "补了料再重做：不缺了")
	t.check(c.store.has_item(6) and c.pot.has_item(5) and c.pot.has_item(4), "多放的酸麦回仓库，原位的没挪")
	var ids: Dictionary = c.current_meal()["ids"]
	t.eq([ids.size(), int(ids.get("mountain_yam", 0)), int(ids.get("wild_berry", 0))], [2, 1, 2], "锅里正好是收藏的那一锅")
	for i in Canteen.MAX_MENUS - 1:
		c.save_menu()
	t.eq(c.menus.size(), Canteen.MAX_MENUS, "8 份")
	t.eq(c.save_menu(), -1, "满了收藏不了")
	t.eq(c.menus[1]["name"], UiText.t("canteen.menu_default") % 1, "默认名取最小的空号")
	var m := T110._meta()
	m.canteen = c
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.eq(back.canteen.menus, c.menus, "存档读回来，收藏一样")
	t.eq(back.canteen.active, c.active, "照哪份一样")
	t.check(c.delete_menu(c.active), "删掉锅照的那份")
	t.eq([c.active, c.menu_name(), c.gaps().size()], [-1, "", 0], "锅不再算照收藏")
	t.check(c.delete_menu(0) and c.menus.size() == Canteen.MAX_MENUS - 2, "再删一份")
	t.check(not c.delete_menu(99), "没有的不删")


static func run_viewer(t: TestCase) -> void:
	t.begin("355 第二批 · 按当前角色算：终值、单件食材加多少（固定值和百分比哪个划算一眼看出）；提示窗写出来；没有负重的角色不写负重")
	var db := T110._db()
	var ch := CharacterDef.new()
	ch.id = &"cook_test"
	ch.display_name = "试吃"
	ch.base_stats = {"max_stamina": 80.0, "max_hp": 200.0}
	ch.weight_capacity = 20
	var scrap := Canteen.single_meal(db.get_def(&"meat_scrap"))
	var wing := Canteen.single_meal(db.get_def(&"fowl_wing"))
	t.eq(Canteen.gain_for(ch, scrap, BattleStats.MAX_STAMINA), 1.0, "兽肉碎：+1")
	t.check(is_equal_approx(Canteen.gain_for(ch, wing, BattleStats.MAX_STAMINA), 1.6), "禽翅 2%：80 的角色 +1.6，比兽肉碎划算")
	t.eq(Canteen.gain_for(ch, Canteen.single_meal(db.get_def(&"honey_jar")), BattleStats.REGEN_HP), 2.0, "蜂蜜罐：生命 200 的 1% = 每秒 2")
	var meal := Canteen.meal_of([_inst(db, &"mountain_yam", 1), _inst(db, &"fowl_leg", 2)])
	t.eq(Canteen.final_lines(ch, meal), [
		UiText.t("canteen.final") % [UiText.t("canteen.stat_carry"), "20", "23"],
		UiText.t("canteen.final") % [UiText.t("canteen.stat_max_stamina"), "80", "84"],
	] as Array[String], "终值两行：负重 20 → 23、耐力上限 80 → 84")
	Canteen.viewer = ch
	var wing_tip := Glossary.strip_bbcode(ItemTooltip.canteen_line(db.get_def(&"fowl_wing")))
	t.check(wing_tip.contains(UiText.t("canteen.stat_max_stamina")) and wing_tip.contains("+2%") and wing_tip.contains(Names.of(ch) + " +1.6"), "下锅小节（作者 11-27，71）：耐力上限 +2%%，名字后挂「试吃 +1.6」（%s）" % wing_tip)
	t.check(not ItemTooltip.canteen_line(db.get_def(&"wild_scallion")).contains(Names.of(ch)), "固定值食材（野葱）：对谁都一样，不另写角色实得（免得看成能直接吃）")
	t.check(not ItemTooltip.canteen_line(db.get_def(&"meat_scrap")).contains(Names.of(ch)), "固定值食材（兽肉碎）：同上")
	var wheat_tip := Glossary.strip_bbcode(ItemTooltip.canteen_line(db.get_def(&"sour_wheat")))
	t.check(wheat_tip.contains(UiText.t("canteen.satiety_name")) and wheat_tip.contains("+5") and not wheat_tip.contains("·") and not wheat_tip.contains("下锅："), "饱腹单独一行，不再「下锅：」前缀和「·」连写（%s）" % wheat_tip)
	t.eq(ItemTooltip.canteen_line(db.get_def(&"broadsword")), "", "不是食材：没有下锅小节")
	var full := ItemTooltip.describe_full(ItemInstance.create(db.get_def(&"fowl_wing")))
	t.check(String(full.get("pot", "")) != "" and Glossary.strip_bbcode(String(full.get("pot_title", ""))) == UiText.t("canteen.pot_title"), "悬浮窗分块里有「下锅」小节（标题 + 两列）")
	t.check(not Glossary.strip_bbcode(String(full.get("body", ""))).contains(UiText.t("canteen.stat_max_stamina")), "正文里不再重复写下锅那行")
	ch.weight_capacity = 0
	t.check(not ItemTooltip.canteen_line(db.get_def(&"sour_wheat")).contains(Names.of(ch)), "没有负重的角色：主食不写对角色加多少")
	t.eq(Canteen.final_lines(ch, meal).size(), 1, "终值只列耐力上限")
	Canteen.viewer = null


static func run_blessed(t: TestCase) -> void:
	t.begin("作者 11-27（确认清单 73「让赐福的更值钱，然后效果统一 +50%」）：赐福食材下锅照本体算 ×1.5，饱腹不变，器官特性也 ×1.5，售价高于本体；标签行（72）食材 / 草木 / 血肉有图标")
	var db := T110._db()
	for pair in [[&"wild_scallion", "flat"], [&"fowl_wing", "pct"], [&"sour_wheat", "flat"]]:
		var base := db.get_def(pair[0])
		var blessed := db.get_def(Blessings.variant_id(pair[0], &"nature"))
		if blessed == null:
			continue
		var a := Canteen.entry_of(base)
		var b := Canteen.entry_of(blessed)
		t.check(not b.is_empty() and is_equal_approx(float(b[pair[1]]), float(a[pair[1]]) * 1.5), "%s：下锅 %s → %s" % [Names.of(blessed), str(a.get(pair[1])), str(b.get(pair[1]))])
		t.eq(int(b.get("satiety", -1)), int(a.get("satiety", -2)), "%s：饱腹不变" % Names.of(blessed))
		t.eq(ItemValue.of(blessed), roundi(ItemValue.of(base) * 1.5), "%s：售价 = 本体 %d × 1.5（作者 11-27，78）" % [Names.of(blessed), ItemValue.of(base)])
	var scallion := db.get_def(Blessings.variant_id(&"wild_scallion", &"nature"))
	t.check(scallion != null, "野葱有自然之神的赐福版")
	if scallion != null:
		var meal := Canteen.meal_of([ItemInstance.create(scallion)])
		t.check(is_equal_approx(float((meal["flat"] as Dictionary).get(String(BattleStats.REGEN_STAMINA), 0.0)), 0.15), "赐福野葱下锅：耐力回复 0.1 × 1.5 = 0.15")
	var heart := db.get_def(Blessings.variant_id(&"wolf_heart", &"nature"))
	if heart != null:
		t.check(is_equal_approx(float(heart.eat_trait.get("damage", heart.eat_trait.get(&"damage", 0.0))), 12.0), "赐福狼心：造成的伤害 8%% × 1.5 = 12%%（%s）" % str(heart.eat_trait))
	for id in [&"wolf_heart", &"meat_scrap", &"fire_gland", &"fowl_wing"]:
		t.check(TagRegistry.first_per_category(db.get_def(id).tags).has(&"ingredient"), "%s 的标签行画食材（面包），压过素材" % id)
	for pair in [[&"ingredient", "food"], [&"plant", "herb"], [&"blood_flesh", "flesh"]]:
		t.eq(TagRegistry.icon_path(pair[0]), "res://assets/ui/tags/%s.png" % pair[1], "%s 标签画 %s 图标、不写字" % pair)


static func run_sources(t: TestCase) -> void:
	t.begin("355 第三批 · 食材从哪来：魔兽必掉兽肉（替身，强的掉大块、上等）；粮铺常备几样一格的小件；普通搜索权重低；局内商店不卖")
	var db := T110._db()
	var meat := [&"meat_scrap", &"game_meat"]
	for e in [&"flame_wolf", &"frost_toad", &"pit_viper", &"shock_eel"]:
		var d := ContentPaths.load_asset("enemies", String(e)) as EnemyDef
		t.check(d != null and not d.loot_filler.is_empty() and d.loot_filler.all(func(id: StringName) -> bool: return meat.has(id)), "%s 掉小块兽肉、兽肉" % e)
	var bear := ContentPaths.load_asset("enemies", "cave_bear") as EnemyDef
	t.check(bear != null and bear.loot_filler.has(&"beast_haunch") and bear.loot_filler.has(&"prime_beast_leg"), "穴熊（强）掉大块、上等")
	var food := Market.stall(&"food")
	var listed := Market.catalogue(Market.load_rules(), db, food, 1)
	for id in [&"sour_wheat", &"black_bean", &"fowl_wing", &"wild_scallion", &"wild_berry"]:
		t.check(listed.has(id), "粮铺常备 %s" % id)
	t.check(not listed.has(&"fat_fowl") and not listed.has(&"game_meat"), "粮铺不卖别的食材")
	t.eq(SearchSession.weight_mult(db.get_def(&"wild_berry"), {}), Canteen.SEARCH_WEIGHT, "搜索里食材权重 × %s" % Canteen.SEARCH_WEIGHT)
	t.eq(SearchSession.weight_mult(db.get_def(&"iron_ore"), {}), 1.0, "别的照旧")
	var econ := ContentPaths.load_asset("economy_rules", "standard") as EconomyRules
	t.check(econ != null and econ.shop_exclude_tags.has(Canteen.TAG), "局内商店不卖食材")


static func run_audit(t: TestCase) -> void:
	t.begin("355 第三批 · 强力搭配记录：每条属性两条线各挑最强一件，三档锅都摆得进、6×6 不比 4×4 少；整锅叠满不溢出；抽样混搭也不到封顶")
	var db := T110._db()
	var rows := CanteenAudit.lines(db)
	t.eq(rows.size(), 8, "四条属性 × 两条线")
	var best := {}
	for row in rows:
		var key := "%s:%s" % [row["stat"], row["line"]]
		best[key] = float(row["value"][6])
		t.check(int(row["count"][4]) > 0 and float(row["value"][6]) >= float(row["value"][4]), "%s：4×4 摆得进，6×6 不比它少" % key)
		t.check(float(row["value"][6]) < (Canteen.CAP_PCT if row["line"] == CanteenAudit.PCT else Canteen.CAP_FLAT), "%s：不到封顶" % key)
	t.eq(StringName(rows[7]["id"]), &"honey_pomelo", "百分比回血最强：蜜柚")
	var top := CanteenAudit.samples(db, 6, 60, 7)
	for key in top:
		t.check(float(top[key]["value"]) < Canteen.CAP_FLAT, "混搭 %s 不到封顶" % key)
	t.check(CanteenAudit.report(db, [], 20).contains("表三"), "记录三张表")


static func run_nursery(t: TestCase) -> void:
	t.begin("355 第三批 / 389 · 苗圃：垦户社 50 声望开第二片、100 开第三片；每片 4×4 棋盘按形状摆；各作物成熟局数不同；主食蔬菜水果灰灯食堂开了才种、种苗白给；收成进食材仓库、偶尔多收优良的；三片存读一样")
	var pb := CommissionBook.new()
	var plots := func(r: int) -> int:
		pb.rep["growers"] = r
		return Nursery.plots_for(pb)
	t.eq([plots.call(0), plots.call(10), plots.call(49), plots.call(50), plots.call(99), plots.call(100)], [1, 1, 1, 2, 2, 3], "10 一片、50 两片、100 三片")
	var c := TestSupport.load_content("free_mode")
	var f := Support.flow(c, PREFIX)
	Support.pass_tutorials(f)
	G342._open(f)
	t.eq(f.meta.nursery.fields.size(), 1, "刚开：一片")
	t.eq(f.meta.nursery.field(0).size, Nursery.FIELD, "一片是 4×4")
	t.eq(f.sow_crop(0, &"sour_wheat"), Nursery.WHY_CANTEEN, "食堂没开：主食种不了")
	f.meta.commissions.rep["growers"] = 50
	f.sync_commissions()
	t.eq(f.meta.nursery.fields.size(), 2, "信赖：两片")
	_open(f)
	for k in 4:
		t.eq(f.sow_crop(1, &"sour_wheat"), "", "食堂开了：第二片种酸麦（种苗白给）#%d" % k)
	t.eq(f.sow_crop(0, &"honey_pomelo", Vector2i(0, 0)), "", "第一片左上角种蜜柚（2×2）")
	t.eq(f.sow_crop(0, &"honey_pomelo", Vector2i(1, 1)), Nursery.WHY_ROOM, "压着别的那株：摆不下")
	t.eq(f.sow_crop(0, &"honey_pomelo", Vector2i(2, 2)), "", "右下角再种一株")
	t.check(int(Nursery.CROPS[&"sour_wheat"]["runs"]) != int(Nursery.CROPS[&"honey_pomelo"]["runs"]), "酸麦和蜜柚熟得不一样快")
	for k in int(Nursery.CROPS[&"sour_wheat"]["runs"]):
		Nursery.advance(f.meta, "r%d" % k)
	t.check(f.meta.nursery.is_ripe(1) and not f.meta.nursery.is_ripe(0), "酸麦熟了，蜜柚还没")
	var got := f.harvest_crop(1)
	t.eq(String(got["why"]), "", "收酸麦")
	t.check(int(got["items"]) >= 4, "四株至少四件（偶尔多收金穗麦）")
	var wheat := f.meta.canteen.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"sour_wheat").size()
	t.eq(wheat, 4, "四件酸麦进食材仓库")
	t.check(f.meta.nursery.is_empty(1), "第二片空了")
	var bonus := 0
	var m := T110._meta()
	m.commissions.grants[String(Canteen.ID)] = true
	for k in 40:
		m.nursery = Nursery.new()
		m.nursery.seq = k
		for j in 4:
			Nursery.sow(m, 0, &"sour_wheat", c.items)
		for g in m.nursery.growth.values():
			g["left"] = 0
		m.canteen.store.clear()
		var r := Nursery.harvest(m, 0, c.items)
		bonus += int(r["items"]) - 4
	t.check(bonus > 0 and bonus < 40 * 4, "四十回里偶尔多收（%d 件金穗麦）" % bonus)
	f.meta.commissions.rep["growers"] = 100
	f.sync_commissions()
	t.eq(f.meta.nursery.fields.size(), 3, "100：三片")
	var back := Nursery.from_dict(f.meta.nursery.to_dict(), c.items)
	t.eq(back.fields.size(), 3, "三片存读回来还是三片")
	t.eq(back.to_dict(), f.meta.nursery.to_dict(), "存读一样")
	var ps := back.plants(0)
	t.check(ps.size() == 2 and back.crop_of(ps[0].uid) == &"honey_pomelo", "第一片的两株蜜柚还在")
	var old := Nursery.from_dict({"plots": [{"crop": "sour_wheat", "sown_run": 0, "left": 1}]})
	t.eq([old.fields.size(), old.legacy_count()], [1, 1], "老档一畦 → 一片，等着摆一株")
	Support.cleanup(PREFIX)


static func run_alchemy_pantry(t: TestCase) -> void:
	t.begin("355 第三批 · 食材仓库里的东西能直接炼金（报告 354：什么都能炼）")
	var db := T110._db()
	var m := T110._meta()
	m.commissions.grants[String(Canteen.ID)] = true
	var berry := _inst(db, &"wild_berry", m.allocate_uid())
	m.canteen.store.try_add(berry)
	t.eq(Alchemy.held(m, berry.uid), berry, "认得食材仓库里的")
	var got := Alchemy.dissolve(m, [berry.uid], null, db)
	t.eq(int(got["count"]), 1, "炼了一件")
	t.check(not m.canteen.store.has_item(berry.uid), "食材仓库里没了")


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
	t.check(is_equal_approx(run.compile_player().meal_regen_hp, 0.9), "每秒回血 0.9")
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
	# 第二批：收藏夹
	t.eq(p._pot_name.text, UiText.t("canteen.unnamed"), "没收藏：「没收藏的一锅」")
	t.check(not p._save_btn.disabled, "锅里有东西：能收藏")
	t.eq(p.save_menu(), 0, "【收藏】")
	t.eq(p._menu_box.get_child_count(), 1, "一块菜单牌")
	var slate_tex := UiTheme.art_cached(UiTheme.ART_STONE_SLATE)
	t.check((p.find_child("MealNote", true, false) as Control).get_theme_stylebox("panel").texture == slate_tex and (p.find_child("Recipes", true, false) as Control).get_theme_stylebox("panel").texture == slate_tex, "作者 11-23 选 B：「这一锅」「配方」两块深石板")
	var apply_btn := p._menu_box.get_child(0).find_child("Load", true, false) as Button
	t.check(apply_btn != null and apply_btn.text == UiText.t("canteen.apply") and apply_btn.theme_type_variation == UiTheme.BUTTON_STONE_PRIMARY, "每份配方一颗深石板【应用】")
	t.eq(p._eat_btn.theme_type_variation, UiTheme.BUTTON_STONE_PRIMARY, "【开饭】深石板主键")
	t.eq(p._pot_name.text, UiText.t("canteen.menu_default") % 1, "锅叫「菜单 1」")
	p.start_rename(0)
	t.check(p._menu_box.get_child(0).get_node_or_null("NameEdit") != null, "改名：换成输入框")
	t.check(p.rename_menu(0, "山薯饭"), "改成「山薯饭」")
	t.eq(f.meta.canteen.menu_name(), "山薯饭", "名字改了")
	f.meta.canteen.pot.clear()     # 吃掉了
	p.refresh()
	t.eq(p._pot_name.text, "山薯饭  " + UiText.t("canteen.gaps") % 1, "锅空了：缺 1 样")
	t.eq(p.load_menu(0).size(), 1, "仓库里没有山薯：重做还缺")
	f.meta.canteen.store.try_add(_inst(f.items, &"mountain_yam", f.meta.allocate_uid()))
	t.eq(p.load_menu(0).size(), 0, "进了山薯：重做齐了")
	t.eq(f.meta.canteen.pot.item_count(), 1, "山薯下锅")
	t.eq(Bare.audit(p, "canteen355_menu"), [] as Array[String], "收藏夹的字不裸")
	t.check(p.delete_menu(0) and p._menu_box.get_child_count() == 0, "删除")
	s.queue_free()
	W178._cleanup()


## 355 第三批：苗圃页 —— 两片以上顶上一排片键；食堂开了空地纸条多一排栏键（药材 / 主食 / 蔬菜 / 水果），食材一栏一排三张小纸条；字不裸
static func frame_nursery(t: TestCase, root: Window) -> void:
	t.begin("355 第三批 · 苗圃页：两片有片键；食堂开了能翻到主食、蔬菜、水果；小纸条点【种下】种上，【选中】再点格子种在那格；字不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	Support.pass_tutorials(f)
	G342._open(f)
	var s: Control = W178._screen(f, root)
	s.show_tab("nursery")
	var p = s.nursery_panel()
	t.check(p.find_child("PlotTabs", true, false) == null and p.find_child("GroupTabs", true, false) == null, "一片、食堂没开：和原来一样")
	t.check(p.find_child("Slip_bitter_leaf", true, false) != null, "药材纸条在")
	s.queue_free()
	f.meta.commissions.rep["growers"] = 50
	_open(f)
	s = W178._screen(f, root)
	s.show_tab("nursery")
	p = s.nursery_panel()
	t.check(p.find_child("PlotTabs", true, false) != null, "两片：有片键")
	t.check(p.find_child("GroupTabs", true, false) != null, "食堂开了：有栏键")
	p.show_group(&"fruit")
	t.check(p.find_child("Slip_honey_pomelo", true, false) != null and p.find_child("Slip_bitter_leaf", true, false) == null, "水果一栏：蜜柚的小纸条")
	t.eq(Bare.audit(p, "nursery355"), [] as Array[String], "字不裸")
	p.show_plot(1)
	t.eq(p.sow(1, &"honey_pomelo"), "", "第二片种蜜柚")
	var ps: Array[ItemInstance] = f.meta.nursery.plants(1)
	t.check(ps.size() == 1 and f.meta.nursery.crop_of(ps[0].uid) == &"honey_pomelo", "种上了")
	t.check(p.find_child("FieldView", true, false) != null, "地是一块棋盘")
	t.check(p.find_child("Pick_honey_pomelo", true, false) == null, "作者 11-27：没有【选中】键，点【种下】就种")
	t.eq(p.sow(1, &"honey_pomelo"), "", "再点【种下】：摆进下一个空处")
	t.eq(f.meta.nursery.plants(1).size(), 2, "两株了")
	t.eq(Bare.audit(p, "nursery355b"), [] as Array[String], "棋盘页字不裸")
	s.queue_free()
	W178._cleanup()


## 383：开局第一屏的食物横条（原第四页「本次准备」）：写这一锅的名字、效果、饱腹，能换一份收藏；出发吃的是换上的那一锅
static func frame_prep(t: TestCase, root: Window) -> void:
	t.begin("355 第二批 / 383 · 开局第一屏的食物横条：食堂开了才有；折叠时写这一锅的效果，展开写名字、效果、饱腹；换一份收藏 = 从食材仓库重做；出发吃的是这一锅")
	Support.cleanup("char")
	var game = load(CS.GAME).instantiate()
	game.save_path = CS.SAVE
	game.meta_path = CS.META
	root.add_child(game)
	var flow: GameFlow = game.flow
	Support.pass_tutorials(flow)
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	_open(flow)
	var cn := flow.meta.canteen
	for id in [&"mountain_yam", &"fowl_leg", &"sour_wheat"]:
		cn.store.try_add(_inst(flow.items, id, flow.meta.allocate_uid()))
	var yam := cn.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"mountain_yam")[0] as ItemInstance
	cn.store.remove(yam.uid)
	cn.pot.place(yam, Vector2i(0, 0), 0)
	cn.save_menu("山薯")
	cn.load_menu(0)
	var wheat := cn.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"sour_wheat")[0] as ItemInstance
	cn.store.remove(wheat.uid)
	cn.pot.place(wheat, Vector2i(3, 3), 0)
	cn.active = -1
	cn.save_menu("酸麦")
	cn.empty_pot()     # 383（作者 2026-11-23）：上一局吃的是「酸麦」配方、食材够 → 进开局屏自动复用
	cn.last = {"kind": Canteen.LAST_MENU, "name": "酸麦", "cells": (cn.menus[1]["cells"] as Array).duplicate(true)}
	flow.new_run()
	var setup = game.base()
	t.eq(setup.last_page(), 2, "383：还是三页")
	t.check(setup.bar(setup.BAR_MEAL).visible and not setup.bar(setup.BAR_MEAL).open, "食物横条在、默认折叠")
	t.check(setup.meal_head_text() != "" and setup.meal_head_text() != UiText.t("canteen.empty_chip"), "折叠时写这一锅的效果：%s" % setup.meal_head_text())
	t.check(setup.open_bar(setup.BAR_MEAL) and setup._meal_box.is_visible_in_tree(), "点开")
	t.eq((setup._meal_box.find_child("PotName", true, false) as Label).text, UiText.t("canteen.this_pot") % "酸麦", "名字：酸麦")
	t.eq(setup.meal_buttons().size(), 2, "两份配方可换")
	t.eq(Bare.audit(setup._meal_box, "canteen355_prep"), [] as Array[String], "字不裸")
	t.eq(setup.choose_menu(0), 0, "换成「山薯」")
	t.eq((setup._meal_box.find_child("PotName", true, false) as Label).text, UiText.t("canteen.this_pot") % "山薯", "名字跟着换")
	t.check(cn.pot.item_count() == 0 and cn.store.has_item(yam.uid), "383：出发前不动锅和仓库")
	setup.show_page(2)
	setup._sync_preview()
	var entries: Array = setup.preview().entry_ids()
	if not entries.is_empty():
		setup.pick_spawn(int(entries[0]))
	t.check(Support.depart(setup), "出发")
	var mod := MealModule.of(flow.run) if flow.run != null else null
	t.check(mod != null and mod.satiety == 11, "吃的是山薯这一锅：饱腹 11")
	t.check(not cn.store.has_item(yam.uid) and cn.store.has_item(wheat.uid) and cn.pot.item_count() == 0, "383：出发那一刻才吃掉山薯，酸麦留在仓库")
	t.eq(String(cn.last.get("name", "")), "山薯", "383：记下这一局是「山薯」配方")
	game.queue_free()
	Support.cleanup("char")
