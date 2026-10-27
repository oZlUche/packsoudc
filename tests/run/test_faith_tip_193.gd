## 193 §7（作者「让所有已实装的能力标注」）：信仰窗的各级效果也列这位神的道具的按阶加成（独有道具写名字、赐福版合成一行），
## 信力来源后面加包内转化一句
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _text(def: FaithDef, items: ItemDatabase) -> String:
	return Glossary.strip_bbcode(FaithTooltip.describe(def, null, null, items))


static func run_item_tiers(t: TestCase) -> void:
	t.begin("193 §7 · 狩猎之神：长弓的 Lv.1 / Lv.2 加成进了各级效果；新教没有这一段；蛮神的 perk 行不变、多出它的道具行；转化一句按阶写")
	var c := CS._content()
	var defs := FaithDef.load_all()
	var hunt: FaithDef = defs.get(&"hunt", null)
	t.not_null(hunt, "有狩猎之神")
	if hunt == null:
		return
	var lines := FaithTooltip.item_lines(hunt, c.items)
	t.check(lines.has(1) and (lines[1] as Array).any(func(l): return String(l).contains("长弓") and String(l).contains("+4")), "Lv.1：长弓 伤害 +4（%s）" % str(lines))
	t.check(lines.has(2) and (lines[2] as Array).any(func(l): return String(l).contains("长弓")), "Lv.2：长弓那一条")
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
		t.check(text.contains("蛮神的护符") and text.contains(FaithTooltip.BLESSED_NAME), "多出护符与赐福版的行")
		var blessed := 0
		for lv in FaithTooltip.item_lines(brute, c.items):
			for l in FaithTooltip.item_lines(brute, c.items)[lv]:
				if String(l).begins_with(FaithTooltip.BLESSED_NAME + "：伤害 +10%"):
					blessed += 1
		t.eq(blessed, 1, "十几件赐福版同一句只列一行")
		t.check(text.contains("每走一步") and text.contains("包里的道具各 3% 转为赐福版"), "转化一句（0 阶 3%；257 起两列：事 / 所得）")
		t.eq(FaithTooltip.convert_parts(brute, 0)[2], "3", "转化百分数 3")
		t.eq(FaithTooltip.convert_line(brute, 2), "每走一步，包里能被赐福的道具各有 5% 转化成赐福版", "2 阶 5%")
	t.eq(FaithTooltip.convert_line(hunt, 0), "", "狩猎之神没有赐福模板：不写转化")
