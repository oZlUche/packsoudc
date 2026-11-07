## 288 效果说明文本普查（作者 2026-11-07 15:00：「检查其他效果的说明文本与实际机制匹配」）：
## 负重阈值 / 寸步难行的倍数从数据读、流血是减益（所有内嵌的流血副本也是）、卖价帮助页 = 数据、赐物按 by_type 拼、describe 补全
extends RefCounted

const NUMERALS := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]


static func run_load_numbers(t: TestCase) -> void:
	t.begin("288 §1 / 2 · 负重三档的阈值、寸步难行走一步乘几：词条、帮助页、HUD 句都从 standard 负重规则读")
	var rules := EncumbranceRules.standard()
	t.check(rules != null and rules.levels.size() == 3, "standard 负重规则三档")
	if rules == null or rules.levels.size() != 3:
		return
	var keep := UiText.lang
	for lang in ["zh", "en"]:
		UiText.lang = lang
		var names := ["吃力", "超重", "寸步难行"]
		for i in 3:
			var text := Glossary.term_text(names[i])
			t.check(text.contains(String.num(rules.levels[i].over, 2)) and not text.contains("{load:"), "%s %s：写 %s 倍（%s）" % [lang, names[i], String.num(rules.levels[i].over, 2), text])
		var step := Glossary.term_text("寸步难行")
		t.check(step.contains("×" + str(rules.travel_mult_of(3))), "%s 寸步难行：走一步 ×%d" % [lang, rules.travel_mult_of(3)])
		t.check(Glossary.term_text("负重").contains(String.num(rules.levels[0].over, 2)), "%s 负重：开始吃力的倍数" % lang)
		var page := _page("encumbrance")
		var shown := TextTemplate.render(page.text_for(lang)) if page != null else ""
		var ok := shown != "" and not shown.contains("{load:") and shown.contains("×")
		for lv in rules.levels:
			ok = ok and shown.contains(String.num((lv as EncumbranceLevel).over, 2))
		t.check(ok, "%s 帮助页「负重」：三个倍数与 ×N 都换成数" % lang)
		t.check(rules.effect_text(3).contains("×%d" % rules.travel_mult_of(3)), "%s HUD：走一步倒计时 ×N（不是 −N）" % lang)
	UiText.lang = keep
	t.check(not Glossary.term_text("负重").contains("包本身也算"), "负重：包本身不算重")


static func run_bleed_debuff(t: TestCase) -> void:
	t.begin("288 §3 · 流血是减益：定义本身、每件道具 / 反应 / 铸炉里内嵌的流血副本都标了（清减益 / 清增益按它分）")
	var bleed := load("res://data/buffs/bleed.tres") as BuffDef
	t.check(bleed != null and bleed.is_debuff, "bleed.tres 是减益")
	t.eq(Glossary.buff_kind(bleed), UiText.t("gloss.kind_debuff"), "名字行写减益")
	var copies := 0
	var wrong: Array[String] = []
	for dir in ["res://data/items", "res://data/reactions", "res://data/forge", "res://data/rule_parts", "res://data/enemies"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tres"):
				continue
			var found: Array[BuffDef] = []
			_collect_buffs(load(dir + "/" + f), found, {})
			for b in found:
				if b.id == &"bleed":
					copies += 1
					if not b.is_debuff:
						wrong.append(f)
	t.check(copies > 0, "找到内嵌的流血副本（%d 份）" % copies)
	t.eq(wrong, [] as Array[String], "每份都是减益")


static func run_shop_ratio(t: TestCase) -> void:
	t.begin("288 §4 · 商店帮助页的卖价 = 数据（局内 shop_sell_ratio、基地 sell_ratio）")
	var eco := load("res://data/economy_rules/standard.tres") as EconomyRules
	var meta := load("res://data/meta_rules/standard.tres") as MetaRules
	var page := _page("shop")
	t.check(eco != null and meta != null and page != null, "数据与帮助页都在")
	if eco == null or meta == null or page == null:
		return
	var run_word: String = NUMERALS[roundi(eco.shop_sell_ratio * 10.0)] + "成"
	var base_word: String = "五成" if is_equal_approx(meta.sell_ratio, 0.5) else NUMERALS[roundi(meta.sell_ratio * 10.0)] + "成"
	t.check(page.text.contains("回定价的" + run_word), "局内卖价写「%s」（%s）" % [run_word, eco.shop_sell_ratio])
	t.check(page.text.contains("基地卖是" + base_word), "带回基地写「%s」（%s）" % [base_word, meta.sell_ratio])
	t.check(not page.text.contains("包与珍宝不上架") and eco.shop_bag_slot_chance > 0.0, "货架会摆包：不再写「包不上架」")
	t.check(not _page("vitality").text.contains("首次战败"), "体力页：没有「首次战败免罚」了（安德烈乌斯是求饶）")


static func run_gift_summary(t: TestCase) -> void:
	t.begin("288 §6 · 大地三阶赐物：说明按 by_type 拼（精英含盾、事件含素材、核心是贵重品）")
	var earth := load("res://data/faiths/earth.tres") as FaithDef
	var perk: GiftOnEnterPerk = null
	for p in (earth.perks if earth != null else []):
		if p is GiftOnEnterPerk:
			perk = p
	t.not_null(perk, "大地有赐物")
	if perk == null:
		return
	var text := perk.describe()
	for key in perk.by_type:
		t.check(text.contains(NodeText.label_of(StringName(String(key)))), "写了 %s" % key)
		for tag in perk.by_type[key]:
			t.check(text.contains(Glossary.tag_name(StringName(String(tag)))), "%s 写了 %s" % [key, tag])
	t.check(not text.contains("珍宝") and not text.contains("BOSS"), "不再写「BOSS-珍宝」（%s）" % text)


static func run_describe(t: TestCase) -> void:
	t.begin("288 §9 / 15 / 16 · 生成句：寒冷只说武器、转化写状态名、per_stack / 读属性 / 按伤害的几成都写出来")
	t.check(UiText.t("gloss.next_fire_cooldown").begins_with("武器"), "寒冷：武器下一次出手")
	var conv := ConvertStatus.new()
	conv.from = &"poison"
	conv.to = load("res://data/buffs/virulent.tres") as BuffDef
	t.check(conv.describe().begins_with(Glossary.status_name(&"poison")), "转化：「%s」" % conv.describe())
	var leech := ChangeResource.new()
	leech.amount = 0.0
	leech.percent_of_damage = 25
	t.check(leech.describe().contains("25%") and not leech.describe().contains(" 0 点"), "吸血：写这一下伤害的 25%%（%s）" % leech.describe())
	var by_stat := ChangeResource.new()
	by_stat.amount_stat = &"max_armor"
	t.check(by_stat.describe().contains(Glossary.stat_name(&"max_armor")), "读属性：写属性名（%s）" % by_stat.describe())
	var plain := ChangeResource.new()
	plain.amount = 5.0
	t.eq(plain.describe(), UiText.t("fx.restore") % [5.0, Glossary.resource_name(&"hp")], "写死的数：句子不变")
	var each := ApplyStatus.new()
	each.buff = load("res://data/buffs/poison.tres") as BuffDef
	each.per_stack = true
	t.check(each.describe().begins_with("每层"), "施加 per_stack：每层（%s）" % each.describe())
	var axis := ShiftAxis.new()
	axis.axis = StatAxes.ATTACK_SPEED
	axis.per_stack = true
	t.check(axis.describe().begins_with("每层"), "轴 per_stack：每层（%s）" % axis.describe())


static func _page(id: String) -> HelpPageDef:
	return load("res://data/help_pages/%s.tres" % id) as HelpPageDef


## 顺着资源的属性往下找 BuffDef（道具规则 → 效果 → buff；反应 → 效果 → buff）
static func _collect_buffs(v: Variant, out: Array[BuffDef], seen: Dictionary) -> void:
	if v is Array:
		for x in v:
			_collect_buffs(x, out, seen)
		return
	if v is Dictionary:
		for x in (v as Dictionary).values():
			_collect_buffs(x, out, seen)
		return
	if not (v is Resource) or seen.has(v.get_instance_id()):
		return
	seen[v.get_instance_id()] = true
	if v is BuffDef:
		out.append(v)
	for p in (v as Resource).get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_STORAGE and (int(p["type"]) == TYPE_OBJECT or int(p["type"]) == TYPE_ARRAY or int(p["type"]) == TYPE_DICTIONARY):
			_collect_buffs((v as Resource).get(p["name"]), out, seen)
