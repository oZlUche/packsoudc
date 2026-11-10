## 193 §7（作者「让所有已实装的能力标注」）：信仰窗的各级效果也列这位神的道具的按阶加成（独有道具写名字、赐福版合成一行），
## 信力来源后面加包内转化一句
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _text(def: FaithDef, items: ItemDatabase) -> String:
	return Glossary.strip_bbcode(String(FaithTooltip.describe_full(def, null, null, items).get("text", "")))


static func run_item_tiers(t: TestCase) -> void:
	t.begin("193 §7 · 狩猎之神：长弓的 Lv.1 / Lv.2 加成进了各级效果；新教没有这一段；蛮神的 perk 行不变、多出它的道具行；转化一句按阶写")
	var c := CS._content()
	var defs := FaithDef.load_all()
	var hunt: FaithDef = defs.get(&"hunt", null)
	t.not_null(hunt, "有狩猎之神")
	if hunt == null:
		return
	var groups := FaithTooltip.item_groups(hunt, c.items)
	var lv1 := false
	var lv2 := false
	for g in groups:
		if not String(g["name"]).contains("长弓"):
			continue
		for i in (g["lines"] as Array).size():
			lv1 = lv1 or (int(g["tiers"][i]) == 1 and String(g["lines"][i]).contains("+4"))
			lv2 = lv2 or int(g["tiers"][i]) == 2
	t.check(lv1, "Lv.1：长弓 伤害 +4（%s）" % str(groups))
	t.check(lv2, "Lv.2：长弓那一条")
	var full := FaithTooltip.describe_full(hunt, null, null, c.items)
	t.check(Glossary.strip_bbcode(String(full["sections"][0])).contains("长弓"), "狩猎之神没有 perk：第一段就是赐福之物（257），写着长弓")
	t.check(not Glossary.strip_bbcode(String(FaithTooltip.describe_full(hunt)["sections"][0])).contains("长弓"), "不给道具库：照旧（没有这一段）")
	var church: FaithDef = defs.get(&"church", null)
	if church != null:
		t.check(not _text(church, c.items).contains("Lv.1　"), "新教：没有各级效果")
	var brute: FaithDef = defs.get(&"brute", null)
	if brute != null:
		var text := _text(brute, c.items)
		for pk in brute.perks:
			var line := (pk as FaithPerk).summary_for(brute, 0)
			if line != "":
				t.check(text.contains(Glossary.strip_bbcode(line).substr(0, 6)), "perk 行还在：%s" % line.substr(0, 10))
		t.check(text.contains("蛮神的护符") and text.contains(FaithTooltip.blessed_name()), "多出护符与赐福版的行")
		var blessed := 0
		for g in FaithTooltip.item_groups(brute, c.items):
			if String(g["name"]) != FaithTooltip.blessed_name():
				continue
			for l in g["lines"]:
				if String(l).begins_with("伤害 +10%"):
					blessed += 1
		t.eq(blessed, 1, "十几件赐福版同一句只列一行")
		t.check(text.contains("每走一步") and text.contains("包里的道具各 3% 转为赐福版"), "转化一句（0 阶 3%；257 起两列：事 / 所得）")
		t.eq(FaithTooltip.convert_parts(brute, 0)[1], "包里的道具各 3% 转为赐福版", "转化百分数 3")
		t.eq(FaithTooltip.convert_parts(brute, 2)[1], "包里的道具各 5% 转为赐福版", "2 阶 5%")
	t.check(FaithTooltip.convert_parts(hunt, 0).is_empty(), "狩猎之神没有赐福模板：不写转化")
