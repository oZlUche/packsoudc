## 279 第二步：铁匠铺配方按材质类认素材（`material_inputs`：材质 → 最低稀有度）；30 张升蓝（上一把 + 一件绿或更高的某类材料）；
## 14 张拼接（两件贴着、点锤合 —— `RecipeDef.adjacent`，拖上去合的查不到它们）
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const T251 := preload("res://tests/meta/test_smithy_251.gd")


static func _anvils() -> Array[SmithRecipeDef]:
	var out: Array[SmithRecipeDef] = []
	for r in SmithRecipeDef.load_all():
		if String(r.id).begins_with("anvil_"):
			out.append(r)
	return out


static func run_content(t: TestCase) -> void:
	t.begin("279 第二步 / 第二批 · 内容：一件上一档武器 + 一类材料，产物高一档 —— 升蓝 30 张（绿起、工钱 60、铺子 1 级）、升紫 32 张（蓝起、120、2 级）、升橙 16 张（魔晶紫起 / 灰白金属碎片，200、3 级，产物只能锻造）；281 极端武器两条线各加一张升紫、一张升橙")
	var db := T110._db()
	var all := _anvils()
	var by_tier := {2: 0, 3: 0, 4: 0}
	for r in all:
		var out := db.get_def(r.output)
		t.check(out != null and out.tags.has(&"weapon"), "%s：产物是武器" % r.id)
		t.eq(r.inputs.size(), 1, "%s：吃一件上一把" % r.id)
		t.eq(r.material_inputs.size(), 1, "%s：一类材料" % r.id)
		if out == null or r.inputs.size() != 1:
			continue
		by_tier[out.rarity] = int(by_tier.get(out.rarity, 0)) + 1
		var src := db.get_def(StringName(String(r.inputs.keys()[0])))
		t.check(src != null and src.tags.has(&"weapon") and src.rarity + 1 == out.rarity, "%s：%s → %s 升一档" % [r.id, r.inputs.keys()[0], r.output])
		for m in r.material_inputs:
			var lo := int(r.material_inputs[m])
			if out.rarity == 4:
				t.check((SmithRecipeDef.is_crystal_key(String(m)) and lo == 3) or (String(m) == "metal" and lo == 4), "%s：升橙要魔晶石（紫起）或灰白金属碎片" % r.id)
			else:
				t.check(not SmithRecipeDef.is_crystal_key(String(m)) and lo >= out.rarity - 1, "%s：材料要比产物低一档起" % r.id)
			t.not_null(r.material_sample(String(m), db), "%s：道具库里有能顶的 %s" % [r.id, m])
		var want := {2: [60, 1], 3: [120, 2], 4: [200, 3]}.get(out.rarity, [0, 0]) as Array
		t.check(r.funds == int(want[0]) and r.level == int(want[1]), "%s：工钱 %d、铺子 %d 级" % [r.id, want[0], want[1]])
		t.eq(out.is_forged_only(), out.rarity == 4, "%s：只有橙档只能锻造" % r.id)
	t.eq(by_tier, {2: 30, 3: 34, 4: 18}, "升蓝 30、升紫 32 + 2、升橙 16 + 2（281 极端武器）")


static func run_material_fits(t: TestCase) -> void:
	t.begin("279 第二步 · 认材料：是素材、材质对、稀有度够才顶得上；武器不算材料；最便宜的样子")
	var db := T110._db()
	var r := SmithRecipeDef.new()
	r.material_inputs = {"bone": 1}
	t.check(r.material_fits("bone", db.get_def(&"antler")), "鹿角（骨、绿）顶得上")
	t.check(r.material_fits("bone", db.get_def(&"beast_claw")), "兽爪（骨、蓝）也行")
	t.check(not r.material_fits("bone", db.get_def(&"barbarian_necklace")), "蛮族的项链是白的：不够档")
	t.check(not r.material_fits("bone", db.get_def(&"steel_ingot")), "钢锭不是骨")
	t.check(not r.material_fits("bone", db.get_def(&"bone_broadsword")), "骨柄阔剑是武器、不是材料")
	var s := r.material_sample("bone", db)
	t.check(s != null and s.rarity == 1, "样子取最便宜的一件绿骨材")


static func run_forge(t: TestCase) -> void:
	t.begin("279 第二步 · 打：仓库里有上一把和够档的那类材料就打；先用最便宜的材料，好的留着；锁住的不算；扣的是选中的那件")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var r := SmithRecipeDef.find(SmithRecipeDef.load_all(), &"anvil_bone_broadsword")
	t.not_null(r, "骨柄阔剑的配方在")
	if r == null:
		return
	var m := T251._meta(1)
	m.funds = 100
	T110._add(m, db, &"broadsword")
	T110._add(m, db, &"barbarian_necklace")
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.missing"), "只有白骨材：缺素材")
	t.eq(int(Smithy.have(m, r).get(Smithy.MATERIAL_KEY % "bone", -1)), 0, "材质格记 0")
	var claw := T110._add(m, db, &"beast_claw")
	var antler := T110._add(m, db, &"antler")
	t.eq(Smithy.can_forge(m, r, db), "", "有了：能打")
	t.eq((Smithy.material_picks(m, r)["bone"] as ItemInstance).uid, antler.uid, "先用鹿角（绿），兽爪（蓝）留着")
	antler.set_locked(true)
	t.eq((Smithy.material_picks(m, r)["bone"] as ItemInstance).uid, claw.uid, "鹿角锁了：用兽爪")
	antler.set_locked(false)
	var out := Smithy.forge(m, r, db)
	t.check(out != null and out.def.id == &"bone_broadsword", "打出骨柄阔剑")
	var left: Array = m.warehouse.items().map(func(i: ItemInstance) -> StringName: return i.def.id)
	t.check(not left.has(&"broadsword") and not left.has(&"antler"), "阔剑和鹿角扣了")
	t.check(left.has(&"beast_claw") and left.has(&"barbarian_necklace"), "兽爪、项链还在")
	t.eq(m.funds, 40, "工钱 60")


static func run_import(t: TestCase) -> void:
	t.begin("279 第二步 · 导入器：材质不认识、稀有度不在 0 ～ 5、道具库里没有能顶的都报错")
	var ctx := ContentImporter.Context.new()
	var db := T110._db()
	for id in db.ids():
		ctx.items[id] = db.get_def(id)
	var base := {"id": "x", "output": "bone_broadsword", "inputs": {"broadsword": 1}, "funds": 60, "group": "blade"}
	for c in [[{"plastic": 1}, "材质不认识"], [{"bone": 9}, "稀有度太高"], [{"gem": 3}, "没有蓝起的宝石材料"]]:
		var d := base.duplicate()
		d["material_inputs"] = c[0]
		var rep := ImportReport.new()
		ContentImporter.import_smith_recipe(d, ctx, rep)
		t.check(not rep.ok(), "%s：报错" % c[1])
	var good := base.duplicate()
	good["material_inputs"] = {"bone": 1}
	var ok := ImportReport.new()
	ContentImporter.import_smith_recipe(good, ctx, ok)
	t.check(ok.ok(), "正常的不报错")


static func run_fusions(t: TestCase) -> void:
	t.begin("279 第二步 · 拼接配方：14 张，两件（白武器或材料，木棍 + 燧石 = 石锤）→ 绿；只按「贴着」查得到，拖上去合查不到；旧的拖合配方不受影响")
	var db := T110._db()
	var fuse: Array[RecipeDef] = []
	for r in RecipeDef.load_all():
		if r.adjacent:
			fuse.append(r)
	t.eq(fuse.size(), 14, "14 张")
	for r in fuse:
		var out := db.get_def(r.output)
		t.check(out != null and out.tags.has(&"weapon") and out.rarity == 1, "%s：产物是绿武器" % r.id)
		t.eq(r.inputs.size(), 2, "%s：两件" % r.id)
		for id in r.inputs:
			var d := db.get_def(id)
			t.not_null(d, "%s：%s 在" % [r.id, id])
			if d != null and d.tags.has(&"weapon"):
				t.eq(d.rarity, 0, "%s：拼的武器是白的（%s）" % [r.id, id])
	var all := RecipeDef.load_all()
	t.not_null(RecipeDef.find(all, &"knife", &"knife", true), "匕首 + 匕首：贴着拼得到双刀")
	t.is_null(RecipeDef.find(all, &"knife", &"knife"), "拖上去合查不到")
	t.not_null(RecipeDef.find(all, &"poison_vial", &"knife"), "涂毒匕首照旧拖上去合")
	t.is_null(RecipeDef.find(all, &"poison_vial", &"knife", true), "涂毒匕首不是拼接")
