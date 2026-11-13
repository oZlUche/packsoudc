## 279 第二步：铁匠铺配方按材质类认素材（`material_inputs`：材质 → 最低稀有度）；改造 D 批起砧升级（anvil_*）全拆；
## 14 张拼接（两件贴着、点锤合 —— `RecipeDef.adjacent`，拖上去合的查不到它们）
extends RefCounted

const TestReformC := preload("res://tests/inventory/test_fusion_reform_c.gd")

const T110 := preload("res://tests/meta/test_tech.gd")
const T251 := preload("res://tests/meta/test_smithy_251.gd")


static func run_content(t: TestCase) -> void:
	t.begin("改造 D · 砧升级拆了：没有 anvil_* 配方、铁匠铺配方不吃武器；不进随机来源的武器各有铁匠铺打造或合成来源")
	var db := T110._db()
	var smith := SmithRecipeDef.load_all()
	t.eq(smith.filter(func(r: SmithRecipeDef) -> bool: return String(r.id).begins_with("anvil_")).size(), 0, "没有 anvil_* 配方")
	for r in smith:
		for key in r.inputs:
			var d := db.get_def(StringName(String(key)))
			t.check(d == null or not d.tags.has(&"weapon"), "%s：不吃武器（%s）" % [r.id, key])
	var made := {}
	for r in smith:
		made[r.output] = true
	for r in RecipeDef.load_all():
		made[r.output] = true
	var ids: Array = db.all_ids()
	Ids.sort(ids)
	for id in ids:
		var d := db.get_def(StringName(String(id)))
		if d != null and d.tags.has(&"weapon") and d.is_no_random_source() and not d.is_blessed():
			t.check(made.has(d.id), "%s：不进随机来源，有打造 / 合成来源" % d.id)


## 旧 anvil_bone_broadsword 的样子（阔剑 + 骨 ≥ 绿 → 骨柄阔剑，60）
static func bone_broadsword() -> SmithRecipeDef:
	var r := SmithRecipeDef.new()
	r.id = &"t_bone_broadsword"
	r.output = &"bone_broadsword"
	r.inputs = {&"broadsword": 1}
	r.material_inputs = {"bone": 1}
	r.funds = 60
	r.group = &"blade"
	r.level = 1
	return r


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
	var r := bone_broadsword()     # 改造 D：数据里的 anvil_* 拆了，这里按原样拼一张测铁匠铺的认材料
	var m := T251._meta(1)
	m.funds = 100
	T110._add(m, db, &"broadsword")
	T110._add(m, db, &"barbarian_necklace")
	t.eq(Smithy.can_forge(m, r, db), UiText.t("smithy.missing"), "只有白骨材：缺素材")
	t.eq(int(Smithy.have(m, r).get(Smithy.SLOT_KEY % 0, -1)), 0, "材质格记 0")
	var claw := T110._add(m, db, &"beast_claw")
	var antler := T110._add(m, db, &"antler")
	t.eq(Smithy.can_forge(m, r, db), "", "有了：能打")
	t.eq(((Smithy.slot_picks(m, r)[0] as Array)[0] as ItemInstance).uid, antler.uid, "先用鹿角（绿），兽爪（蓝）留着")
	antler.set_locked(true)
	t.eq(((Smithy.slot_picks(m, r)[0] as Array)[0] as ItemInstance).uid, claw.uid, "鹿角锁了：用兽爪")
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
		if String(r.id).begins_with("fuse_") and not TestReformC.NEW.has(r.id):     # 310：改造 C 批新加的六张另测（tests/inventory/test_fusion_reform_c.gd）；迁过来的 9 张生存配方不是 fuse_*
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
	t.not_null(RecipeDef.find(all, &"knife", &"knife"), "匕首 + 匕首：贴着拼得到双刀")
	t.not_null(RecipeDef.find(all, &"poison_vial", &"knife"), "310：涂毒匕首也是贴着拼")
	t.check(all.all(func(r: RecipeDef) -> bool: return r.adjacent), "310：没有拖上去合的配方了")
