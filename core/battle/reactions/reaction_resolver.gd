## 元素印与反应（175 第一批，架构文档 4.6）。
##
## 五种元素：火、冰、雷、毒、血（和伤害类型同名）。**印就是状态**：火 / 冰 / 雷各有一个轻状态（灼 / 寒 / 麻，
## [member BuffDef.element] 指明是哪种元素），毒与血的印就是中毒 / 剧毒 / 流血本身。印从两条路来：
## [codeblock]
## 命中    伤害管线第 5 步之后（[DamageResolver]）：这种伤害类型有 [member DamageTypeDef.mark] 就盖那个印
## 施加    [method ApplyStatus.give] 加上了层数、而那个状态本身是印（施加中毒 = 盖毒印）
## [endcodeblock]
## 目标身上已经带着甲元素的印、这一下带来乙元素 → 查反应表（[ReactionDef]）结算一次。**同元素再碰只是加深**（印照常再盖：
## 灼 / 寒 / 麻刷新时长，中毒 / 流血加层），不反应。身上同时带着几种印时按 [constant ELEMENTS] 的顺序取第一个能和来者反应的。
##
## 结算：记下两边可叠层的印共几层（效果的 per_stack 读它）→ 按 [member ReactionDef.consume] 吃掉印 → 发一条
## `effect_resolved {effect: reaction}`（回放弹字、百科点亮）→ 以**攻击方**（挨打那一方的对手）为主人跑效果。
## 命中带来的那个印：被吃掉就不盖；不吃（凝毒、电解里的毒）就在效果之后补盖上。
##
## **反应不连锁**：结算期间 [member BattleContext.reacting] > 0 —— 这期间的伤害不盖印、施加的状态照常上身但不再引发反应。
## 规则层一行不加：印是伤害类型与状态的副产品，元素从哪儿来（法杖的晶石、附加的火箭、附魔、投掷弹）都一样
class_name ReactionResolver
extends RefCounted

## 元素，也是同时带着几种印时取哪一个的顺序
const ELEMENTS: Array[StringName] = [&"fire", &"ice", &"lightning", &"poison", &"bleed"]
## 元素的单字名（悬浮窗、对阵屏的小图标）
const ELEMENT_NAMES := {
	&"fire": {"zh": "火", "en": "Fire"}, &"ice": {"zh": "冰", "en": "Ice"}, &"lightning": {"zh": "雷", "en": "Volt"},
	&"poison": {"zh": "毒", "en": "Toxin"}, &"bleed": {"zh": "血", "en": "Blood"},
}
const REASON := "reaction"
## 回放事件 `effect_resolved` 的 effect 名
const EFFECT := "reaction"

## 两种元素拼成的键 → [ReactionDef]
static var _defs: Dictionary = {}
static var _loaded: bool = false
## 测试注入的 buff（id → [BuffDef]），先查它再查内容库
static var _buffs: Dictionary = {}


#region 反应表
static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for res in ContentPaths.load_resources(ContentPaths.REACTIONS):
		if res is ReactionDef:
			register(res as ReactionDef)


## 两种元素的键：按 [constant ELEMENTS] 的顺序拼（`fire_poison`）。也是反应 json 的文件名与 id
static func pair_key(a: StringName, b: StringName) -> String:
	var ia := ELEMENTS.find(a)
	var ib := ELEMENTS.find(b)
	if ia < 0 or ib < 0 or ia == ib:
		return ""
	return "%s_%s" % [ELEMENTS[mini(ia, ib)], ELEMENTS[maxi(ia, ib)]]


## 登记一种反应（同一对元素后登记的覆盖先登记的）。元素不是两种认得的就不收
static func register(def: ReactionDef) -> bool:
	if def == null or def.elements.size() != 2:
		return false
	var key := pair_key(def.elements[0], def.elements[1])
	if key == "":
		return false
	_defs[key] = def
	return true


static func find(a: StringName, b: StringName) -> ReactionDef:
	_ensure()
	return _defs.get(pair_key(a, b), null)


static func by_id(id: StringName) -> ReactionDef:
	_ensure()
	for def in _defs.values():
		if (def as ReactionDef).id == id:
			return def
	return null


## 全部反应，按元素顺序排（火毒、火冰……百科与悬浮窗都按这个顺序）
static func all() -> Array[ReactionDef]:
	_ensure()
	var keys: Array = _defs.keys()
	keys.sort_custom(func(a, b) -> bool: return _order_of(String(a)) < _order_of(String(b)))
	var out: Array[ReactionDef] = []
	for k in keys:
		out.append(_defs[k])
	return out


static func _order_of(key: String) -> int:
	var parts := key.split("_")
	return ELEMENTS.find(StringName(parts[0])) * 10 + ELEMENTS.find(StringName(parts[1]))


## 仅供测试：清空，下次用时重读数据；[param keep_data] 为假则不再读数据（只用测试登记的）
static func reset(keep_data: bool = true) -> void:
	_defs.clear()
	_buffs.clear()
	_loaded = not keep_data


## 仅供测试：让 [method mark_buff] 认得一个不在内容库里的 buff
static func register_buff(def: BuffDef) -> void:
	if def != null:
		_buffs[def.id] = def
#endregion


#region 元素
static func is_element(e: StringName) -> bool:
	return ELEMENTS.has(e)


static func element_name(e: StringName, lang: String = "") -> String:
	var n: Dictionary = ELEMENT_NAMES.get(e, {})
	if n.is_empty():
		return String(e)
	var l := lang if lang != "" else UiText.lang
	return String(n.get(l, n["zh"]))


## 一个印的定义（伤害类型的 mark 指的那个 buff）
static func mark_buff(id: StringName) -> BuffDef:
	if id == &"":
		return null
	if _buffs.has(id):
		return _buffs[id]
	return ContentLibrary.buffs().get(id, null)


## 一种伤害类型带的元素（它盖的印是哪种元素的）；不盖印的空
static func element_of_type(type: StringName) -> StringName:
	if type == &"" or not DamageTypes.has(type):
		return &""
	var mark := mark_buff(DamageTypes.get_def(type).mark)
	return mark.element if mark != null else &""


## [param who] 身上有没有 [param e] 元素的印
static func has_mark(who: CombatantRuntime, e: StringName) -> bool:
	for b in who.buffs:
		if b.def.element == e and b.stacks > 0:
			return true
	return false


## [param who] 身上 [param e] 元素的**可叠层**印共几层（中毒 + 剧毒；灼 / 寒 / 麻是不可叠的标记，不算层）
static func mark_stacks(who: CombatantRuntime, e: StringName) -> int:
	var n := 0
	for b in who.buffs:
		if b.def.element == e and b.def.is_stackable():
			n += b.stacks
	return n


## 一组规则会带来哪些元素（悬浮窗的「可引发」、对阵屏的元素图标）：造成的伤害类型、改成的伤害类型、施加 / 转成的状态、附火。按元素顺序
static func elements_of_rules(rules: Array) -> Array[StringName]:
	var found := {}
	for r in rules:
		var rule := r as AbilityRule
		if rule == null:
			continue
		for e in rule.effects:
			for el in _elements_of_effect(e):
				found[el] = true
	var out: Array[StringName] = []
	for el in ELEMENTS:
		if found.has(el):
			out.append(el)
	return out


static func _elements_of_effect(e) -> Array[StringName]:
	var out: Array[StringName] = []
	var el := &""
	if e is DealDamage:
		el = element_of_type((e as DealDamage).damage_type)
	elif e is ConvertDamageType:
		el = element_of_type((e as ConvertDamageType).to)
	elif e is FireEnchant:
		el = element_of_type(DamageTypes.FIRE)
	elif e is ApplyStatus and (e as ApplyStatus).buff != null:
		el = (e as ApplyStatus).buff.element
	elif e is ConvertStatus and (e as ConvertStatus).to != null:
		el = (e as ConvertStatus).to.element
	if el != &"":
		out.append(el)
	return out


## 一件道具（编译后，含别人挂上来的规则）带的元素
static func elements_of_item(item: CompiledItem) -> Array[StringName]:
	if item == null:
		return [] as Array[StringName]
	var out := elements_of_rules(item.rules)
	if item.loaded.is_empty():
		return out
	var found := {}     # 175 第二批：轮读的法杖，元素来自轮读表里的晶石
	for el in out:
		found[el] = true
	for e in item.loaded:
		var el := element_of_type(StringName(e.get("type", &"")))
		if el != &"":
			found[el] = true
	var merged: Array[StringName] = []
	for el in ELEMENTS:
		if found.has(el):
			merged.append(el)
	return merged


## 甲方元素 × 乙方元素能引发的反应（不同元素、表里有的），按反应表的顺序，不重复
static func reactions_between(mine: Array, others: Array) -> Array[ReactionDef]:
	var out: Array[ReactionDef] = []
	for def in all():
		for a in mine:
			for b in others:
				if a != b and def.has_element(a) and def.has_element(b) and not out.has(def):
					out.append(def)
	return out
#endregion


#region 结算
## 伤害管线第 5 步之后：这一下带的印 —— 能反应就反应（印不盖），否则盖上（同元素就是加深）
static func after_hit(ctx: BattleContext, packet: DamagePacket, td: DamageTypeDef) -> void:
	var victim := packet.victim
	if ctx == null or victim == null or victim.dead or ctx.reacting > 0:
		return
	var mark := mark_buff(td.mark)
	if mark == null:
		return
	if mark.element != &"" and _react(ctx, victim, mark.element, packet.source_uid, mark, false):
		return
	_stamp(ctx, victim, mark)


## [method ApplyStatus.give] 加上了层数、那个状态本身是印：来者已经在身上了，看要不要反应
static func after_status(ctx: BattleContext, victim: CombatantRuntime, def: BuffDef) -> void:
	if ctx == null or victim == null or victim.dead or ctx.reacting > 0 or def.element == &"":
		return
	_react(ctx, victim, def.element, 0, def, true)


## 找一个能和来者反应的印并结算。返回反应了没有
static func _react(ctx: BattleContext, victim: CombatantRuntime, incoming: StringName, uid: int, incoming_def: BuffDef, applied: bool) -> bool:
	for present in ELEMENTS:
		if present == incoming or not has_mark(victim, present):
			continue
		var def := find(present, incoming)
		if def == null:
			continue
		_resolve(ctx, victim, def, present, incoming, uid, incoming_def, applied)
		return true
	return false


static func _resolve(ctx: BattleContext, victim: CombatantRuntime, def: ReactionDef, present: StringName, incoming: StringName,
		uid: int, incoming_def: BuffDef, applied: bool) -> void:
	ctx.reacting += 1
	var owner := ctx.opponent_of(victim)
	var rc := RuleContext.create(ctx, owner, RuleRuntime.create(null, 0, null, owner.side))
	var stacks := mark_stacks(victim, present) + mark_stacks(victim, incoming)
	if not applied and incoming_def != null and incoming_def.is_stackable():
		stacks += 1     # 命中带来的可叠层印（没盖上去）也算一层
	rc.reaction_stacks = stacks
	for el in [present, incoming]:
		if def.consumes(el):
			_consume(rc, victim, el)
	if ctx.trace != null:
		ctx.trace.record(ctx.now, victim.side, BattleTrace.EVENT, {"name": "reaction", "payload": {
			"reaction": String(def.id), "present": String(present), "incoming": String(incoming), "stacks": stacks}})
	ctx.emit(BattleEvent.EFFECT_RESOLVED, victim.side, {
		"effect": EFFECT, "reaction": String(def.id), "uid": 0, "from_uid": uid, "source_side": owner.side,
		"elements": [String(present), String(incoming)], "stacks": stacks,
	})
	for e in def.effects:
		if e != null:
			(e as Effect).apply(rc)
	# 命中带来的印没被吃掉（凝毒的寒、电解里的毒）：效果之后补盖上
	if not applied and incoming_def != null and not def.consumes(incoming) and not victim.dead:
		_stamp(ctx, victim, incoming_def)
	ctx.reacting -= 1


## 吃掉 [param who] 身上 [param e] 元素的全部印（被锁住的吃不掉，凝毒）
static func _consume(rc: RuleContext, who: CombatantRuntime, e: StringName) -> void:
	var ids: Array[StringName] = []
	for b in who.buffs:
		if b.def.element == e:
			ids.append(b.def.id)
	for id in ids:
		RemoveStatus.take(rc, who, id, who.stacks_of(id), REASON)


## 盖一个印（施加方 = 挨打那一方的对手）。走 [method ApplyStatus.give]：发 status_stacked / status_applied，同元素就是刷新 / 加层
static func _stamp(ctx: BattleContext, victim: CombatantRuntime, mark: BuffDef) -> void:
	var owner := ctx.opponent_of(victim)
	var rc := RuleContext.create(ctx, owner, RuleRuntime.create(null, 0, null, owner.side))
	ctx.reacting += 1     # 已经判过反应了：这一盖不再引发
	ApplyStatus.give(rc, victim, mark, 1)
	ctx.reacting -= 1
#endregion


#region 回放与记账
## 一场里引发过的反应 id（按第一次出现的顺序，不重复）。百科点亮、测试用
static func reactions_in(log: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for e in log:
		var ev := e as BattleEvent
		if ev != null and ev.name == BattleEvent.EFFECT_RESOLVED and String(ev.payload.get("effect", "")) == EFFECT:
			var id := ev.get_name(&"reaction")
			if not out.has(id):
				out.append(id)
	return out
#endregion
