## 词条表（087，作者定）：道具说明里指向特定名词 / 关键词的地方（「护符结界」「自发」「中毒」「血怒」……），
## 每个关键词有一段具体效果 —— 主文字只写名词，不写「伤害 +10%」这种细节。170：关键词带下划线，悬浮窗钉住后停上去开子窗（原来的侧边小窗取消）。
##
## 两类词条：**固定词条**（[constant TERMS]：时机、属性、机制的通用解释）与 **buff 词条**（从道具的规则里收集到的 [BuffDef]，
## 说明由 [method describe_buff] 按定义生成 —— 数据改了文字跟着改，不用手写）。
## 这一层只产出**数据**（`[{name, text, id}]`）与标了关键词的 BBCode；怎么画是 [HoverTip] 的事
class_name Glossary
extends RefCounted

## 关键词在主文字里的颜色（下划线 + 这个色，一眼看出「这个词有解释」）
const TERM_COLOR := Color("c9a0ff")

## 固定词条：关键词 → `{text: 解释, tip: 要不要弹词条}`。键就是主文字里出现的原词。
##
## 107（作者定）：**能直观理解的词不弹** —— 弹窗留给带玩家猜不到的规则的词。
## `tip: false` 的词不进侧窗、主文字里也不标色（标了色玩家就会去找解释，找不到比没有更糟），
## 但**说明文字一字不动**：编辑器的词典、文档、将来的帮助页照用。没写 `tip` 按 true，取文字一律走 [method term_text]
const TERMS := {
	# 107：时机词与直白的资源词，字面就是意思，不弹
	"自发": {"text": "不等任何事件，按自己的冷却周期反复出手 —— 武器的普通攻击都是自发的。", "tip": false},
	"开战时": {"text": "战斗开始那一瞬触发一次。", "tip": false},
	"出手时": {"text": "有道具出手时跟着触发（连带）。", "tip": false},
	"受伤时": {"text": "受到伤害之后触发。", "tip": false},
	"层数够时": {"text": "身上某个状态叠到指定层数时触发。", "tip": false},
	# 130
	"施加时": {"text": "某个状态被施加、层数增加的那一瞬触发；叠满后只刷新时长的那一下不算。默认只认自己施加的。", "tip": false},
	"资源低于时": {"text": "生命 / 耐力等降到阈值以下时触发。", "tip": false},
	"冷却": {"text": "两次出手之间的间隔（秒），急速会缩短它。", "tip": false},
	"耐力": {"text": "出手要花的资源，每秒按回复速度补回；不够就出不了手，等回够再动。", "tip": false},
	"耗耐力": {"text": "这一下出手要花的耐力。", "tip": false},
	"信力": {"text": "按信仰要求的行为攒的点数；过了阈值，这个信仰的道具解锁更多功能。", "tip": false},
	# 129：负重
	"负重": {"text": "作战棋盘上所有东西（包本身也算）的重量之和；地上、保险箱、仓库里的不算。超过角色的负重上限就开始吃力。"},
	"吃力": {"text": "负重超过上限：急速 −10%、耐力回复 −10%。"},
	"超重": {"text": "负重超过上限的 1.25 倍：急速 −25%、耐力回复 −25%、耐力上限 −20%。"},
	"寸步难行": {"text": "负重超过上限的 1.5 倍：超重的减益照旧，地图上每走一步（传送也算）花双倍行动点；原地等待不翻倍。"},
	"地上": {"text": "棋盘之外的整块屏幕（128，原「暂存区」）：拖出棋盘放哪就落在哪。不参战、不吃邻接、不算套装、撤离不带走；留在这个点上，回来还在原处。", "tip": false},
	# 以下都带玩家猜不到的规则（换算、结算顺序、叠层方式），照弹
	"急速": {"text": "出手速度的倍率，越高冷却越短。"},
	# 153（作者定）：防护改名格挡，只有盾牌给，几面盾只算最高的一面
	"格挡": {"text": "只有盾牌给格挡。每次受到**直接伤害**（武器造成的）固定减少这个数，减到零为止；带几面盾只算最高的一面，加固 / 破绽在它之上加减，破绽为负时反而多挨。buff 造成的灼烧、中毒、流血不算直接伤害，格挡挡不住。"},
	"护甲": {"text": "先于生命被扣的一层。开战时按护甲上限充满，之后不自己回复。中毒、流血无视护甲。"},
	"直接伤害": {"text": "武器造成的伤害。格挡（加固 / 破绽）只减它；buff 造成的伤害（灼烧、中毒、流血）不是直接伤害。"},
	"永续": {"text": "不会过期，一直到战斗结束（除非被清除）。"},
	"叠层": {"text": "同一个状态可以叠多层，效果按层数累加；没写上限就不限层。"},
	"合成": {"text": "把一件道具拖到另一件上面，两件有配方就立刻合成一件新的；装不下就到地上。"},
	"增益槽": {"text": "这件道具的一种格位：邻居占着它，邻居就得到写着的加成。"},
	"受益槽": {"text": "这件道具的一种格位：每被邻居点亮一格，自己就得一份写着的加成。"},
	"装载槽": {"text": "法杖的晶石座（171）：放上去的魔晶石把它带的供给交给法杖。一颗晶石只给一把法杖（压着两把的给后放的那把），占了同一把的几个装载槽也只算一份。"},
	# 107（作者定）：这两条写的是**buff**（每层每秒掉血、无视格挡与护甲），不是武器的伤害类型 —— 同名的标签
	# 「中毒」「流血」指类型，那边 tip 为 false。两边文字都保留
	"中毒": {"text": "每层每秒造成毒伤，无视格挡与护甲，永续叠层。"},
	"流血": {"text": "每层每秒造成流血伤害，无视格挡与护甲，永续叠层。"},
}


## 一条固定词条的说明文字（词条不存在给空）。107：`tip` 关掉的词照样取得到文字
static func term_text(name: String) -> String:
	var entry = TERMS.get(name, null)
	if entry == null:
		return ""
	return String((entry as Dictionary).get("text", "")) if entry is Dictionary else String(entry)


## 这条固定词条要不要弹词条（107：没写按 true；词条不存在给 false）
static func term_tip(name: String) -> bool:
	var entry = TERMS.get(name, null)
	if entry == null:
		return false
	return bool((entry as Dictionary).get("tip", true)) if entry is Dictionary else true


## 标签给人看（096：名字是数据 —— [TagRegistry]，按当前语言；`faith:<id>` 写成「信仰：神名」；没登记的原词）
static func tag_name(tag: StringName) -> String:
	var fid := FaithTags.id_of_tag(tag)
	if fid != &"":
		var defs := FaithDef.load_all()
		var god: FaithDef = defs.get(fid, null)
		return "%s%s%s" % [UiText.pick(FAITH_WORD), "：" if UiText.lang == "zh" else ": ", Names.of(god) if god != null else String(fid)]
	return TagRegistry.name_of(tag)


## 标签的词条（096）：登记了说明的标签 → {名字: {"id": 标签 id, "text": 说明}}；没说明的不出。
## 107：`tip` 关掉的标签也不出 —— 名字仍在标签行里列着，只是不弹窗
static func tag_terms(tags: Array) -> Dictionary:
	var out := {}
	for t in tags:
		var d := TagRegistry.describe(t)
		if d != "" and TagRegistry.tip_of(t) and not TagRegistry.is_internal(t):
			out[tag_name(t)] = {"id": String(t), "text": d}
	return out


## 伤害类型给人看（096：数据 —— [DamageTypes.name_of]，按当前语言）
static func damage_type_name(type: StringName) -> String:
	return DamageTypes.name_of(type)


const FAITH_WORD := {"zh": "信仰", "en": "Faith"}

## 属性键 → 名字（096：中 / 英；按 [UiText.lang] 取，没有英文的回落中文 —— [method UiText.pick]）
const STAT_NAMES := {
	"damage": {"zh": "伤害", "en": "Damage"}, "block": {"zh": "格挡", "en": "Block"}, "max_hp": {"zh": "生命", "en": "Health"},
	"max_stamina": {"zh": "耐力上限", "en": "Max stamina"}, "haste": {"zh": "急速", "en": "Haste"}, "cooldown": {"zh": "冷却", "en": "Cooldown"},
	"regen_stamina": {"zh": "每秒回耐力", "en": "Stamina regen"}, "regen_hp": {"zh": "每秒回血", "en": "Health regen"}, "max_armor": {"zh": "护甲上限", "en": "Max Armor"},
	"max_mana": {"zh": "法力上限", "en": "Max mana"}, "regen_mana": {"zh": "每秒回法力", "en": "Mana regen"},
	"stamina_cost": {"zh": "耗耐力", "en": "Stamina cost"}, "mana_cost": {"zh": "耗法力", "en": "Mana cost"},
	"crit_chance": {"zh": "暴击率", "en": "Crit chance"}, "crit_damage": {"zh": "暴击伤害", "en": "Crit damage"},
	"step_cooldown": {"zh": "单次冷却", "en": "Step cooldown"}, "load_steps": {"zh": "一轮几颗", "en": "Loaded crystals"},     # 175
}


static func stat_name(key: StringName) -> String:
	return UiText.pick(STAT_NAMES.get(String(key), null), String(key))


## 171（作者定）：增益 / 受益句里属性的叫法（「武器**增伤** 10%」）。没写的用 [constant STAT_NAMES] 的名字；
## 伤害的乘算叫「增伤」，加算还是「伤害 +N」
const SENTENCE_NAMES := {
	"damage": {"zh": "增伤", "en": "damage"}, "haste": {"zh": "加速", "en": "haste"}, "max_armor": {"zh": "护甲", "en": "Armor"},
	"regen_stamina": {"zh": "回耐力", "en": "stamina regen"}, "regen_hp": {"zh": "回血", "en": "health regen"},
}


## 171：句子里属性的叫法（见 [constant SENTENCE_NAMES]）
static func sentence_name(key: StringName, mult: bool) -> String:
	if key == &"damage" and not mult:
		return stat_name(key)
	return UiText.pick(SENTENCE_NAMES.get(String(key), null), stat_name(key))


## 一条属性修饰给人看：「伤害 +10%」「格挡 +4」。
## 171：[param sentence] = 增益 / 受益句的写法 —— 乘算「增伤 10%」（基础轴的数值简单换算，正数不带加号）、加算「护甲 +5」
static func mod_text(m: StatModifier, sentence: bool = false) -> String:
	if m == null:
		return ""
	if sentence:
		var nm := sentence_name(m.stat, m.is_mult())
		if m.is_mult():
			return "%s %d%%" % [nm, roundi(m.amount)]
		if BattleStats.PERCENT_DISPLAY.has(m.stat):
			return "%s %+d%%" % [nm, roundi(m.amount * 100.0)]
		return "%s %s" % [nm, ("%+d" % roundi(m.amount)) if TextTemplate.is_whole(m.amount) else "%+.1f" % m.amount]
	if m.amount == 0.0:
		return "%s（无效果）" % stat_name(m.stat)
	if m.is_mult():     # 133：乘算「伤害 +25%」
		return "%s %+d%%" % [stat_name(m.stat), roundi(m.amount)]
	if BattleStats.PERCENT_DISPLAY.has(m.stat):
		return "%s %+d%%" % [stat_name(m.stat), roundi(m.amount * 100.0)]     # 104：暴击按百分数写
	var f := m.amount
	return "%s %s" % [stat_name(m.stat), ("%+d" % roundi(f)) if TextTemplate.is_whole(f) else "%+.1f" % f]


static func mods_text(mods: Array) -> String:
	var out: Array[String] = []
	for m in mods:
		out.append(mod_text(m as StatModifier))
	return "、".join(out)


## 一个 buff 的具体效果（侧窗的正文）：增益 / 减益、叠层、时长、每层的属性、自带的规则、上身 / 到期时的效果
static func describe_buff(def: BuffDef) -> String:
	if def == null:
		return ""
	var lines: Array[String] = []
	var kind := "减益" if def.is_debuff else "增益"
	var stacks := "不可叠层" if not def.is_stackable() else "不限层"
	var duration := def.duration_text()
	# 103：默认永续、可叠层；不可叠层与会过期是例外，用例外色标出来，作者 / 玩家一眼看出「这个不是默认」
	if not def.is_stackable():
		stacks = _exception(stacks)
	if not def.is_permanent() or def.seconds_per_stack > 0:
		duration = _exception(duration)
	lines.append("%s　%s　%s" % [kind, stacks, duration])
	if not def.axes.is_empty():     # 152：每层带的标准轴
		var parts: Array[String] = []
		for a in def.axes:
			if a != null:
				var ba := a as BuffAxis
				parts.append("【%s】%d 层（%s）" % [StatAxes.name_of(ba.axis, ba.stacks), absi(ba.stacks), StatAxes.effect_text(ba.axis, ba.stacks)])
		lines.append("每层带%s" % "、".join(parts))
	if not def.mods.is_empty():
		lines.append("%s%s" % ["每层：" if def.is_stackable() else "", mods_text(def.mods)])
	for r in def.rules:
		var rule := r as AbilityRule
		if rule != null:
			lines.append(rule_text(rule))
	if not def.on_apply.is_empty():
		lines.append("上身时：" + effects_text(def.on_apply))
	if not def.on_expire.is_empty():
		lines.append("到期时：" + effects_text(def.on_expire))
	# 175：元素印、衰减、截治疗、恢复叠层、按类型易伤
	if def.seconds_per_stack > 0:
		lines.append(_exception("每层持续 %d 秒" % def.seconds_per_stack) + "：再叠上来就延长，时间到整个消失")
	var pct := TextTemplate.num(def.per_stack_percent)
	match def.decay_halve_on:
		BuffDef.HALVE_TICK:
			lines.append(_exception("每次结算后层数减半"))
		BuffDef.HALVE_WEAPON_FIRED:
			lines.append("武器出手时，这一次的冷却每层 +%s%%；之后%s" % [pct, _exception("层数减半")])
		BuffDef.HALVE_STAMINA_PAID:
			lines.append("付耐力时，这一次的消耗每层 +%s%%；之后%s" % [pct, _exception("层数减半")])
	for k in def.damage_taken_by_type.keys():
		lines.append("受到的%s伤害每层 +%s%%" % [damage_type_name(StringName(String(k))), TextTemplate.num(float(def.damage_taken_by_type[k]))])
	if def.element != &"":
		lines.append("%s元素的印：带着它再挨上别的元素，引发反应" % ReactionResolver.element_name(def.element))
	if def.heal_cut > 0:
		lines.append("治疗无效" if def.heal_cut >= 100 else "每次恢复生命少 %d%%" % def.heal_cut)
	if def.heal_echo != &"":
		var per := def.heal_echo_per_point
		var each := "" if is_equal_approx(per, 1.0) else "×%s" % TextTemplate.num(per)
		lines.append("每次恢复生命，实际回了几点就叠几层%s%s" % [status_name(def.heal_echo), each])
	return "\n".join(lines)


## 例外色（103）：buff 的默认是永续、可叠层，不是默认的那几个字染成这个色
const EXCEPTION_COLOR := Color("e0b45c")


static func _exception(text: String) -> String:
	return "[color=#%s]%s[/color]" % [EXCEPTION_COLOR.to_html(false), text]


## 一条规则的一句（142：全部由字段生成）：「[你给对手施加流血时] 获得血勇」「[造成物理伤害前] 若对手有流血，伤害 +20%」。
##
## 方括号里是扳机那句（[method Trigger.describe]）；自发且有冷却的写「每 N 秒」（武器那条悬浮窗再换成实算冷却），
## 别的扳机带冷却的在方括号后写「每 N 秒最多一次」。之后是条件 / 消耗（[method Cost.describe]），最后是效果。
## [param skip_stamina]：耐力消耗另有地方写（道具悬浮窗的「耗耐力 N」）时不在句子里重复
static func rule_text(rule: AbilityRule, skip_stamina: bool = false) -> String:
	var line := ""
	var cad := cadence_text(rule)
	if _scheduled(rule):
		line = "[%s] " % cad
	else:
		var when := trigger_text(rule.trigger)
		line = ("[%s] " % when) if when != "" else ""
		if cad != "":
			line += cad + "，"
	var bits: Array[String] = []
	var costs := costs_text(rule, skip_stamina)
	if costs != "":
		bits.append(costs)
	bits.append(effects_text(rule.effects))
	return line + "，".join(bits)


## 自发且有冷却：方括号里直接写「每 N 秒」
static func _scheduled(rule: AbilityRule) -> bool:
	return rule.trigger is OnSchedule and rule.cadence is CooldownCadence


## 145：节奏那半句。自发的「每 N 秒」，别的扳机带冷却「每 N 秒最多一次」，没冷却为空
static func cadence_text(rule: AbilityRule) -> String:
	var cd := rule.cadence as CooldownCadence
	if cd == null:
		return ""
	return ("每 %.1f 秒" if _scheduled(rule) else "每 %.1f 秒最多一次") % cd.seconds


## 145：规则列表「时机」那一列 = 扳机句 + 节奏（自发的只写「每 N 秒」）
static func timing_text(rule: AbilityRule) -> String:
	var cad := cadence_text(rule)
	if _scheduled(rule):
		return cad
	var when := trigger_text(rule.trigger)
	if when == "":
		when = "（没有扳机）"
	return when + ("，" + cad if cad != "" else "")


## 145：显式消耗 / 条件，「，」连起来；没有为空
static func costs_text(rule: AbilityRule, skip_stamina: bool = false) -> String:
	var bits: Array[String] = []
	for c in rule.costs:
		if c == null:
			continue
		if skip_stamina and c is ResourceCost and (c as ResourceCost).resource_key == BattleStats.RES_STAMINA:
			continue
		var d := (c as Cost).describe()
		if d != "":
			bits.append(d)
	return "，".join(bits)


static func effects_text(effects: Array) -> String:
	var bits: Array[String] = []
	for e in effects:
		if e == null:
			continue
		var d: String = e.describe() if e.has_method("describe") else ""
		bits.append(d if d != "" else String(ContentSchema.registry_name_of(e)))
	return "，".join(bits) if not bits.is_empty() else "（没有效果）"


const TRIGGER_NAMES := {"on_schedule": "自发", "on_battle_start": "开战时", "on_item_fired": "出手时", "on_damage": "受伤时",
	"on_before_damage": "受伤前", "on_stacks_at_least": "层数够时", "on_resource_below": "资源低于时",
	"on_status_applied": "施加时", "on_status_removed": "状态掉光时", "on_overtime": "加时开始时"}


## 时机的类别名（百科「时机」那一页的词条用）：自发 / 开战时 / 施加时……
static func trigger_name(trigger: Trigger) -> String:
	if trigger == null:
		return ""
	var key := String(ContentSchema.registry_name_of(trigger))
	return String(TRIGGER_NAMES.get(key, key))


## 142：规则行方括号里那句 —— 扳机自己按字段说（[method Trigger.describe]）；没写的退回类别名
static func trigger_text(trigger: Trigger) -> String:
	if trigger == null:
		return ""
	var d := trigger.describe()
	return d if d != "" else trigger_name(trigger)


## 142：状态 id 给人看。按 id 引用的状态（扳机、条件、移除）都是有登记的类型（流血、中毒……），名字从那里取；
## 查不到原样返回（测试守着：道具的规则行里不出现英文 id）
static func status_name(id: StringName) -> String:
	if id == &"":
		return "?"
	return DamageTypes.name_of(id)


const RESOURCE_NAMES := {"hp": {"zh": "生命", "en": "Health"}, "stamina": {"zh": "耐力", "en": "Stamina"},
	"mana": {"zh": "法力", "en": "Mana"}, "armor": {"zh": "护甲", "en": "Armor"}}


static func resource_name(key: StringName) -> String:
	return UiText.pick(RESOURCE_NAMES.get(String(key), null), String(key))


#region 收集 buff
## 一件道具会施加的所有 buff（自己的规则、信力加成的规则、buff 自带规则里再施加的），id → 定义
static func buffs_in_item(def: ItemDef) -> Dictionary:
	var out := {}
	if def == null:
		return out
	if def.combat != null:
		buffs_in_rules(def.combat.rules, out)
	for fb in def.faith_bonuses:
		var b := fb as FaithBonus
		if b != null:
			buffs_in_rules(b.rules, out)
	if def.adjacency != null:
		buffs_in_rules(def.adjacency.grant_rules, out)     # 108：毒箭给邻居挂的中毒，毒箭自己的侧窗也要能解释
	return out


## 一个战斗单位会施加的所有 buff（战斗屏的 buff 栏要）
static func buffs_in_spec(spec: CombatantSpec) -> Dictionary:
	var out := {}
	if spec == null:
		return out
	for it in spec.items:
		buffs_in_rules((it as CompiledItem).rules, out)
	buffs_in_rules(spec.set_rules, out)
	return out


static func buffs_in_rules(rules: Array, out: Dictionary) -> void:
	for r in rules:
		var rule := r as AbilityRule
		if rule == null:
			continue
		_buffs_in_effects(rule.effects, out)


static func _buffs_in_effects(effects: Array, out: Dictionary) -> void:
	for e in effects:
		var buff: BuffDef = null
		if e is ApplyStatus:
			buff = (e as ApplyStatus).buff
		elif e is ConvertStatus:
			buff = (e as ConvertStatus).to     # 130：转化出来的剧毒也要能解释
		elif e is GuardStatus:
			buff = (e as GuardStatus).buff     # 175 补充四：凝毒 / 冻疮锁的是中毒 / 流血
		if buff == null or out.has(buff.id):
			continue
		out[buff.id] = buff
		buffs_in_rules(buff.rules, out)
		_buffs_in_effects(buff.on_apply, out)
		_buffs_in_effects(buff.on_expire, out)
#endregion


#region 找词、标色
## 剥掉 BBCode 标签，只留文字（实现在 [method TextTemplate.strip_bbcode]）
static func strip_bbcode(text: String) -> String:
	return TextTemplate.strip_bbcode(text)


## 文字里出现了哪些词条：固定词条 + [param extra]（名字 → 解释，或名字 → `{"id", "text"}`：buff / 标签词条），按第一次出现的位置排。
## 返回 `[{"name": 词, "text": 解释, "id": 词条 id}]`（固定词条的 id 就是词本身）；同一个词只出一次
static func terms_in(text: String, extra: Dictionary = {}) -> Array:
	var plain := strip_bbcode(text)
	var found: Array = []
	var names := {}
	for name in extra:
		var v = extra[name]
		names[String(name)] = v if v is Dictionary else {"id": String(name), "text": String(v)}
	for name in TERMS:
		if not names.has(name) and term_tip(name):     # 107：tip 关掉的词不弹，也因此不被 mark 标出
			names[name] = {"id": name, "text": term_text(name)}
	for name in names:
		var at := plain.find(name)
		if at >= 0:
			found.append({"name": name, "text": String(names[name]["text"]), "id": String(names[name].get("id", name)), "at": at})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["at"]) < int(b["at"]) if int(a["at"]) != int(b["at"]) else String(a["name"]).length() > String(b["name"]).length())
	var out: Array = []
	for f in found:
		out.append({"name": f["name"], "text": f["text"], "id": f["id"]})
	return out


## 把词条在文字里标出来：170 起是**关键词** —— `[url=term:<id>]` 包着词条色 + 下划线；悬浮窗钉住后停上去开子窗（[HoverTip]）
static func mark(text: String, terms: Array) -> String:
	var names: Array[String] = []
	var ids := {}
	for t in terms:
		var d := t as Dictionary
		names.append(String(d["name"]))
		ids[String(d["name"])] = String(d.get("id", d["name"]))
	return wrap_terms(text, names, func(name: String) -> String:
		return "[url=term:%s][color=%sterm][u]%s[/u][/color][/url]" % [ids[name], TextTemplate.STYLE_PREFIX, name])


## 把一串词在文字里各包一层（[param wrap]：词 → 包好的 BBCode）。长的词先替，替进去的先用占位符挡住，免得短词把长词切开。
## 170：BBCode 标签里面（`[url=term:增益槽]` 这种参数）不替。词条标色（[method mark]）与百科画链接（[method Encyclopedia.link_words]）同一套，只差包的是什么
static func wrap_terms(text: String, names: Array[String], wrap: Callable) -> String:
	var sorted: Array[String] = []
	sorted.assign(names)
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	if sorted.is_empty():
		return text
	var out := ""
	var at := 0
	while at < text.length():
		var open := text.find("[", at)
		if open < 0:
			out += _wrap_plain(text.substr(at), sorted, wrap)
			break
		var close := text.find("]", open)
		if close < 0:
			out += _wrap_plain(text.substr(at), sorted, wrap)
			break
		out += _wrap_plain(text.substr(at, open - at), sorted, wrap) + text.substr(open, close - open + 1)
		at = close + 1
	return out


static func _wrap_plain(text: String, sorted: Array[String], wrap: Callable) -> String:
	if text == "":
		return text
	var out := text
	var holders: Array[String] = []
	for i in sorted.size():
		var holder := "\u0001%d\u0002" % i
		holders.append(holder)
		out = out.replace(sorted[i], holder)
	for i in sorted.size():
		out = out.replace(holders[i], String(wrap.call(sorted[i])))
	return out
#endregion
