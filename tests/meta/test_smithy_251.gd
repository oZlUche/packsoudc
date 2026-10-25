## 251（作者 2026-10-24）：基地铁匠铺 —— 科技「铁匠铺」三级（会打绿 / 蓝 / 紫的配方）；配方是数据（素材各几件 + 钱 → 一件武器 / 防具）；
## 只吃仓库里没锁的，产物进仓库、图鉴点亮；级不够 / 缺素材 / 钱不够 / 仓库满都不打、什么也不动；导入器拦产物不是装备、id 不存在的配方
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")


static func _meta(lv: int) -> MetaState:
	var m := T110._meta()
	if lv > 0:
		m.facility_levels[Smithy.ID] = lv
	return m


static func _recipe(out: StringName, inputs: Dictionary, funds: int, lv: int = 1) -> SmithRecipeDef:
	var r := SmithRecipeDef.new()
	r.id = StringName("t_" + String(out))
	r.output = out
	r.inputs = inputs
	r.funds = funds
	r.level = lv
	return r


static func run_content(t: TestCase) -> void:
	t.begin("251 §三：内容 —— 科技「铁匠铺」三级、前置行囊（← 保险箱 ← 仓库，树不加宽）；首批 14 张配方，产物都是装备、素材都在、级 1 ～ 3")
	var def := load(ContentPaths.asset_file("techs", "smithy")) as TechDef
	t.not_null(def, "科技资产在")
	if def == null:
		return
	t.eq(def.max_level(), 3, "三级")
	t.eq(def.requires, [&"pack"] as Array[StringName], "前置行囊（一路往下是仓库）")
	t.check(def.effect is TechFacility and (def.effect as TechFacility).facility == Smithy.ID, "tech_facility(smithy)")
	var db := T110._db()
	var all := SmithRecipeDef.load_all()
	t.eq(all.size(), 20, "14 张 + 252 的 6 张")
	var ok := true
	for r in all:
		var o := db.get_def(r.output)
		var kinds := [&"material"] if r.group == SmithRecipeDef.SMELT else [&"weapon", &"armor", &"shield", &"gear_plug"]
		ok = ok and o != null and kinds.any(func(tag): return o.tags.has(tag))
		ok = ok and r.level >= 1 and r.level <= 3 and r.funds > 0 and not r.inputs.is_empty()
		for k in r.inputs:
			ok = ok and db.get_def(StringName(String(k))) != null and int(r.inputs[k]) >= 1
	t.check(ok, "产物都是装备（冶炼的是素材）、素材都在、级 1 ～ 3")


static func run_forge(t: TestCase) -> void:
	t.begin("251 §三：打造 —— 级不够不打；缺一件不打；齐了：素材按数扣、钱扣、仓库多一件产物、图鉴点亮；锁住的素材不算有")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var r := _recipe(&"shortsword", {"iron_ore": 2, "hardwood_plank": 1}, 40)
	var m := _meta(0)
	m.funds = 100
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.need_level") % 1, "没有铁匠铺：级不够")
	m.facility_levels[Smithy.ID] = 1
	var ore1 := T110._add(m, db, &"iron_ore")
	T110._add(m, db, &"hardwood_plank")
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.missing"), "铁矿石只有一件：缺素材")
	t.is_null(Smithy.forge(m, r, db), "缺素材：不打")
	var ore2 := T110._add(m, db, &"iron_ore")
	ore2.set_locked(true)
	t.eq(int(Smithy.have(m, r)["iron_ore"]), 1, "锁住的不算有")
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.missing"), "锁住的那件不吃")
	ore2.set_locked(false)
	m.funds = 39
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.no_funds"), "钱不够")
	m.funds = 100
	t.eq(Smithy.can_forge(m, r, db), "", "齐了")
	var got := Smithy.forge(m, r, db)
	t.not_null(got, "打出来了")
	t.eq(m.funds, 60, "扣了 40 币")
	t.check(not m.warehouse.has_item(ore1.uid) and not m.warehouse.has_item(ore2.uid), "两件铁矿石扣了")
	t.eq(m.warehouse.items().filter(func(i): return (i as ItemInstance).def.id == &"hardwood_plank").size(), 0, "硬木板扣了")
	t.check(got != null and m.warehouse.has_item(got.uid) and got.def.id == &"shortsword", "仓库里多了一把短剑")
	t.check(m.codex_lit(&"shortsword"), "图鉴点亮")
	var hi := _recipe(&"longbow", {"oak_log": 1}, 1, 2)
	T110._add(m, db, &"oak_log")
	t.eq(Smithy.can_forge(m, hi, db), UiText.t("smithy.need_level") % 2, "1 级打不了 2 级的配方")
	var split := Smithy.recipes_for(m, [r, hi])
	t.check((split["ready"] as Array).has(r) and (split["level_locked"] as Array).has(hi), "分成会打的 / 还不会的")


static func run_full(t: TestCase) -> void:
	t.begin("251 §三：仓库满（产物放不下）不打、不扣素材、不扣钱")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var r := _recipe(&"warhammer", {"oak_log": 1}, 10)
	var m := _meta(1)
	m.funds = 100
	T110._add(m, db, &"oak_log")
	while T110._add(m, db, &"rope_coil") != null:
		pass
	var n := m.warehouse.item_count()
	if m.warehouse.can_admit(db.get_def(&"warhammer")):
		t.check(false, "仓库没塞满")
		return
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.full"), "说放不下")
	t.is_null(Smithy.forge(m, r, db), "不打")
	t.check(m.funds == 100 and m.warehouse.item_count() == n, "钱与素材都不动")


static func run_import(t: TestCase) -> void:
	t.begin("251 §三：导入器 —— 产物不是武器 / 防具 / 盾 / 插件、产物或素材 id 不存在、级不在 1 ～ 3、件数 < 1 都报错")
	var ctx := ContentImporter.Context.new()
	var db := T110._db()
	for id in db.ids():
		ctx.items[id] = db.get_def(id)
	var cases := [
		[{"id": "a", "output": "oak_log", "inputs": {"iron_ore": 1}, "funds": 1}, "产物不是装备"],
		[{"id": "b", "output": "no_such_251", "inputs": {"iron_ore": 1}, "funds": 1}, "产物 id 不存在"],
		[{"id": "c", "output": "shortsword", "inputs": {"no_such_251": 1}, "funds": 1}, "素材 id 不存在"],
		[{"id": "d", "output": "shortsword", "inputs": {"iron_ore": 0}, "funds": 1}, "件数 0"],
		[{"id": "e", "output": "shortsword", "inputs": {}, "funds": 1}, "没有素材"],
		[{"id": "g", "output": "shortsword", "inputs": {"iron_ore": 2}, "funds": 40}, "补充一：没写大类"],
		[{"id": "h", "output": "shortsword", "inputs": {"iron_ore": 2}, "funds": 40, "group": "spear"}, "补充一：大类不在六个里"],
	]
	for c in cases:
		var rep := ImportReport.new()
		ContentImporter.import_smith_recipe(c[0], ctx, rep)
		t.check(not rep.ok(), "%s：报错" % c[1])
	var good := ImportReport.new()
	ContentImporter.import_smith_recipe({"id": "f", "output": "shortsword", "inputs": {"iron_ore": 2}, "funds": 40, "group": "blade"}, ctx, good)
	t.check(good.ok(), "正常的不报错")


static func run_groups(t: TestCase) -> void:
	t.begin("251 补充一 §10.2：配方分六个大类（刀剑 / 斧锤 / 弓 / 法杖 / 盾 / 护甲）—— 首批 14 张各归各的，法杖暂空")
	var by := {}
	for g in SmithRecipeDef.GROUPS:
		by[g] = []
	for r in SmithRecipeDef.load_all():
		t.check(SmithRecipeDef.GROUPS.has(r.group), "%s 有大类（%s）" % [r.id, r.group])
		if by.has(r.group):
			(by[r.group] as Array).append(String(r.output))
	for g in by:
		(by[g] as Array).sort()
	t.eq(by["blade"], ["bloodletter", "cleaver", "festering_blade", "longsword", "mithril_sword", "shortsword"], "刀剑六张")
	t.eq(by["hammer"], ["pendulum_blade", "warhammer"], "斧锤两张")
	t.eq(by["bow"], ["longbow", "shortbow"], "弓两张")
	t.eq(by["staff"], ["grand_magus_staff", "mage_staff", "magic_staff", "magus_staff"], "252：法杖四张")
	t.eq(by["smelt"], ["mithril_ingot", "silver_ingot"], "252：冶炼两张")
	t.eq(by["shield"], ["round_shield"], "盾一张")
	t.eq(by["armor"], ["gambeson", "leather_armor", "plate_cuirass"], "护甲三张")
	for g in SmithRecipeDef.GROUPS:
		t.check(UiText.t("smithy.group_" + g) != "smithy.group_" + g, "%s 有名字" % g)
