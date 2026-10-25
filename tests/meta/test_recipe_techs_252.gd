## 252（作者 2026-10-25 14:43 定乙：配方写在配方上）：配方多一道「会不会」的门 —— [member SmithRecipeDef.tech] / [member SmithRecipeDef.tech_level]，
## 科技「秘银冶炼」「法杖工艺」（构件 [TechRecipes]）开配方；新素材秘银锭、木棍，法杖梯子（法师杖 / 魔导杖 / 大魔导杖），冶炼大类；
## 铁匠铺分三桶（会打 / 铺子级不够 / 科技没点），科技没点的照样列着、灰掉、写要哪项科技
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")


static func _meta(smithy: int, techs: Dictionary = {}) -> MetaState:
	var m := T110._meta()
	if smithy > 0:
		m.facility_levels[Smithy.ID] = smithy
	for id in techs:
		m.tech_levels[String(id)] = int(techs[id])
	return m


static func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for r in list:
		out.append(String((r as SmithRecipeDef).id))
	out.sort()
	return out


static func run_content(t: TestCase) -> void:
	t.begin("252 §3.1～3.3：两项科技都在深度 4（前置铁匠铺；秘银冶炼列 0、法杖工艺列 1，树宽守门），构件 tech_recipes；新道具五件；配方写着要哪项科技几级")
	var defs: Array = []
	for f in DirAccess.get_files_at(ContentPaths.TECHS):
		var d := load(ContentPaths.TECHS + "/" + f.trim_suffix(".remap")) as TechDef
		if d != null:
			defs.append(d)
	var lay := TechService.layout(defs)
	for id in [&"mithril_smelting", &"staffcraft"]:
		var def := TechService.find(defs, id)
		t.not_null(def, "%s 在" % id)
		if def == null:
			continue
		t.eq(def.requires, [&"smithy"] as Array[StringName], "%s 前置铁匠铺" % id)
		t.check(def.effect is TechRecipes and (def.effect as TechRecipes).tech == id, "%s 的构件是 tech_recipes、写着自己" % id)
	t.eq(lay.get(&"mithril_smelting", Vector2i(-1, -1)), Vector2i(0, 4), "秘银冶炼：列 0 深度 4")
	t.eq(lay.get(&"staffcraft", Vector2i(-1, -1)), Vector2i(1, 4), "法杖工艺：列 1 深度 4")
	t.eq(TechService.find(defs, &"mithril_smelting").max_level(), 1, "秘银冶炼一级")
	t.eq(TechService.find(defs, &"staffcraft").max_level(), 3, "法杖工艺三级")
	var db := T110._db()
	var mi := db.get_def(&"mithril_ingot")
	t.check(mi != null and mi.tags.has(&"material") and mi.rarity == 3, "秘银锭：素材、紫")
	var stick := db.get_def(&"wooden_stick")
	t.check(stick != null and stick.tags.has(&"material") and stick.rarity == 0, "木棍：素材、白")
	var ladder := [[&"magic_staff", 1, 2], [&"mage_staff", 2, 2], [&"magus_staff", 3, 3], [&"grand_magus_staff", 4, 3]]
	for row in ladder:
		var s := db.get_def(row[0])
		t.check(s != null and s.rarity == row[1] and s.tags.has(&"staff") and s.adjacency != null and s.adjacency.load_cells.size() == row[2],
			"%s：稀有度 %d、%d 个装载格" % row)
	var all := SmithRecipeDef.load_all()
	var want := {
		&"smith_silver_ingot": [&"", 1], &"smith_mithril_ingot": [&"mithril_smelting", 1], &"smith_mithril_sword": [&"mithril_smelting", 1],
		&"smith_magic_staff": [&"staffcraft", 1], &"smith_mage_staff": [&"staffcraft", 2],
		&"smith_magus_staff": [&"staffcraft", 3], &"smith_grand_magus_staff": [&"staffcraft", 3],
	}
	for id in want:
		var r := SmithRecipeDef.find(all, id)
		t.check(r != null and r.tech == want[id][0] and r.tech_level == want[id][1], "%s 要 %s %d 级" % [id, want[id][0], want[id][1]])
	var sword := SmithRecipeDef.find(all, &"smith_mithril_sword")
	t.check(sword != null and int(sword.inputs.get("mithril_ingot", 0)) == 2 and int(sword.inputs.get("longsword", 0)) == 1, "秘银剑换成真配方（长剑 + 秘银锭 ×2）")


static func run_buckets(t: TestCase) -> void:
	t.begin("252 §3.4：铁匠铺三级、科技都没点 —— 秘银锭、法杖在「科技没点」；秘银冶炼一级 → 秘银两张会打；法杖工艺一级只开魔法杖，三级再开两根")
	var all := SmithRecipeDef.load_all()
	var m := _meta(3)
	var b := Smithy.recipes_for(m, all)
	var tl := _ids(b["tech_locked"])
	t.check(tl.has("smith_mithril_ingot") and tl.has("smith_magic_staff") and not tl.has("smith_silver_ingot"), "科技没点：秘银锭、魔法杖锁着，炼银锭不要科技（%s）" % str(tl))
	t.eq((b["level_locked"] as Array).size(), 0, "铺子三级：没有级数锁")
	m.tech_levels["mithril_smelting"] = 1
	b = Smithy.recipes_for(m, all)
	t.check(_ids(b["ready"]).has("smith_mithril_ingot") and _ids(b["ready"]).has("smith_mithril_sword"), "秘银冶炼一级：秘银锭、秘银剑会打")
	m.tech_levels["staffcraft"] = 1
	var staffs := func() -> Array[String]:
		return _ids((Smithy.recipes_for(m, all)["ready"] as Array).filter(func(r) -> bool: return (r as SmithRecipeDef).group == "staff"))
	t.eq(staffs.call(), ["smith_magic_staff"] as Array[String], "法杖工艺一级：只开魔法杖")
	m.tech_levels["staffcraft"] = 3
	t.eq(staffs.call(), ["smith_grand_magus_staff", "smith_mage_staff", "smith_magic_staff", "smith_magus_staff"] as Array[String], "三级：四根都开")
	var low := _meta(1, {"mithril_smelting": 1})
	b = Smithy.recipes_for(low, all)
	t.check(_ids(b["level_locked"]).has("smith_mithril_ingot") and not _ids(b["tech_locked"]).has("smith_mithril_ingot"), "科技点了、铺子一级：秘银锭在「级数不够」")
	var none := _meta(3)
	var r := SmithRecipeDef.find(all, &"smith_magus_staff")
	t.eq(Smithy.can_forge(none, r, T110._db()), UiText.t("smithy.need_tech_level") % ["法杖工艺", 3], "科技没点：先说要点出哪项几级")
	var r1 := SmithRecipeDef.find(all, &"smith_mithril_ingot")
	t.eq(Smithy.can_forge(none, r1, T110._db()), UiText.t("smithy.need_tech") % "秘银冶炼", "一级的不写级数")


static func run_describe(t: TestCase) -> void:
	t.begin("252 §3.1：科技卡「现在 / 下一级」—— 秘银冶炼一级「会打：秘银锭、秘银附魔长剑」；法杖工艺各级只列那一级新开的")
	var e := (load(ContentPaths.asset_file("techs", "mithril_smelting")) as TechDef).effect as TechRecipes
	var line := e.describe_level(1)
	t.check(line.contains("秘银锭") and line.contains("秘银附魔长剑"), "一级：%s" % line)
	var s := (load(ContentPaths.asset_file("techs", "staffcraft")) as TechDef).effect as TechRecipes
	t.check(s.describe_level(1).contains("魔法杖") and not s.describe_level(1).contains("魔导杖"), "法杖工艺一级：%s" % s.describe_level(1))
	t.check(s.describe_level(3).contains("魔导杖") and s.describe_level(3).contains("大魔导杖"), "法杖工艺三级：%s" % s.describe_level(3))
	t.eq(TechRecipes.new().describe_level(1), "", "没挂科技的构件：空")


static func run_forge_eats_crystal(t: TestCase) -> void:
	t.begin("252 §3.3：打法师杖 —— 木棍、下品火晶石、银锭各吃一件，扣 90 币，法师杖进仓库")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := _meta(2, {"staffcraft": 2})
	m.funds = 100
	for id in [&"wooden_stick", &"fire_crystal_low", &"silver_ingot"]:
		T110._add(m, db, id)
	var r := SmithRecipeDef.find(SmithRecipeDef.load_all(), &"smith_mage_staff")
	t.eq(Smithy.can_forge(m, r, db), "", "齐了")
	var got := Smithy.forge(m, r, db)
	t.check(got != null and got.def.id == &"mage_staff" and m.warehouse.has_item(got.uid), "法师杖进了仓库")
	t.eq(m.funds, 10, "扣了 90 币")
	t.eq(m.warehouse.items().filter(func(i) -> bool: return (i as ItemInstance).def.id in [&"wooden_stick", &"fire_crystal_low", &"silver_ingot"]).size(), 0, "三样料都吃掉了（晶石也算料）")


static func run_import_checks(t: TestCase) -> void:
	t.begin("252 §3.7：导入器 —— 配方写了不存在的科技、科技级数超上限、冶炼的产物不是素材都报错；构件 tech 不是自己的报错")
	var db := T110._db()
	var ctx := ContentImporter.Context.new()
	for id in db.ids():
		ctx.items[id] = db.get_def(id)
	ContentImporter.import_tech({"id": "smelt_t", "display_name": "炼", "effect": {"type": "tech_recipes", "tech": "smelt_t"}, "tiers": [{"funds": 1}, {"funds": 2}]}, ctx, ImportReport.new())
	var ok := ImportReport.new()
	ContentImporter.import_smith_recipe({"id": "a", "output": "silver_ingot", "inputs": {"silver_ore": 2}, "funds": 1, "group": "smelt", "tech": "smelt_t", "tech_level": 2}, ctx, ok)
	ContentImporter.validate_smith_recipe_techs(ctx, ok)
	t.check(ok.ok(), "好的不报错：%s" % ok.to_text())
	var bad_out := ImportReport.new()
	ContentImporter.import_smith_recipe({"id": "b", "output": "shortsword", "inputs": {"iron_ore": 2}, "funds": 1, "group": "smelt"}, ctx, bad_out)
	t.check(not bad_out.ok(), "冶炼的产物不是素材：报错")
	var c2 := ContentImporter.Context.new()
	c2.items = ctx.items
	c2.techs = ctx.techs
	ContentImporter.import_smith_recipe({"id": "c", "output": "silver_ingot", "inputs": {"silver_ore": 2}, "funds": 1, "group": "smelt", "tech": "nope_252"}, c2, ImportReport.new())
	ContentImporter.import_smith_recipe({"id": "d", "output": "silver_ingot", "inputs": {"silver_ore": 2}, "funds": 1, "group": "smelt", "tech": "smelt_t", "tech_level": 3}, c2, ImportReport.new())
	var rep := ImportReport.new()
	ContentImporter.validate_smith_recipe_techs(c2, rep)
	t.check(not rep.ok() and rep.to_text().contains("nope_252"), "科技不存在：点名")
	t.check(rep.to_text().contains("只有 2 级"), "级数超上限：报错")
	var c3 := ContentImporter.Context.new()
	ContentImporter.import_tech({"id": "x", "display_name": "x", "effect": {"type": "tech_recipes", "tech": "y"}, "tiers": [{"funds": 1}]}, c3, ImportReport.new())
	var r3 := ImportReport.new()
	ContentImporter.validate_smith_recipe_techs(c3, r3)
	t.check(not r3.ok(), "构件写的不是自己的 id：报错")


static func run_market_and_mages(t: TestCase) -> void:
	t.begin("252 §3.6 / 待定 2：集市不卖秘银锭、一级起有木棍；三阶法师各拿对应的杖")
	var db := T110._db()
	var rules := Market.load_rules()
	var c3 := Market.candidates(rules, db, 3)
	t.check(not (c3["material"] as Array).has(&"mithril_ingot"), "三级集市也没有秘银锭")
	t.check((Market.candidates(rules, db, 1)["material"] as Array).has(&"wooden_stick"), "一级集市有木棍")
	for row in [["apprentice_mage", &"magic_staff"], ["adept_mage", &"mage_staff"], ["magus", &"magus_staff"], ["grand_magus", &"grand_magus_staff"]]:
		var e := load(ContentPaths.asset_file("enemies", row[0])) as EnemyDef
		t.check(e != null and e.signature.has(row[1]), "%s 拿 %s" % row)
