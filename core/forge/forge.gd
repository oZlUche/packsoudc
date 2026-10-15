## 铸炉与附魔（175 第三批，作者定）：三件道具放进【时机】【效果】【数值】三个槽，各按【材质】【用途】【稀有度】查表（[ForgeTable]），
## 铸成一枚 1×1 的**铸牌**；铸牌拖到武器上就是附魔（永存，后来者覆盖前者）。所有附魔都视为铸牌附魔 ——
## 道具的 `state.enchant`（铸牌附上的）覆盖定义里预置的 [member ItemDef.enchant]。
##
## 附魔记的是**三张表里各落到哪一行**（[EnchantDef] 同构的字典），不是规则本身：规则在编译时由 [method rule_of] 现拼，
## 经 108 的附加入口（[method BattleCompiler._attach]）挂到武器上，同一把只挂一条。表里查不到了（行被删）→ 规则拼不出、
## 存档对账（[SaveReconcile]）把附魔摘掉并报告一行
class_name Forge
extends RefCounted

## 道具实例 `state` 里附魔的键（铸牌、被附魔的武器都用它）
const KEY := "enchant"
## 铸牌的价值记在实例上
const VALUE_KEY := "value"
## 175 补充二（作者定）：铸牌固定价，几乎总是亏 —— 低于任何三件材料之和
const TOKEN_VALUE := 3
## 铸牌的定义 id 与标签（不进图鉴、掉落、商店，[method ItemDatabase.ids] 按标签拦）
const TOKEN_ID := &"forge_token"
const TOKEN_TAG := &"token"
## 「每次都触发」落到不许的时机上时换成的冷却（秒）
const MIN_COOLDOWN := 1.0
## 附魔规则挂到武器上时记的来源（[member CompiledItem.attached] 的 origin）
const ORIGIN := &"enchant"
## 槽的中文名
const SLOT_NAMES := {&"timing": {"zh": "时机", "en": "Timing"}, &"effect": {"zh": "效果", "en": "Effect"}, &"value": {"zh": "数值", "en": "Value"}}

static var _tables: Dictionary = {}
static var _loaded: bool = false


#region 表
static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for res in ContentPaths.load_resources(ContentPaths.FORGE):
		if res is ForgeTable:
			register(res as ForgeTable)


## 登记一张表（测试注入；同一槽后登记的覆盖）
static func register(t: ForgeTable) -> void:
	if t != null and ForgeTable.SLOTS.has(t.id):
		_tables[t.id] = t


static func table(slot: StringName) -> ForgeTable:
	_ensure()
	return _tables.get(slot, null)


static func reset() -> void:
	_tables.clear()
	_loaded = false


static func slot_name(slot: StringName, lang: String = "") -> String:
	var n: Dictionary = SLOT_NAMES.get(slot, {})
	return Names.pick(n, String(n.get("zh", slot)), lang) if not n.is_empty() else String(slot)
#endregion


#region 铸
## 三件道具（时机、效果、数值槽各一件）铸成的附魔字典；表缺了返回空
static func forge(timing: ItemDef, effect: ItemDef, value: ItemDef) -> Dictionary:
	var t := table(&"timing")
	var e := table(&"effect")
	var v := table(&"value")
	if t == null or e == null or v == null or timing == null or effect == null or value == null:
		return {}
	var tm := t.by_material(timing)
	var tp := t.by_purpose(timing)
	var em := e.by_material(effect)
	var ep := e.by_purpose(effect)
	var vm := v.by_material(value)
	var vp := v.by_purpose(value)
	var vr := v.by_rarity(value.rarity)
	if tm == null or em == null:
		return {}
	var mag := maxi(1, roundi(em.base * (vr.size if vr != null else 1.0) * (vm.mult if vm != null else 1.0) * (vp.mult if vp != null else 1.0)))
	return {
		"trigger": String(tm.key), "direction": String(tp.key if tp != null else ForgeTable.DEFAULT), "rate": timing.rarity,
		"effect": String(em.key), "target": String(ep.key if ep != null else ForgeTable.DEFAULT), "tier": effect.rarity,
		"magnitude": mag, "element": String(_element_for(em, effect)),
		"from": [String(timing.id), String(effect.id), String(value.id)],
	}


## 晶石这类按元素盖印：这件道具自己带的元素（供给规则、战斗规则里的伤害类型），表里有的第一个；没有就表里第一个
static func _element_for(em: ForgeEntry, def: ItemDef) -> StringName:
	if em.by_element.is_empty():
		return &""
	var rules: Array = []
	if def.adjacency != null:
		rules.append_array(def.adjacency.feed_rules)
	if def.combat != null:
		rules.append_array(def.combat.rules)
	for el in ReactionResolver.elements_of_rules(rules):
		if em.by_element.has(String(el)):
			return el
	var keys: Array = em.by_element.keys()
	keys.sort()
	return StringName(String(keys[0]))


## 一枚铸牌：1×1、带附魔、价值固定 [constant TOKEN_VALUE]（补充二）。铸牌的定义没导进来返回 null
static func make_token(db: ItemDatabase, timing: ItemInstance, effect: ItemInstance, value: ItemInstance) -> ItemInstance:
	if db == null or not db.has_def(TOKEN_ID) or timing == null or effect == null or value == null:
		return null
	var ench := forge(timing.def, effect.def, value.def)
	if ench.is_empty():
		return null
	var inst := ItemInstance.create(db.get_def(TOKEN_ID))
	inst.state[KEY] = ench
	inst.state[VALUE_KEY] = TOKEN_VALUE
	return inst


static func is_token(inst: ItemInstance) -> bool:
	return inst != null and inst.def != null and inst.def.tags.has(TOKEN_TAG)


## 铸牌能附给它吗（待定 7 A：只武器）
static func accepts(inst: ItemInstance) -> bool:
	return inst != null and inst.def != null and inst.def.tags.has(&"weapon") and not is_token(inst)
#endregion


#region 读附魔
## 这件道具身上的附魔（实例的覆盖定义预置的；没有 = 空）。铸牌自己的那份也从这里读
static func enchant_of(inst: ItemInstance) -> Dictionary:
	if inst == null:
		return {}
	var own: Variant = inst.state.get(KEY, null)
	if own is Dictionary and not (own as Dictionary).is_empty():
		return own
	if inst.def != null and inst.def.enchant != null:
		return inst.def.enchant.to_dict()
	return {}


## 附魔哪里坏了（表里查不到的行）；好的返回空串
static func problem(ench: Dictionary) -> String:
	if ench.is_empty():
		return "空的附魔"
	var t := table(&"timing")
	var e := table(&"effect")
	if t == null or e == null:
		return "铸炉映射表没导入"
	if ForgeTable.find(t.material, StringName(String(ench.get("trigger", "")))) == null:
		return "时机表里没有「%s」" % ench.get("trigger", "")
	if ForgeTable.find(e.material, StringName(String(ench.get("effect", "")))) == null:
		return "效果表里没有「%s」" % ench.get("effect", "")
	return ""


## 拼成一条规则（以宿主身份跑，108）；坏了返回 null
static func rule_of(ench: Dictionary) -> AbilityRule:
	if problem(ench) != "":
		return null
	var t := table(&"timing")
	var e := table(&"effect")
	var tm := ForgeTable.find(t.material, StringName(String(ench["trigger"])))
	var tp := ForgeTable.find(t.purpose, StringName(String(ench.get("direction", ForgeTable.DEFAULT))))
	var tr := t.by_rarity(int(ench.get("rate", 0)))
	var em := ForgeTable.find(e.material, StringName(String(ench["effect"])))
	var ep := ForgeTable.find(e.purpose, StringName(String(ench.get("target", ForgeTable.DEFAULT))))
	var er := e.by_rarity(int(ench.get("tier", 0)))
	if tm.trigger == null or em.effect == null:
		return null
	var rule := AbilityRule.new()
	rule.trigger = tm.trigger.duplicate(true) as Trigger
	if tp != null:
		_set_props(rule.trigger, tp.trigger_props)
	if rule.trigger is OnItemFired:     # 附魔的「出手时」= 这把武器自己出手（编译挂上时 108 入口也会再绑一次宿主）
		(rule.trigger as OnItemFired).self_only = true
	var cad: Cadence = tm.fixed_cadence if tm.fixed_cadence != null else (tr.cadence if tr != null else null)
	rule.cadence = (cad.duplicate(true) if cad != null else Always.new()) as Cadence
	# 每次都触发只许给「宿主出手时」「开战时」：别的时机（受伤、造成伤害、施加状态、按节拍）每次都触发会自己点燃自己
	if rule.cadence is Always and not (rule.trigger is OnItemFired or rule.trigger is OnBattleStart):
		var cd := CooldownCadence.new()
		cd.seconds = MIN_COOLDOWN
		rule.cadence = cd
	var tier := er.tier if er != null else 0
	var main := (em.upgraded if tier >= 1 and em.upgraded != null else em.effect).duplicate(true) as CombatEffect
	_shape_effect(main, em, ep, ench)
	rule.effects.append(main)
	if tier >= 2 and em.bonus != null:
		var extra := em.bonus.duplicate(true) as CombatEffect
		if not em.self_only and ep != null and ep.target >= 0 and "target" in extra:
			extra.set("target", ep.target)
		rule.effects.append(extra)
	return rule


## 数值、给谁、按元素换的印
static func _shape_effect(eff: CombatEffect, em: ForgeEntry, ep: ForgeEntry, ench: Dictionary) -> void:
	var mag := maxi(1, int(ench.get("magnitude", 1)))
	if em.amount_field in eff:
		var cur: Variant = eff.get(em.amount_field)
		eff.set(em.amount_field, float(mag) if cur is float else mag)
	if not em.self_only and ep != null and ep.target >= 0 and "target" in eff:
		eff.set("target", ep.target)
	var el := String(ench.get("element", ""))
	if el == "" or not em.by_element.has(el):
		return
	var row: Dictionary = em.by_element[el]
	for k in row:
		var key := String(k)
		if key == "prefix" or key == "prefixes" or not (key in eff):
			continue
		if key == "buff":
			var b: BuffDef = ContentLibrary.buffs().get(StringName(String(row[k])), null)
			if b != null:
				eff.set(key, b)
		elif typeof(eff.get(key)) == TYPE_STRING_NAME:
			eff.set(key, StringName(String(row[k])))
		else:
			eff.set(key, row[k])


## 用途给扳机写的几项：扳机有这一项才写；枚举可以写名字（"DEALT"）
static func _set_props(obj: Object, props: Dictionary) -> void:
	for k in props:
		var key := String(k)
		if not (key in obj):
			continue
		var v: Variant = props[k]
		if v is String and typeof(obj.get(key)) == TYPE_INT:
			v = _enum_value(obj, String(v))
			if v == null:
				continue
		obj.set(key, v)


static func _enum_value(obj: Object, name: String) -> Variant:
	var script: Script = obj.get_script()
	while script != null:
		for c in script.get_script_constant_map().values():
			if c is Dictionary and (c as Dictionary).has(name):
				return int((c as Dictionary)[name])
		script = script.get_base_script()
	return null


## 附魔前缀（「嗜血的」）：按元素换印的用元素那一行的前缀
static func prefix(ench: Dictionary, lang: String = "") -> String:
	var e := table(&"effect")
	if e == null or ench.is_empty():
		return ""
	var em := ForgeTable.find(e.material, StringName(String(ench.get("effect", ""))))
	if em == null:
		return ""
	var el := String(ench.get("element", ""))
	if el != "" and em.by_element.has(el):
		var row: Dictionary = em.by_element[el]
		var by_lang: Dictionary = row.get("prefixes", {})
		return Names.pick(by_lang, String(row.get("prefix", em.prefix)), lang)
	return Names.pick(em.prefixes, em.prefix, lang)


## 附魔的那一句（171 的句子生成）：「出手时 对手施加 2 层流血」
static func sentence(ench: Dictionary) -> String:
	var rule := rule_of(ench)
	return AdjacencyText.rule_phrase(rule) if rule != null else ""
#endregion
