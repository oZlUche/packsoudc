## 信仰的悬浮说明（087，作者定：鼠标停在「信仰：X」上时显示具体效果与信力怎么涨）。
##
## 纯文字（BBCode）：神与说明、**信力怎么涨**（[FaithDef.deeds] 各一句）、阈值与现在几阶、这个信仰的道具各阶解锁什么
## （从道具库里按 `faith:<id>` 标签找，[ItemDef.faith_bonuses] 的 note / 修饰）。画是 [HoverTip] 的事
class_name FaithTooltip
extends RefCounted


## [param power] 可为 null（只写定义）；[param items] 可为 null（不列道具）
static func describe(def: FaithDef, power: FaithPower = null, items: ItemDatabase = null) -> String:
	if def == null:
		return "[b]没有信仰[/b]\n棋盘上放一件带信仰标签的道具就激活它的信仰；最后放进去的那件说了算。"
	var lines: Array[String] = []
	lines.append("[b]%s[/b]%s" % [Names.of(def), ("　" + def.god) if def.god != "" and def.god != def.display_name else ""])
	if def.description != "":
		lines.append("[color=#8b93a1]%s[/color]" % def.description)
	# 信力怎么涨
	var deeds := def.deeds_summary()
	lines.append("[color=#f0ad4e]信力怎么涨：[/color]%s" % (deeds if deeds != "" else "（没有配行为）"))
	# 阈值与现在
	var ths: Array[String] = []
	for th in def.thresholds:
		ths.append(str(th))
	var now_line := "阈值：%s" % ("、".join(ths) if not ths.is_empty() else "无")
	if power != null:
		var p := power.points_of(def.id)
		var tier := def.tier_of(p)
		var next := def.next_threshold(p)
		now_line += "　现在 %d 点、第 %d 阶%s" % [p, tier, ("，再 %d 点到下一阶" % (next - p)) if next >= 0 else "，已满阶"]
	lines.append(now_line)
	# 093：献祭品与信仰级效果
	if not def.offerings.is_empty():
		lines.append("[color=#f0ad4e]献祭品（神坛）：[/color]%s" % def.offerings_summary())
	if not def.perks.is_empty():
		var tier_now := def.tier_of(power.points_of(def.id)) if power != null else -1
		lines.append("[color=#f0ad4e]各级效果：[/color]")
		for pk in def.perks:
			var perk := pk as FaithPerk
			if perk == null:
				continue
			var on := tier_now >= perk.tier
			lines.append("　%sLv.%d　%s%s" % ["[color=#5cb85c]" if on else "[color=#8b93a1]", perk.tier, perk.describe(), "[/color]"])
	# 这个信仰的道具各阶解锁什么
	if items != null:
		var ids: Array = items.ids()
		ids.sort()
		var any := false
		for id in ids:
			var d := items.get_def(id)
			if d == null or d.faith_tag() != def.tag():
				continue
			if not any:
				lines.append("[color=#f0ad4e]这个信仰的道具：[/color]")
				any = true
			var bits: Array[String] = []
			for fb in d.faith_bonuses:
				var b := fb as FaithBonus
				if b == null:
					continue
				var what := b.note if b.note != "" else Glossary.mods_text(b.mods)
				bits.append("第 %d 阶 %s" % [b.tier, what])
			lines.append("　%s%s" % [Names.of(d), ("：" + "；".join(bits)) if not bits.is_empty() else "（没有按阶解锁的功能）"])
	lines.append("[color=#8b93a1]别的信仰的道具休眠：只留通用效果（盾的减伤、武器的攻击力），护符彻底失效。切换 = 把道具挪到暂存区再挪回[/color]")
	return "\n".join(lines)
