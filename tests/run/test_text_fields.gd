## 104 第十节（第 ⑤ 批）：说明文本里的数只能来自字段。
## 改字段 → 文字跟着变；note 是补充不覆盖；`{item_stat:…}` 取别的道具的数；整个 data/authoring 零裸数字。
extends RefCounted


static func run_params(t: TestCase) -> void:
	t.begin("104⑤ · TextParams：数值字段、字典键、注册表构件加类型前缀、mods 首条不加前缀")
	var opt := EventOption.new()
	var pay := ChangeMoney.new()
	pay.amount = -10
	opt.outcomes.append(pay)
	var cond := StepsWithin.new()
	cond.min_steps = 4
	opt.requires.append(cond)
	var p := TextParams.of(opt)
	t.eq(p.get("change_money_amount"), -10, "结果：类型_字段")
	t.eq(p.get("steps_within_min_steps"), 4, "条件：类型_字段")
	opt.label = "给他 {change_money_amount|abs} 币（步数 ≥ {steps_within_min_steps}）"
	t.eq(TextTemplate.plain(opt.label, p), "给他 10 币（步数 ≥ 4）", "abs 过滤器")
	pay.amount = -25
	t.eq(TextTemplate.plain(opt.label, TextParams.of(opt)), "给他 25 币（步数 ≥ 4）", "改字段，文字跟着变")

	var ch := CharacterDef.new()
	ch.base_stats = {"max_hp": 50}
	ch.description = "生命 {max_hp}"
	t.eq(Names.description_of(ch), "生命 50", "字典键 + Names.description_of 走模板")
	ch.base_stats = {"max_hp": 61}
	t.eq(Names.description_of(ch), "生命 61", "改字段，说明跟着变")

	var buff := RunBuffDef.new()
	buff.duration_steps = 5
	var m := StatModifier.new()
	m.mult_category = StatMath.Buff.EMPOWER
	m.mult_percent = -10
	buff.mods.append(m)
	buff.description = "走 {duration_steps} 步之内伤害 {mult_percent|signed}%"
	t.eq(Names.description_of(buff), "走 5 步之内伤害 -10%", "mods 首条不加前缀；signed")
	m.mult_percent = 15
	t.eq(Names.description_of(buff), "走 5 步之内伤害 +15%", "signed 正数带 +")
	t.eq(TextTemplate.render("{amount|nope}", {"amount": 3}), "{amount|nope}", "不认识的过滤器原样保留")
	t.eq(TextTemplate.render("{x}", {"x": 4.0}), "4", "整数值的 float 写成整数")


static func run_notes(t: TestCase) -> void:
	t.begin("104⑤ · note 是补充：主句由字段生成；FaithBonus.describe 带门槛与修饰；改 per_points 文字跟着变")
	var fb := FaithBonus.new()
	fb.mode = "scaled"
	fb.per_points = 50
	fb.max_stacks = 6
	var m := StatModifier.new()
	m.flat = 1.0
	fb.mods.append(m)
	var a := fb.describe()
	t.check(a.contains("每 50 信力一份") and a.contains("最多 6 份") and a.contains("+1"), "主句按字段：%s" % a)
	fb.per_points = 40
	t.check(fb.describe().contains("每 40 信力一份"), "改 per_points：%s" % fb.describe())
	fb.note = "满 {max_stacks} 份封顶"
	t.check(fb.describe().ends_with("满 6 份封顶") and fb.describe().contains("每 40 信力"), "note 接在后面、也读字段：%s" % fb.describe())
	fb.mode = "tier"
	fb.tier = 2
	t.check(fb.describe().begins_with("Lv.2"), "阶统一写 Lv.n：%s" % fb.describe())

	var perk := StatModPerk.new()
	var pm := StatModifier.new()
	pm.stat = &"max_stamina"
	pm.flat = 20.0
	perk.mods.append(pm)
	t.check(perk.describe().contains("+20"), "等级效果主句按字段：%s" % perk.describe())
	perk.note = "补一句"
	t.check(perk.describe().contains("+20") and perk.describe().ends_with("补一句"), "note 不再覆盖主句：%s" % perk.describe())

	var rule := OfferingRule.new()
	rule.multiplier = 5.0
	rule.note = "（×{multiplier}）"
	t.check(rule.describe().contains("2^稀有度 × 5") and rule.describe().ends_with("（×5）"), "献祭：主句 + note：%s" % rule.describe())
	rule.multiplier = 2.5
	t.check(rule.describe().contains("× 2.5"), "非整数倍率：%s" % rule.describe())


static func run_item_stat(t: TestCase) -> void:
	t.begin("104⑤ · {item_stat:道具:字段}：基础属性、伤害修正、buff 里的属性修饰；教程文本里的数跟着道具走")
	var db := ItemDatabase.new()
	db.load_dir()
	var ctx := {"_items": db}
	var leather := db.get_def(&"leather_armor")
	t.eq(TextTemplate.render("{item_stat:leather_armor:max_shield}", ctx), TextTemplate.num(float(leather.combat.base_stats.get("max_shield", -1))), "base_stats")
	var shield := db.get_def(&"tower_shield")
	t.eq(TextTemplate.render("{item_stat:tower_shield:armor}", ctx), TextTemplate.num(float(shield.combat.base_stats.get("armor", -1))), "塔盾的防护")
	var m := ModifyDamage.new()
	m.flat = -4.0
	var tree := CombatProfile.new()
	var rule := AbilityRule.new()
	rule.effects.append(m)
	tree.rules.append(rule)
	t.eq(TextTemplate._find_field(tree, "flat", 0), -4.0, "规则效果里的同名字段（伤害修正的 flat）")
	t.eq(TextTemplate.render("{x|abs}", {"x": -4.0}), "4", "abs")
	t.check(TextTemplate.render("{item_stat:warding_charm:max_shield}", ctx).is_valid_int(), "buff 里的属性修饰：%s" % TextTemplate.render("{item_stat:warding_charm:max_shield}", ctx))
	t.eq(TextTemplate.render("{item_stat:nope:max_shield}", ctx), "{item_stat:nope:max_shield}", "找不到原样保留")
	t.check(TextTemplate.render("{item_stat:leather_armor:max_shield}", {}) != "{item_stat:leather_armor:max_shield}", "没给道具库也能自己读一份")
	for id in ["tut2_battle_heavy", "tut2_battle_swarm", "tut2_battle_ward", "tut2_search_1_again", "tut_search_1_done"]:
		var ev: EventDef = load(ContentPaths.asset_file("events", id))
		var text := TextTemplate.plain(ev.text_for(), ctx)
		t.check(not text.contains("{item_stat"), "%s 的键都填上了" % id)


static func run_no_bare_numbers(t: TestCase) -> void:
	t.begin("104⑤ · 裸数字检查：剥掉 {…} 与 BBCode 后的阿拉伯数字才算；整个 data/authoring 清零")
	t.check(TextLint.has_bare_number("给他 10 币"), "写死的数")
	t.check(not TextLint.has_bare_number("给他 {change_money_amount|abs} 币"), "占位符不算")
	t.check(not TextLint.has_bare_number("[color=#8b93a1]三秒一下[/color]"), "BBCode 的颜色与汉字数不算")
	var hits := TextLint.scan({"options": [{"label": "体力 -1"}], "descriptions": {"en": "HP 50"}, "title": "第 1 章"})
	t.eq(hits.size(), 2, "查 label 与多语言说明，不查别的键：%s" % str(hits))
	var all := TextLint.scan_all()
	t.eq(all.size(), 0, "data/authoring 里没有写死的数字：%s" % "\n".join(all))
