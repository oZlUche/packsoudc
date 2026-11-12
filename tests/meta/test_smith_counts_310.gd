## 合成与锻造改造 C 批第三步（报告 310，方案 §5）：铁匠配方的材料格带件数（`material_slots`）——
## 同一类可以写两档；一件只顶一格；分配找最大解（不因先占稀缺件而打不了）；低档先用；新格出件固定品质 0；
## 15 件金武的 forge_* 打造配方；秘银剑、大魔导杖不再吃上一把武器
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const T251 := preload("res://tests/meta/test_smithy_251.gd")

const GOLD15: Array[StringName] = [&"flame_berserker_twin_axes", &"flame_bonesteel_broadsword", &"flame_bonesteel_spear", &"flame_composite_bow",
	&"flame_execution_blade", &"flame_executioner_axe", &"flame_meteor_maul", &"frost_bloodoath_axe", &"frost_bonesteel_greatsword",
	&"frost_dragoon_lance", &"imperial_sword", &"thunder_bloodthirst_twin_blades", &"thunder_boneiron_club", &"thunder_horse_halberd", &"thunder_siege_spear"]


## 第五步经济对照：基地卖价 900 的五件，资金提到 750，打了再卖不比直接卖料赚
const HEAVY: Array[StringName] = [&"flame_execution_blade", &"flame_executioner_axe", &"flame_meteor_maul", &"frost_bonesteel_greatsword", &"thunder_boneiron_club"]


static func _recipe(slots: Array) -> SmithRecipeDef:
	var r := SmithRecipeDef.new()
	r.id = &"t_counts"
	r.output = &"longsword"
	r.group = "blade"
	for s in slots:
		r.material_slots.append(s)
	return r


static func run_counts(t: TestCase) -> void:
	t.begin("310 · 材料格带件数：×2 要两件；两档同类各占一件；一件不顶两格；低档先用；重叠时找得到解")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var m := T251._meta(3)
	m.funds = 1000
	var r := _recipe([{"material": "bone", "min": 2, "count": 2}])
	t.eq(r.slots().size(), 1, "一格")
	t.eq(int(r.slots()[0]["count"]), 2, "件数 2")
	var claw := T110._add(m, db, &"beast_claw")
	t.eq(int(Smithy.have(m, r)[Smithy.SLOT_KEY % 0]), 1, "一件蓝骨：分到 1")
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.missing"), "要两件：缺")
	T110._add(m, db, &"antler")
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.missing"), "鹿角是绿的：不够档")
	var dice := T110._add(m, db, &"bone_dice")
	t.eq(Smithy.can_forge(m, r, db), "", "两件够档：能打")
	# 两档同类：金属 ≥金 ×1 + 金属 ≥紫 ×1。只有一件金：一件不顶两格
	var m2 := T251._meta(3)
	m2.funds = 1000
	var r2 := _recipe([{"material": "metal", "min": 3, "count": 1}, {"material": "metal", "min": 4, "count": 1}])
	var pale := T110._add(m2, db, &"pale_shard")
	t.eq(Smithy.can_forge(m2, r2, db), UiText.t("smithy.missing"), "只有一件苍白碎片：两格顶不满")
	var mith := T110._add(m2, db, &"mithril_ingot")
	t.eq(Smithy.can_forge(m2, r2, db), "", "加一块秘银锭：能打")
	var picks := Smithy.slot_picks(m2, r2)
	t.check((picks[0] as Array)[0] == mith and (picks[1] as Array)[0] == pale, "紫格用秘银锭、金格用苍白碎片（不让碎片去占紫格）")
	# 低档先用：再放一件金，紫格照旧用秘银锭
	T110._add(m2, db, &"pale_shard")
	t.check((Smithy.slot_picks(m2, r2)[0] as Array)[0] == mith, "多了一件金：紫格还是用秘银锭")
	mith.set_locked(true)
	t.eq(Smithy.can_forge(m2, r2, db), "", "秘银锭锁了：两件金各占一格")
	mith.set_locked(false)
	# 打出来：扣分到的那几件，固定品质 0
	var out := Smithy.forge(m2, r2, db)
	t.check(out != null and out.quality() == 0, "打出来，品质 0（高档材料只满足资格）")
	var ids: Array = m2.warehouse.items().map(func(i: ItemInstance) -> StringName: return i.def.id)
	t.check(not ids.has(&"mithril_ingot") and ids.count(&"pale_shard") == 1, "秘银锭和一件苍白碎片扣了（剩 %s）" % str(ids))
	var used := Smithy.slot_picks(m, r)
	t.check((used[0] as Array).has(claw) and (used[0] as Array).has(dice), "×2 的格分到兽爪和骨骰")


static func run_import(t: TestCase) -> void:
	t.begin("310 · 导入：material_slots 只认 material / min / count；件数至少 1；没有材料也没有 inputs 的报错；只写格的配方能导")
	var ctx := ContentImporter.Context.new()
	var db := ItemDatabase.new()
	db.load_dir()
	for id in db.all_ids():
		ctx.items[id] = db.get_def(id)
	var base := {"id": "t_slots", "output": "longsword", "group": "blade", "level": 1, "funds": 0}
	var good := base.duplicate()
	good["material_slots"] = [{"material": "metal", "min": 1, "count": 2}]
	var ok := ImportReport.new()
	var def := ContentImporter.import_smith_recipe(good, ctx, ok)
	t.check(ok.ok(), "只写格：不报错")
	t.check(def != null and int(def.slots()[0]["count"]) == 2 and typeof(def.slots()[0]["count"]) == TYPE_INT, "件数读成整数 2")
	for bad in [[{"material": "metal", "min": 1, "count": 0}], [{"material": "metal", "min": 1, "count": 1, "x": 1}], [{"material": "nope", "min": 1, "count": 1}]]:
		var d := base.duplicate()
		d["material_slots"] = bad
		var rep := ImportReport.new()
		ContentImporter.import_smith_recipe(d, ctx, rep)
		t.check(not rep.ok(), "坏格报错：%s" % str(bad))
	var rep2 := ImportReport.new()
	ContentImporter.import_smith_recipe(base, ctx, rep2)
	t.check(not rep2.ok(), "什么都不要：报错")


static func run_content(t: TestCase) -> void:
	t.begin("310 · 15 件金武有 forge_* 打造配方（铁匠铺 3 级、300 或 750、只用材料格、不吃武器）；秘银剑、大魔导杖不再吃上一把")
	var db := ItemDatabase.new()
	db.load_dir()
	var all := SmithRecipeDef.load_all()
	for out in GOLD15:
		var r := SmithRecipeDef.find(all, StringName("forge_" + String(out)))
		t.check(r != null and r.output == out, "forge_%s 在" % out)
		if r == null:
			continue
		t.check(r.inputs.is_empty() and r.material_inputs.is_empty() and not r.material_slots.is_empty(), "%s：只用材料格" % out)
		t.check(r.level == 3 and r.funds == (750 if HEAVY.has(out) else 300), "%s：3 级、%d" % [out, r.funds])
		for s in r.slots():
			t.not_null(SmithRecipeDef.slot_sample(s, db), "%s：%s ≥%d 有能顶的" % [out, s["material"], int(s["min"])])
	for id in [&"smith_mithril_sword", &"smith_grand_magus_staff"]:
		var r := SmithRecipeDef.find(all, id)
		t.not_null(r, "%s 在" % id)
		if r != null:
			for key in r.inputs:
				var d := db.get_def(StringName(String(key)))
				t.check(d != null and not d.tags.has(&"weapon"), "%s：不吃武器（%s）" % [id, key])
