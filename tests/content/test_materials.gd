## 122（作者定）：非战斗材料首批 —— 用处就是价值本身和科技材料；按是否人造分【工艺】/【自然】；技巧之神祭品加【工艺】
extends RefCounted

const NATURE := [&"copper_ore", &"iron_ore", &"silver_ore", &"flint", &"raw_salt", &"oak_log", &"ironwood_branch",
	&"beast_hide", &"fine_fur", &"antler", &"dried_herbs", &"beeswax"]
const CRAFTED := [&"clay_pot", &"glazed_vase", &"linen_bolt", &"wool_cloth", &"silk_bolt", &"rope_coil", &"copper_ingot",
	&"silver_ingot", &"nail_keg", &"tanned_leather", &"brass_gear", &"oil_lamp", &"gilded_goblet", &"tapestry"]


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run(t: TestCase) -> void:
	t.begin("122 · 首批材料都在库里、能搜出来：没有战斗、不填价值（价值 = 稀有度 × 格数的公式）、出身标签对")
	var db := _db()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var search: SearchRules = (load(ContentPaths.asset_file("node_rules", String(chapter.node_rules))) as NodeRules).search
	var pool := SearchSession.candidates(search, db)
	for pair in [[NATURE, &"nature"], [CRAFTED, &"crafted"]]:
		for id in pair[0]:
			var def := db.get_def(id)
			t.not_null(def, "%s 在库里" % id)
			if def == null:
				continue
			t.check(def.tags.has(&"material") and def.tags.has(pair[1]), "%s：材料、%s" % [id, pair[1]])
			t.check(def.combat == null, "%s：不参战" % id)
			t.eq(def.value, 0, "%s：价值不手填" % id)
			t.eq(ItemValue.of(def), ItemValue.BASE_PER_CELL[def.rarity] * def.shape.cell_count(), "%s：价值走公式" % id)
			t.check(pool.has(id), "%s：搜索池里有" % id)
			t.check(Names.of(def, "en") != String(id), "%s：有英文名" % id)
	t.eq(db.get_def(&"tapestry").rarity, 3, "挂毯稀有度 3")
	t.eq(ItemValue.of(db.get_def(&"tapestry")), 450, "挂毯 6 格 × 75 = 450")
	t.check(db.get_def(&"antler").tags.has(&"beast_part"), "鹿角是兽材（250：战利品并进兽材，狩猎之神 ×10）")
	t.eq(db.get_def(&"iron_ore").material, "metal", "矿石的材质是金属（250：材质是字段）")

	t.begin("122 · 每件材料都恰好带【工艺】/【自然】/【魔法】之一；硬木板算工艺，魔晶石算魔法（作者补正）")
	var materials := 0
	for id in db.ids(true):
		var def := db.get_def(id)
		if def == null or not def.tags.has(&"material"):
			continue
		materials += 1
		var kinds := 0
		for k in ContentImporter.MATERIAL_ORIGINS:
			kinds += 1 if def.tags.has(k) else 0
		t.eq(kinds, 1, "%s：工艺 / 自然 / 魔法三选一" % id)
	t.check(materials >= 37, "材料 %d 件（原有 9 + 新 28）" % materials)
	t.check(db.get_def(&"hardwood_plank").tags.has(&"crafted"), "硬木板：工艺（锯出来的）")
	for id in [&"fire_crystal", &"ice_crystal", &"lightning_crystal", &"quartz_cluster", &"raw_amber"]:     # 148：魔晶石换成三种元素晶石；244 补充一：两块宝石并进来
		var def := db.get_def(id)
		t.check(def.tags.has(&"magic") and not def.tags.has(&"nature") and not def.tags.has(&"crafted"), "%s：魔法，不算自然也不算工艺" % id)
	t.not_null(load(ContentPaths.asset_file("tags", "crafted")), "【工艺】标签登记了")
	t.not_null(load(ContentPaths.asset_file("tags", "magic")), "【魔法】标签登记了")

	t.begin("122 / 250 · 导入器：素材缺本源或带两个 → 报错（250 起拦）")
	var ctx := ContentImporter.Context.new()
	for tag in [&"material", &"crafted", &"nature", &"magic"]:
		ctx.tags[tag] = true
	for pair in [[["material"], true], [["material", "crafted", "nature"], true], [["material", "crafted"], false], [["material", "magic"], false], [["material", "nature", "magic"], true]]:
		var report := ImportReport.new()
		ContentImporter.import_item({"id": "probe", "display_name": "探针", "shape": ["1"], "tags": pair[0], "material": "metal"}, ctx, report)
		t.eq(report.ok(), not pair[1], "%s：%s" % [pair[0], "拦" if pair[1] else "不拦"])
		t.eq(report.to_text().contains("恰好带一个"), pair[1], "%s：%s" % [pair[0], "报本源" if pair[1] else "不报"])

	t.begin("122 / 250 · 技巧之神收【工艺】：铜锭、陶罐只有工艺那条 = 5 × 2^稀有度；铜矿石是自然的、不收（250：金属那条换成防具 / 盾）")
	var skill: FaithDef = load(ContentPaths.asset_file("faiths", "skill"))
	var ingot := db.get_def(&"copper_ingot")
	t.eq(skill.offering_value(ingot), int(5 * pow(2, ingot.rarity)), "铜锭：%d" % skill.offering_value(ingot))
	var pot := db.get_def(&"clay_pot")
	t.eq(skill.offering_value(pot), int(5 * pow(2, pot.rarity)), "陶罐：%d" % skill.offering_value(pot))
	t.eq(skill.offering_value(db.get_def(&"copper_ore")), 0, "铜矿石：不收")

	t.begin("122 · 科技材料接上：行囊 3 级要熟皮革与亚麻布，保险箱 2 级要铁钉桶；带 supply 的商店不卖")
	var techs := GameFlow.load_techs()
	t.eq(TechService.find(techs, &"pack").tiers[2].items, {"tanned_leather": 2, "linen_bolt": 1}, "行囊 3 级")
	t.eq(TechService.find(techs, &"safe_box").tiers[1].items, {"nail_keg": 1, "steel_ingot": 1}, "保险箱扩格 2 级")
	t.eq(TechService.find(techs, &"sinew").tiers[2].items, {"copper_ingot": 2}, "筋骨 3 级")
	t.eq(TechService.find(techs, &"bargain").tiers[1].items, {"silver_ingot": 1}, "讨价 2 级")
	t.eq(int(TechService.find(techs, &"warehouse").tiers[4].items.get("nail_keg", 0)), 1, "仓库扩建 5 级加铁钉桶")
	var eco := load(ContentPaths.asset_file("economy_rules", "standard")) as EconomyRules
	var shop := ShopSession.candidates(eco, db)
	for id in [&"linen_bolt", &"copper_ingot", &"silver_ingot", &"nail_keg", &"tanned_leather"]:
		t.check(db.get_def(id).tags.has(&"supply") and not shop.has(id), "%s：建材、商店不卖" % id)

	t.begin("122 · 说明文字不写数字（TextLint）")
	for id in NATURE + CRAFTED:
		var text := FileAccess.get_file_as_string(ContentPaths.authoring_file("items", String(id)))
		var json := JSON.new()
		t.eq(json.parse(text), OK, "%s 能解析" % id)
		t.eq(TextLint.scan(json.data).size(), 0, "%s：说明里没有裸数字" % id)
