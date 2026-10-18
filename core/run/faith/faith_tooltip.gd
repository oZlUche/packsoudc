## 信仰的悬浮说明（087；188 作者 2026-10-17 重排：「信仰说明的悬浮窗需要重新排版和设计字体颜色」）。
##
## 和道具窗同一套版式：名字行（神名、等级、休眠几件）+ 信力行 + 到下一阶的进度条 / 分隔线 / 各阶效果 / 虚线 / 信力来源 / 虚线 / 献祭。
## 颜色全走字色模板（`@faith` `@val` `@tip_fg` `@tip_desc` `@tip_meta` `@warn`），不写死十六进制。
## 不写：神的括号注、背景故事、阈值串、这个信仰的道具清单、机制说明。画是 [HoverTip] 的事（[method HoverTip.show_faith]）
##
## 188 补充一（作者 2026-10-18）：进度条分段（一段一级，[code]bar[/code] 给阈值与信力）；同一级的效果合并成一行（[code][table=2][/code]，
## 折行对齐在句子下面）；没到的级整行灰（`@dim`），句子里随信力的数按到那一级时至少有的信力写；献祭有图标就排成一行图标
class_name FaithTooltip
extends RefCounted

const META_SIZE := 13
const POWER_SIZE := 14
## 献祭图标（标签 → `<TAG_ICON_DIR><tag>.png`；体积 / 属性条件 → `<OFFER_ICON_DIR>large.png` 等）
const TAG_ICON_DIR := "res://assets/ui/tags/"
const OFFER_ICON_DIR := "res://assets/ui/offerings/"
const ICON_SIZE := 24
const ICON_NAME_SIZE := 12


## `{"head": 名字行 + 信力行, "sections": [各阶效果?, 信力来源, 献祭?]（各段 BBCode）, "bar": {"thresholds", "points"}（分段进度条）, "text": 连起来}`。
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
		sections.append(_perk_section(def, p))
	var deeds: Array[String] = []
	for d in def.deeds:
		if d != null and String(d.describe()) != "":
			deeds.append(_fg(Glossary.val_numbers(String(d.describe()))))
	if not deeds.is_empty():
		sections.append(_section("信力来源", deeds))
	var offers := _offer_section(def)
	if offers != "":
		sections.append(offers)
	for i in sections.size():
		sections[i] = "[font_size=%d]%s[/font_size]" % [Glossary.BODY_SIZE, sections[i]]
	var head := _head(def, p, tier, next, dormant)
	return {
		"head": head,
		"sections": sections,
		"bar": {"thresholds": def.thresholds.duplicate(), "points": p},
		"text": "\n".join([head] + sections),
	}


## 只要文字（连起来）；没有信仰空串
static func describe(def: FaithDef, power: FaithPower = null, board: ItemContainer = null) -> String:
	return String(describe_full(def, power, board).get("text", ""))


static func _head(def: FaithDef, points: int, tier: int, next: int, dormant: int) -> String:
	var right := ""
	if dormant > 0:
		right += _meta("[color=%swarn]%d 件休眠[/color]" % [TextTemplate.STYLE_PREFIX, dormant]) + "　"
	right += _meta("Lv.%s" % Glossary.val(str(tier)))
	var name := "[font_size=%d]%s[/font_size]" % [Glossary.NAME_SIZE, Glossary.NAME_OUTLINE % ("[b][color=%sfaith]%s[/color][/b]" % [TextTemplate.STYLE_PREFIX, Names.of(def)])]
	var power := "信力 %s%s" % [Glossary.val(str(points)), (" / " + Glossary.val(str(next))) if next >= 0 else "（满阶）"]
	return "%s　　%s\n[font_size=%d][color=%stip_meta]%s[/color][/font_size]" % [name, right, POWER_SIZE, TextTemplate.STYLE_PREFIX, power]


## 各级效果：同一级合并成一行（「；」连），左列 Lv 号、右列句子（[code][table=2][/code]）。到了的亮字 + 数值色；没到的整行 `@dim`，
## 随信力的数按 max(现在的信力, 那一级的阈值) 写
static func _perk_section(def: FaithDef, points: int) -> String:
	var tier := def.tier_of(points)
	var by_tier := {}
	var order: Array[int] = []
	for pk in def.perks:
		var perk := pk as FaithPerk
		if perk == null:
			continue
		var at := points if tier >= perk.tier else maxi(points, def.thresholds[perk.tier - 1] if perk.tier - 1 < def.thresholds.size() else points)
		var line := perk.summary_for(def, at)
		if line == "":
			continue
		if not by_tier.has(perk.tier):
			by_tier[perk.tier] = []
			order.append(perk.tier)
		(by_tier[perk.tier] as Array).append(line)
	order.sort()
	var cells: Array[String] = []
	for lv in order:
		var text := "；".join(PackedStringArray(by_tier[lv]))
		if tier >= lv:
			cells.append("[cell]%s　[/cell][cell expand=1]%s[/cell]" % [_meta("Lv.%d" % lv), _fg(Glossary.val_numbers(text))])
		else:
			cells.append("[cell]%s　[/cell][cell expand=1]%s[/cell]" % [_dim("[font_size=%d]Lv.%d[/font_size]" % [META_SIZE, lv]), _dim(text)])
	return "[table=2]%s[/table]" % "".join(cells) if not cells.is_empty() else ""


## 献祭：每条规矩的图标都在 → 一行图标（下面小字名字）；有一枚缺图就整段退回文字
static func _offer_section(def: FaithDef) -> String:
	var rules: Array[OfferingRule] = []
	for r in def.offerings:
		if r != null:
			rules.append(r as OfferingRule)
	if rules.is_empty():
		return ""
	var cells: Array[String] = []
	var all_art := true
	for r in rules:
		var icons := icon_paths(r)
		if icons.is_empty():
			all_art = false
			break
		var imgs := ""
		for path in icons:
			imgs += "[img=%d]%s[/img]" % [ICON_SIZE, path]
		cells.append("[cell][center]%s\n[font_size=%d]%s[/font_size][/center][/cell]" % [imgs, ICON_NAME_SIZE, _fg(r.short_name())])
	if all_art:
		return _meta("献祭") + "\n[table=%d]%s[/table]" % [cells.size(), "".join(cells)]
	var lines: Array[String] = []
	for r in rules:
		lines.append(_fg(Glossary.val_numbers(r.describe())))
	return _section("献祭", lines)


## 一条献祭规矩的图标（标签各一枚、体积 / 属性条件一枚）；有一枚没有图就返回空
static func icon_paths(r: OfferingRule) -> Array[String]:
	var out: Array[String] = []
	for t in r.tags:
		out.append(TAG_ICON_DIR + String(t) + ".png")
	if r.min_cells > 0:
		out.append(OFFER_ICON_DIR + ("large" if ItemVolume.grade_of_cells(r.min_cells) >= 3 else "medium") + ".png")
	if r.exact_grade >= 0:
		out.append(OFFER_ICON_DIR + ("large" if r.exact_grade >= 3 else "medium") + ".png")
	if r.has_stat != &"":
		out.append(OFFER_ICON_DIR + ("crit" if String(r.has_stat).begins_with("crit") else String(r.has_stat)) + ".png")
	for path in out:
		if not ResourceLoader.exists(path):
			return [] as Array[String]
	return out


static func _section(title: String, lines: Array[String]) -> String:
	return _meta(title) + "\n" + "\n".join(lines)


static func _meta(text: String) -> String:
	return "[font_size=%d][color=%stip_meta]%s[/color][/font_size]" % [META_SIZE, TextTemplate.STYLE_PREFIX, text]


static func _dim(text: String) -> String:
	return "[color=%sdim]%s[/color]" % [TextTemplate.STYLE_PREFIX, text]


static func _fg(text: String) -> String:
	return "[color=%stip_fg]%s[/color]" % [TextTemplate.STYLE_PREFIX, text]
