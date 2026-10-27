## 195（作者「铸牌的几个方向都可以做，尤其是第五项，需要让标签对应道具更加繁多，撑起世界观」）：
## 每件道具恰好一个材质标签（十种，新增织物 / 草药 / 陶瓷）；三张表十个材质行 + 来源兜底；效果攻式 / 守式按用途选、升阶追加不替换；
## 用途的节奏系数；稀有度 0–5
extends RefCounted

const MATERIALS: Array[StringName] = [&"metal", &"gem", &"leather", &"bone", &"stone", &"wood", &"flesh", &"cloth", &"herb", &"clay"]


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _ench(effect: String, stance_purpose: String, rate: int, element: String = "") -> Dictionary:
	return {"trigger": "metal", "direction": "default", "rate": rate, "effect": effect, "target": stance_purpose, "tier": rate,
		"magnitude": 2, "element": element}


static func run_material_tags(t: TestCase) -> void:
	t.begin("195 §2 / 250 · 材质十种（新增织物 / 草药 / 陶瓷）；可生成的道具除「都行」外每件都填了材质（250：材质是字段，不再是标签）")
	var mats := ItemMaterials.IDS.duplicate()
	mats.sort()
	var want := MATERIALS.duplicate()
	want.sort()
	t.eq(mats, want, "材质十种")
	t.eq(TagRegistry.by_category("material"), [], "标签表里没有材质类了")
	var db := _db()
	var bad: Array[String] = []
	for id in db.ids(true):
		if id == &"douxing" or (db.get_def(id) as ItemDef).is_bullion():     # 244：金银不带材质（不进铸炉、不进配方）
			continue
		var def := db.get_def(id) as ItemDef
		if not MATERIALS.has(StringName(def.material)):
			bad.append("%s（%s）" % [id, def.material])
	t.check(bad.is_empty(), "每件一个：%s" % "、".join(bad))
	t.eq(db.get_def(&"pale_shard").material, "metal", "灰白色的金属碎片是金属")
	var e := Forge.table(&"effect")
	for m in MATERIALS:
		t.not_null(ForgeTable.find(e.material, m), "效果表有 %s 行" % m)
	for src in [&"nature", &"crafted", &"magic"]:
		t.not_null(ForgeTable.find(Forge.table(&"timing").material, src), "时机表有来源兜底 %s" % src)


static func run_rows_build(t: TestCase) -> void:
	t.begin("195 §4 · 十个材质行 + 兜底 + default：攻式、守式都拼得出规则；守式不打对手、攻式不打自己；元素只跟攻式")
	var e := Forge.table(&"effect")
	for row in e.material:
		var key := String((row as ForgeEntry).key)
		var el := "fire" if not (row as ForgeEntry).by_element.is_empty() else ""
		var atk := Forge.rule_of(_ench(key, "weapon", 3, el))
		var grd := Forge.rule_of(_ench(key, "shield", 3, el))
		t.check(atk != null and grd != null, "%s：两式都拼得出" % key)
		if atk == null or grd == null:
			continue
		var self_hit := false
		for eff in atk.effects:
			if eff is DealDamage and (eff as DealDamage).target == CombatEffect.Target.SELF:
				self_hit = true
		t.check(not self_hit, "%s 攻式不打自己" % key)
		var foe_touch := false
		for eff in grd.effects:
			if "target" in eff and int(eff.get("target")) == CombatEffect.Target.OPPONENT:
				foe_touch = true
		t.check(not foe_touch, "%s 守式只对自己" % key)
		t.check(Forge.prefix(_ench(key, "shield", 0)) != Forge.prefix(_ench(key, "weapon", 0)) or key == "default", "%s：攻守前缀不同" % key)
	var gem := Forge.rule_of(_ench("gem", "shield", 3, "fire"))
	var stamped := false
	for eff in gem.effects:
		if eff is ApplyStatus and (eff as ApplyStatus).buff != null and (eff as ApplyStatus).buff.id == &"scorch":
			stamped = true
	t.check(not stamped, "宝石守式不施加元素")
	var db := _db()
	var ench := Forge.forge(db.get_def(&"round_shield"), db.get_def(&"round_shield"), db.get_def(&"plate_cuirass"))
	var rule := Forge.rule_of(ench)
	t.eq(Forge.prefix(ench), "铁壁的", "盾进效果槽：守式「铁壁的」")
	t.check(rule != null and rule.effects[0] is ChangeResource and (rule.effects[0] as ChangeResource).resource_key == BattleStats.RES_ARMOR, "自己加护甲，不再打自己")


static func run_append_and_rarity(t: TestCase) -> void:
	t.begin("195 §4.2 / §5 · 升阶追加不替换：稀有度 0–1 一句、2 两句、3 起三句；4、5 基础句再 ×1.5、×2；稀有度 5 有自己的一行")
	for r in 6:
		var rule := Forge.rule_of(_ench("bone", "weapon", r))
		var want := [1, 1, 2, 3, 3, 3][r] as int
		t.eq(rule.effects.size(), want, "稀有度 %d：%d 句" % [r, want])
		t.check(rule.effects[0] is ApplyStatus and (rule.effects[0] as ApplyStatus).buff.id == &"bleed", "稀有度 %d：基础句还是流血" % r)
	t.eq((Forge.rule_of(_ench("bone", "weapon", 4)).effects[0] as ApplyStatus).stacks, 3, "稀有度 4：2 × 1.5 = 3 层")
	t.eq((Forge.rule_of(_ench("bone", "weapon", 5)).effects[0] as ApplyStatus).stacks, 4, "稀有度 5：2 × 2 = 4 层")
	for slot in ForgeTable.SLOTS:
		t.eq(Forge.table(slot).by_rarity(5).key, &"5", "%s 表有稀有度 5" % slot)
	var leather := Forge.rule_of(_ench("leather", "weapon", 0))
	t.eq((leather.effects[0] as ShiftAxis).delta, -2, "减速 −N：负号照写")
	var report := ImportReport.new()
	var data := {"id": "effect", "material": [{"key": "default", "effect": {"type": "deal_damage", "amount": 2.0, "damage_stat": ""}}],
		"purpose": [{"key": "default", "stance": "sideways"}], "rarity": [{"key": "6"}, {"key": "default"}]}
	ContentImporter.import_forge_table(data, preload("res://core/authoring/authoring_context.gd").context(), report)
	var text := report.to_text()
	t.check(text.contains("守式") and text.contains("attack / guard") and text.contains("0–5"), "导入器：缺守式、攻守写错、稀有度超出都报（%s）" % text.replace("\n", " / "))


static func run_cadence_mult(t: TestCase) -> void:
	t.begin("195 §4.1 · 节奏系数：武器 ×0.75、盾 ×1、防具 ×1.25；每次触发与开战时不乘")
	var db := _db()
	var cases := [[&"knife", 4.5], [&"round_shield", 4.0], [&"plate_cuirass", 3.75]]
	for c in cases:
		var def := db.get_def(c[0])
		var ench := Forge.forge(def, db.get_def(&"antler"), def)
		var cd := Forge.rule_of(ench).cadence as CooldownCadence
		t.check(cd != null and is_equal_approx(cd.seconds, float(c[1])), "%s：每 %s 秒（%s）" % [c[0], c[1], cd.seconds if cd != null else "?"])
	var leather := Forge.forge(db.get_def(&"leather_armor") if db.has_def(&"leather_armor") else db.get_def(&"raw_hide"), db.get_def(&"antler"), db.get_def(&"knife"))
	t.check(Forge.rule_of(leather).cadence is Always, "皮革（开战时）：固定一次，不乘")


static func run_any_status_timing(t: TestCase) -> void:
	t.begin("作者 10-27 · 时机槽木制 / 自然 / 布料 =「施加任意状态时」：文字不再是「？」，扳机不挑状态")
	for key in ["wood", "nature", "cloth"]:
		var ench := _ench("bone", "weapon", 2)
		ench["trigger"] = key
		var rule := Forge.rule_of(ench)
		t.not_null(rule, "%s：拼得出规则" % key)
		if rule == null:
			continue
		var trig := rule.trigger as OnStatusApplied
		t.check(trig != null and trig.buff_id == &"", "%s：施加状态时、没指定哪种" % key)
		var text := Glossary.trigger_text(rule.trigger)
		t.check(not text.contains("?") and text.contains("状态"), "%s：%s" % [key, text])
