## 信仰的悬浮说明（087；188 作者 2026-10-17 重排：「信仰说明的悬浮窗需要重新排版和设计字体颜色」）。
##
## 和道具窗同一套版式：名字行（神名、等级、休眠几件）+ 信力行 + 到下一阶的进度条 / 分隔线 / 各阶效果 / 虚线 / 信力来源 / 虚线 / 献祭。
## 颜色全走字色模板（`@faith` `@val` `@tip_fg` `@tip_desc` `@tip_meta` `@warn`），不写死十六进制。
## 不写：神的括号注、背景故事、阈值串、这个信仰的道具清单、机制说明。画是 [HoverTip] 的事（[method HoverTip.show_faith]）
class_name FaithTooltip
extends RefCounted

const META_SIZE := 13
const POWER_SIZE := 14


## `{"head": 名字行 + 信力行, "sections": [各阶效果?, 信力来源, 献祭?]（各段 BBCode）, "progress": 到下一阶的比例（满阶 -1）, "text": 连起来}`。
## [param power] 可为 null（只写定义，按 0 点算）；[param board] 给了就数休眠的道具。没有信仰返回空字典（悬浮窗不开）
static func describe_full(def: FaithDef, power: FaithPower = null, board: ItemContainer = null) -> Dictionary:
	if def == null:
		return {}
	var p := power.points_of(def.id) if power != null else 0
	var tier := def.tier_of(p)
	var next := def.next_threshold(p)
	var dormant := FaithState.dormant_uids(board).size() if board != null else 0
	var sections: Array[String] = []
	if not def.perks.is_empty():
		sections.append(_perk_section(def, tier))
	var deeds: Array[String] = []
	for d in def.deeds:
		if d != null and String(d.describe()) != "":
			deeds.append(_fg(Glossary.val_numbers(String(d.describe()))))
	if not deeds.is_empty():
		sections.append(_section("信力来源", deeds))
	var offers: Array[String] = []
	for r in def.offerings:
		if r != null:
			offers.append(_fg(Glossary.val_numbers((r as OfferingRule).describe())))
	if not offers.is_empty():
		sections.append(_section("献祭", offers))
	for i in sections.size():
		sections[i] = "[font_size=%d]%s[/font_size]" % [Glossary.BODY_SIZE, sections[i]]
	var head := _head(def, p, tier, next, dormant)
	return {
		"head": head,
		"sections": sections,
		"progress": progress_of(def, p),
		"text": "\n".join([head] + sections),
	}


## 只要文字（连起来）；没有信仰空串
static func describe(def: FaithDef, power: FaithPower = null, board: ItemContainer = null) -> String:
	return String(describe_full(def, power, board).get("text", ""))


## 到下一阶走了多少（待定 3 甲：从本阶阈值算起）；满阶 -1
static func progress_of(def: FaithDef, points: int) -> float:
	var next := def.next_threshold(points)
	if next < 0:
		return -1.0
	var tier := def.tier_of(points)
	var from := def.thresholds[tier - 1] if tier > 0 else 0
	return clampf(float(points - from) / float(maxi(1, next - from)), 0.0, 1.0)


static func _head(def: FaithDef, points: int, tier: int, next: int, dormant: int) -> String:
	var right := ""
	if dormant > 0:
		right += _meta("[color=%swarn]%d 件休眠[/color]" % [TextTemplate.STYLE_PREFIX, dormant]) + "　"
	right += _meta("Lv.%s" % Glossary.val(str(tier)))
	var name := "[font_size=%d]%s[/font_size]" % [Glossary.NAME_SIZE, Glossary.NAME_OUTLINE % ("[b][color=%sfaith]%s[/color][/b]" % [TextTemplate.STYLE_PREFIX, Names.of(def)])]
	var power := "信力 %s%s" % [Glossary.val(str(points)), (" / " + Glossary.val(str(next))) if next >= 0 else "（满阶）"]
	return "%s　　%s\n[font_size=%d][color=%stip_meta]%s[/color][/font_size]" % [name, right, POWER_SIZE, TextTemplate.STYLE_PREFIX, power]


## 各阶效果：到了的亮字（数值色），没到的整行暗
static func _perk_section(def: FaithDef, tier: int) -> String:
	var lines: Array[String] = []
	for pk in def.perks:
		var perk := pk as FaithPerk
		if perk == null or perk.describe() == "":
			continue
		if tier >= perk.tier:
			lines.append("%s　%s" % [_meta("Lv.%d" % perk.tier), _fg(Glossary.val_numbers(perk.describe()))])
		else:
			lines.append("[color=%stip_desc][font_size=%d]Lv.%d[/font_size]　%s[/color]" % [TextTemplate.STYLE_PREFIX, META_SIZE, perk.tier, perk.describe()])
	return "\n".join(lines)


static func _section(title: String, lines: Array[String]) -> String:
	return _meta(title) + "\n" + "\n".join(lines)


static func _meta(text: String) -> String:
	return "[font_size=%d][color=%stip_meta]%s[/color][/font_size]" % [META_SIZE, TextTemplate.STYLE_PREFIX, text]


static func _fg(text: String) -> String:
	return "[color=%stip_fg]%s[/color]" % [TextTemplate.STYLE_PREFIX, text]
