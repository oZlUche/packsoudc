## 增益 / 受益 / 装载句（171 §3，作者定）：三段都从字段来 —— 条件（标签）+ 效果名（属性的句式名 / buff 的解说或名字）+ 数值。
##
## 目标格式：「武器增伤 15%」。条件：`grant_filter`（命中其一，OR）写「XX、YY」，`grant_filter_all`（全部带上，AND）连写「XXYY」，
## 都有就 AND 组在前直接接 OR 组（「武器弓、弩」）；都空写「邻居」。效果：属性修饰走 [method Glossary.mod_text] 的句式
## （乘算「增伤 15%」、加算「护甲 +5」），附加规则走 [method Glossary.rule_text]，里面提到的 buff 有专属解说就换成解说（[method BuffDef.sentence_text]）。
## 行首的图标是悬浮窗的事（[ItemTooltip]），这里只出文字
class_name AdjacencyText
extends RefCounted

const NEIGHBOUR := {"zh": "邻居", "en": "neighbours"}


## 条件那一段
static func condition(any: Array, all: Array = []) -> String:
	var a := UiText.t("tip.adj_and_sep").join(_names(all))
	var o := UiText.t("tip.adj_or_sep").join(_names(any))
	if a == "" and o == "":
		return UiText.pick(NEIGHBOUR)
	return a + o if a == "" or o == "" else a + UiText.t("tip.adj_and_sep") + o


## 效果那一段：修饰与规则，用「、」连
static func effects(mods: Array, rules: Array) -> String:
	var parts: Array[String] = []
	for m in mods:
		if m != null:
			parts.append(Glossary.mod_text(m as StatModifier, true))
	for r in rules:
		if r != null:
			parts.append(UiText.t("tip.adj_added") % rule_phrase(r as AbilityRule))
	return UiText.t("tip.list_sep").join(parts)


## 一条附加规则的一句；提到的 buff 有专属解说就写解说（171 §1）
static func rule_phrase(rule: AbilityRule) -> String:
	var text := Glossary.rule_text(rule)
	var buffs := {}
	Glossary.buffs_in_rules([rule], buffs)
	for id in buffs:
		var b: BuffDef = buffs[id]
		if b != null and b.has_blurb and b.blurb.strip_edges() != "":
			text = text.replace(Names.of(b), b.sentence_text())
	return text


## 增益句：「武器增伤 15%」；没有增益返回空
static func grant(adj: AdjacencyProfile) -> String:
	if adj == null or not adj.has_grant():
		return ""
	return UiText.t("tip.adj_grant") % [condition(adj.grant_filter, adj.grant_filter_all), effects(adj.grant_mods, adj.grant_rules)]


## 受益句：主语是自己 ——「挨着盾时 护甲 +5」；不止一个受益格写「每挨着一件盾 护甲 +5」（点亮几格得几份）
static func receive(adj: AdjacencyProfile) -> String:
	if adj == null or not adj.has_receive():
		return ""
	var who := condition(adj.receive_filter)
	var head := (UiText.t("tip.adj_next_to") % who) if adj.receive_cells.size() <= 1 else (UiText.t("tip.adj_per_next") % who)
	return "%s %s" % [head, effects(adj.receive_mods, adj.receive_rules)]


## 供给句（晶石自己的悬浮窗）：「装进法杖：伤害 +6、附加：…」
static func feed(adj: AdjacencyProfile) -> String:
	if adj == null or not adj.has_feed():
		return ""
	return UiText.t("tip.adj_feed") % [condition(adj.feed_filter) if not adj.feed_filter.is_empty() else UiText.t("tip.adj_host"), effects(adj.feed_mods, adj.feed_rules)]


## 晶石供给里把伤害转成的类型（`convert_damage_type` 的 `to`）；没有返回空
static func feed_damage_type(adj: AdjacencyProfile) -> StringName:
	if adj == null:
		return &""
	for r in adj.feed_rules:
		var rule := r as AbilityRule
		if rule == null:
			continue
		for e in rule.effects:
			if e is ConvertDamageType and (e as ConvertDamageType).to != &"":
				return (e as ConvertDamageType).to
	return &""


static func _names(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for t in tags:
		out.append(Glossary.tag_name(StringName(String(t))))
	return out
