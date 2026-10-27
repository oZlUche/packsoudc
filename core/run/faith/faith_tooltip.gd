## 信仰的悬浮说明（087；188 作者 2026-10-17 重排：「信仰说明的悬浮窗需要重新排版和设计字体颜色」）。
##
## 和道具窗同一套版式：名字行（神名、等级、休眠几件）+ 信力行 + 到下一阶的进度条 / 分隔线 / 各阶效果 / 虚线 / 信力来源 / 虚线 / 献祭。
## 颜色全走字色模板（`@faith` `@val` `@tip_fg` `@tip_desc` `@tip_meta` `@warn`），不写死十六进制。
## 不写：神的括号注、背景故事、阈值串、这个信仰的道具清单、机制说明。画是 [HoverTip] 的事（[method HoverTip.show_faith]）
##
## 188 补充一（作者 2026-10-18）：进度条分段（一段一级，[code]bar[/code] 给阈值与信力）；同一级的效果合并成一行（[code][table=2][/code]，
## 折行对齐在句子下面）；没到的级整行灰（`@dim`），句子里随信力的数按到那一级时至少有的信力写；献祭有图标就排成一行图标
##
## 193（作者「让所有已实装的能力标注」）：各级效果也列这位神的道具的按阶加成（[member ItemDef.faith_bonuses]：独有的道具写名字，
## 赐福版合成一行「赐福的道具」）；信力来源后面加一行包内转化。献祭图标一行排开、不写名字
##
## 257（作者 2026-10-27 定 甲 四段分立）：神赐（只有 perks，一阶一组、一条一行，阶号左列）/ 赐福之物（193 的道具加成按道具分组，名左阶右）/
## 信力来源（两列：事 → 所得）/ 献祭（图标下写 ×倍率）。分色：信力本身（Lv、点数、所得、倍率、「N 信力」）`@faith`；
## 加成的数 `@val`；条件里的数不上色（[method Glossary.bonus_numbers]）；没到的阶整组 `@dim`。一行最多两种颜色
class_name FaithTooltip
extends RefCounted

const META_SIZE := 14
const POWER_SIZE := 15
## 献祭图标（标签 → [method TagRegistry.icon_path]；体积 / 属性条件 → `<OFFER_ICON_DIR>large.png` 等）
const OFFER_ICON_DIR := "res://assets/ui/offerings/"
## 193 美术定稿（作者 2026-10-18「32像素，献祭栏里面不要名字，图标也要32像素」）
const ICON_SIZE := 32
## 193：献祭一行里规矩之间空多宽（两个全角空格，按这个字号算）
const OFFER_GAP_SIZE := 8
## 赐福版合成一行时写的名字
const BLESSED_NAME := "赐福的道具"
## 257：神赐的阶号列宽、赐福之物的右列（阶号）宽（[method Glossary.columns] 撑的宽；信力来源按字估，[method Glossary.two_widths]）
const LV_COL := 44
const ITEM_LV_COL := 44


## 221 F1：[constant BLESSED_NAME] 按当前语言
static func blessed_name() -> String:
	return UiText.t("faith.blessed")


## `{"head": 名字行 + 信力行, "sections": [神赐?, 赐福之物?, 信力来源, 献祭?]（各段 BBCode）, "bar": {"thresholds", "points"}（分段进度条）, "text": 连起来}`。
## [param power] 可为 null（只写定义，按 0 点算）；[param board] 给了就数休眠的道具；[param items] 给了就把这位神的道具的按阶加成单列一段「赐福之物」（193 / 257）。
## 没有信仰返回空字典（悬浮窗不开）
static func describe_full(def: FaithDef, power: FaithPower = null, board: ItemContainer = null, items: ItemDatabase = null) -> Dictionary:
	if def == null:
		return {}
	var p := power.points_of(def.id) if power != null else 0
	var tier := def.tier_of(p)
	var next := def.next_threshold(p)
	var dormant := FaithState.dormant_uids(board).size() if board != null else 0
	var sections: Array[String] = []
	var perks := _perk_section(def, p)
	if perks != "":
		sections.append(perks)
	var gifts := _item_section(def, tier, items)
	if gifts != "":
		sections.append(gifts)
	var sources := _source_section(def, tier)
	if sources != "":
		sections.append(sources)
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
static func describe(def: FaithDef, power: FaithPower = null, board: ItemContainer = null, items: ItemDatabase = null) -> String:
	return String(describe_full(def, power, board, items).get("text", ""))


static func _head(def: FaithDef, points: int, tier: int, next: int, dormant: int) -> String:
	var right := ""
	if dormant > 0:
		right += _meta("[color=%swarn]%s[/color]" % [TextTemplate.STYLE_PREFIX, UiText.t("faith.dormant") % dormant]) + "　"
	right += _meta(Glossary.faith("Lv.%d" % tier))     # 257：Lv 与信力数都是信力色
	var name := "[font_size=%d]%s[/font_size]" % [Glossary.NAME_SIZE, Glossary.NAME_OUTLINE % ("[b][color=%sfaith]%s[/color][/b]" % [TextTemplate.STYLE_PREFIX, Names.of(def)])]
	var power := UiText.t("faith.points") % [Glossary.faith(str(points)), (" / " + Glossary.faith(str(next))) if next >= 0 else UiText.t("faith.max_rank")]
	return "%s　　%s\n[font_size=%d][color=%stip_meta]%s[/color][/font_size]" % [name, right, POWER_SIZE, TextTemplate.STYLE_PREFIX, power]


## 257 神赐：只有 perks，一阶一组、一条一行；左列阶号（到了 `@faith`，没到整组 `@dim`），右列句子（[method Glossary.bonus_numbers]：
## 加成的数金、条件的数不染）。没到的阶照 188 补充一仍写句子，随信力的数按 max(现在的信力, 那一级的阈值) 写
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
	var rows: Array = []
	for lv in order:
		var lines: Array = by_tier[lv]
		for i in lines.size():
			var lv_cell := ""
			if i == 0:
				lv_cell = _lv_meta(lv, tier >= lv)
			rows.append([lv_cell, _fg(Glossary.bonus_numbers(String(lines[i]))) if tier >= lv else _dim(String(lines[i]))])
	if rows.is_empty():
		return ""
	return _meta(UiText.t("faith.perks")) + "\n" + Glossary.columns(rows, [LV_COL, Glossary.TIP_WIDTH - LV_COL - Glossary.COL_SLACK] as Array[int], false)


## 257 赐福之物：193 的道具按阶加成单列一段，一件道具一组 —— 名字行（名左、生效阶右 `@faith`；各条阶不同就写在每条右边）+ 每条加成缩进一行；
## 按信力算份数的接「每 N 信力一份」（N 信力 `@faith`）。阶没到的条（与名字）`@dim`。[param items] 为 null 或这位神没有归神道具返回空
static func _item_section(def: FaithDef, tier: int, items: ItemDatabase) -> String:
	var rows: Array = []
	for g in item_groups(def, items):
		var tiers: Array = g["tiers"]
		var mixed := tiers.any(func(x) -> bool: return int(x) != int(tiers[0]))
		var lit := tier >= int(g["tier"])
		rows.append([_fg(String(g["name"])) if lit else _dim(String(g["name"])), "" if mixed else _lv_meta(int(g["tier"]), lit)])
		var lines: Array = g["lines"]
		for i in lines.size():
			var line_lit := tier >= int(tiers[i])
			rows.append(["[indent]%s[/indent]" % (_fg(Glossary.bonus_numbers(String(lines[i]))) if line_lit else _dim(String(lines[i]))), _lv_meta(int(tiers[i]), line_lit) if mixed else ""])
	if rows.is_empty():
		return ""
	return _meta(UiText.t("faith.items")) + "\n" + Glossary.columns(rows, [Glossary.TIP_WIDTH - ITEM_LV_COL - Glossary.COL_SLACK, ITEM_LV_COL] as Array[int])


## 神赐左列 / 赐福之物右列的「Lv.n」：到了信力色，没到灰
static func _lv_meta(lv: int, lit: bool) -> String:
	var text := "Lv.%d" % lv
	return _meta(Glossary.faith(text)) if lit else _dim("[font_size=%d]%s[/font_size]" % [META_SIZE, text])


## 257：[method _item_section] 的分组：`[{name, tier: 最低阶, lines: [效果（按信力的接条件）…], tiers: [各条的阶]}]`，
## 一件道具一组（各条阶不同就每条右边写阶），组按最低阶、同阶按道具 id；赐福版合成「赐福的道具」一组，同一句只列一次
static func item_groups(def: FaithDef, items: ItemDatabase) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null or items == null:
		return out
	var ids := items.ids_where(func(d: ItemDef) -> bool: return d.faith_tag() == def.tag() and not d.faith_bonuses.is_empty())
	Ids.sort(ids)
	var at := {}     # 名字 → out 里第几组
	for id in ids:
		var item := items.get_def(id)
		var name := blessed_name() if item.is_blessed() else Names.of(item)
		for fb in item.faith_bonuses:
			var b := fb as FaithBonus
			if b == null:
				continue
			var line := b.effect_text().strip_edges()
			if b.mode == "scaled":
				var gate := b.gate_text()
				line += UiText.t("faith.share") % (gate.left(1).to_lower() + gate.substr(1) if UiText.lang == "en" else gate)
			if not at.has(name):
				at[name] = out.size()
				out.append({"name": name, "tier": b.list_tier(), "lines": [], "tiers": []})
			var g: Dictionary = out[int(at[name])]
			if not (g["lines"] as Array).has(line):
				(g["lines"] as Array).append(line)
				(g["tiers"] as Array).append(b.list_tier())
				g["tier"] = mini(int(g["tier"]), b.list_tier())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["tier"]) < int(b["tier"]))
	return out


## 257 信力来源：两列「事 → 所得」（[method FaithDeed.parts]；所得 `@faith`），段末接包内转化（[method convert_parts]）
static func _source_section(def: FaithDef, tier: int) -> String:
	var rows: Array = []
	for d in def.deeds:
		if d == null:
			continue
		for pair in (d as FaithDeed).parts():
			rows.append([_fg(String(pair[0])), Glossary.faith(String(pair[1])) if String(pair[1]) != "" else ""])
	var conv := convert_parts(def, tier)
	if not conv.is_empty():
		rows.append([_fg(conv[0]), Glossary.faith(conv[1])])
	if rows.is_empty():
		return ""
	return _meta(UiText.t("faith.sources")) + "\n" + Glossary.columns(rows, Glossary.two_widths(rows))


## 193：这位神的道具（带 `faith:<id>` 标签、有 [member ItemDef.faith_bonuses]）的按阶加成，按 [method FaithBonus.list_tier] 归级：
## `{级: [「道具名：效果」…]}`。独有的道具写自己的名字；赐福版（[method ItemDef.is_blessed]）同一句合成一行「赐福的道具：…」。
## 按信力算份数的在句尾括号里写生效条件。[param items] 为 null 返回空
static func item_lines(def: FaithDef, items: ItemDatabase) -> Dictionary:
	var out := {}
	if def == null or items == null:
		return out
	var ids := items.ids_where(func(d: ItemDef) -> bool: return d.faith_tag() == def.tag() and not d.faith_bonuses.is_empty())
	Ids.sort(ids)
	var seen := {}
	for id in ids:
		var item := items.get_def(id)
		var name := blessed_name() if item.is_blessed() else Names.of(item)
		for fb in item.faith_bonuses:
			var b := fb as FaithBonus
			if b == null:
				continue
			var line := UiText.t("faith.item_line") % [name, b.effect_text()]
			if b.mode == "scaled":
				line += UiText.t("faith.gate") % b.gate_text()
			var lv := b.list_tier()
			if seen.has(str(lv) + line):
				continue
			seen[str(lv) + line] = true
			if not out.has(lv):
				out[lv] = []
			(out[lv] as Array).append(line)
	return out


## 193：信力来源段末的包内转化一句（按现在的阶算概率）；这位神没有赐福模板或概率为 0 返回空
static func convert_line(def: FaithDef, tier: int) -> String:
	var parts := convert_parts(def, tier)
	return UiText.t("faith.convert") % parts[2] if not parts.is_empty() else ""


## 257：转化一句拆成两列 [什么时候, 所得, 百分数]；没有返回空
static func convert_parts(def: FaithDef, tier: int) -> Array[String]:
	if def == null or def.blessings.is_empty():
		return [] as Array[String]
	var chance := def.convert_chance + def.convert_per_tier * float(maxi(0, tier))
	if chance <= 0.0:
		return [] as Array[String]
	var pct := String.num(chance * 100.0, 1).trim_suffix(".0")
	return [UiText.t("faith.convert_when"), UiText.t("faith.convert_gain") % pct, pct] as Array[String]


## 献祭：每条规矩的图标都在 → 一行图标（193：不写名字；同一条规矩的图标间一个半角空格，规矩之间两个全角空格），
## 257 起排成两行的表、图标下写倍率；有一枚缺图就整段退回文字
static func _offer_section(def: FaithDef) -> String:
	var rules: Array[OfferingRule] = []
	for r in def.offerings:
		if r != null:
			rules.append(r as OfferingRule)
	if rules.is_empty():
		return ""
	var groups: Array[String] = []
	var mults: Array[String] = []
	var all_art := true
	for r in rules:
		var icons := icon_paths(r)
		if icons.is_empty():
			all_art = false
			break
		var imgs: Array[String] = []
		for path in icons:
			imgs.append("[img=%d]%s[/img]" % [ICON_SIZE, path])
		groups.append(" ".join(imgs))
		mults.append(Glossary.faith(UiText.t("faith.offer_mult") % TextTemplate.num(r.multiplier)))
	if all_art:     # 257：一条规矩一列，图标下写倍率（信力色），列间仍隔两个全角空格
		var gap := "[font_size=%d]　　[/font_size]" % OFFER_GAP_SIZE
		var cells := ""
		for row in [groups, mults]:
			for i in row.size():
				cells += "[cell][center]%s[/center][/cell]" % row[i]
				if i < row.size() - 1:
					cells += "[cell]%s[/cell]" % gap
		return _meta(UiText.t("faith.offering")) + "\n" + "[table=%d]%s[/table]" % [groups.size() * 2 - 1, cells]
	var lines: Array[String] = []
	for r in rules:
		lines.append(_fg(Glossary.faith_numbers(r.describe())))
	return _section(UiText.t("faith.offering"), lines)


## 一条献祭规矩的图标（标签各一枚、体积 / 属性条件一枚）；有一枚没有图就返回空
static func icon_paths(r: OfferingRule) -> Array[String]:
	var out: Array[String] = []
	for t in r.tags:
		var path := TagRegistry.icon_path(t)     # 193：按标签的 icon 字段（空 = id）
		if path == "":
			return [] as Array[String]
		out.append(path)
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
