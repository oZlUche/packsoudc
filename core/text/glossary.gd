## 词条表（087，作者定）：道具说明里指向特定名词 / 关键词的地方（「护符结界」「自发」「中毒」「血怒」……），
## 悬浮窗**侧边**给每个关键词开一个小窗写具体效果 —— 主文字只写名词，不写「伤害 +10%」这种细节。
##
## 两类词条：**固定词条**（[constant TERMS]：时机、属性、机制的通用解释）与 **buff 词条**（从道具的规则里收集到的 [BuffDef]，
## 说明由 [method describe_buff] 按定义生成 —— 数据改了文字跟着改，不用手写）。
## 这一层只产出**数据**（`[{name, text}]`）与标了色的 BBCode；怎么画是 [HoverTip] 的事。将来换正式渲染，这套「主文字 + 侧边词条」的逻辑保留
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
	"资源低于时": {"text": "生命 / 耐力等降到阈值以下时触发。", "tip": false},
	"冷却": {"text": "两次出手之间的间隔（秒），急速会缩短它。", "tip": false},
	"耐力": {"text": "出手要花的资源，每秒按回复速度补回；不够就出不了手，等回够再动。", "tip": false},
	"耗耐力": {"text": "这一下出手要花的耐力。", "tip": false},
	"信力": {"text": "按信仰要求的行为攒的点数；过了阈值，这个信仰的道具解锁更多功能。", "tip": false},
	# 以下都带玩家猜不到的规则（换算、结算顺序、叠层方式），照弹
	"急速": {"text": "出手速度的倍率，越高冷却越短。"},
	"防护": {"text": "每次受到**直接伤害**（武器造成的）固定减少这个数，减到 0 为止；破绽为负时反而多挨。buff 造成的灼烧、中毒、流血不算直接伤害，防护挡不住。"},
	"护盾": {"text": "先于生命被扣的一层。开战时按护盾上限充满，之后不自己回复。中毒、流血无视护盾。"},
	"直接伤害": {"text": "武器造成的伤害。防护（格挡 / 破绽）只减它；buff 造成的伤害（灼烧、中毒、流血）不是直接伤害。"},
	"永续": {"text": "不会过期，一直到战斗结束（除非被清除）。"},
	"叠层": {"text": "同一个状态可以叠多层，效果按层数累加；没写上限就不限层。"},
	"合成": {"text": "把一件道具拖到另一件上面，两件有配方就立刻合成一件新的；装不下就进暂存区。"},
	"增益槽": {"text": "这件道具的一种格位：邻居占着它，邻居就得到写着的加成。"},
	"受益槽": {"text": "这件道具的一种格位：每被邻居点亮一格，自己就得一份写着的加成。"},
	# 107（作者定）：这两条写的是**buff**（每层每秒掉血、无视防护与护盾），不是武器的伤害类型 —— 同名的标签
	# 「中毒」「流血」指类型，那边 tip 为 false。两边文字都保留
	"中毒": {"text": "每层每秒造成毒伤，无视防护与护盾，永续叠层。"},
	"流血": {"text": "每层每秒造成流血伤害，无视防护与护盾，永续叠层。"},
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
	var fid := FaithDef.id_of_tag(tag)
	if fid != &"":
		var defs := FaithDef.load_all()
		var god: FaithDef = defs.get(fid, null)
		return "%s%s%s" % [_pick(FAITH_WORD), "：" if UiText.lang == "zh" else ": ", Names.of(god) if god != null else String(fid)]
	return TagRegistry.name_of(tag)


## 标签的词条（096）：登记了说明的标签 → {名字: 说明}；没说明的不出。
## 107：`tip` 关掉的标签也不出 —— 名字仍在标签行里列着，只是不弹窗
static func tag_terms(tags: Array) -> Dictionary:
	var out := {}
	for t in tags:
		var d := TagRegistry.describe(t)
		if d != "" and TagRegistry.tip_of(t) and not TagRegistry.is_internal(t):
			out[tag_name(t)] = d
	return out


## 伤害类型给人看（096：数据 —— [DamageTypes.name_of]，按当前语言）
static func damage_type_name(type: StringName) -> String:
	return DamageTypes.name_of(type)


const FAITH_WORD := {"zh": "信仰", "en": "Faith"}

## 属性键 → 名字（096：中 / 英；按 [UiText.lang] 取，没有英文的回落中文）
const STAT_NAMES := {
	"damage": {"zh": "伤害", "en": "Damage"}, "armor": {"zh": "防护", "en": "Armor"}, "max_hp": {"zh": "生命", "en": "Health"},
	"max_stamina": {"zh": "耐力上限", "en": "Max stamina"}, "haste": {"zh": "急速", "en": "Haste"}, "cooldown": {"zh": "冷却", "en": "Cooldown"},
	"regen_stamina": {"zh": "每秒回耐力", "en": "Stamina regen"}, "regen_hp": {"zh": "每秒回血", "en": "Health regen"}, "max_shield": {"zh": "护盾", "en": "Shield"},
	"max_mana": {"zh": "法力上限", "en": "Max mana"}, "regen_mana": {"zh": "每秒回法力", "en": "Mana regen"},
	"stamina_cost": {"zh": "耗耐力", "en": "Stamina cost"}, "mana_cost": {"zh": "耗法力", "en": "Mana cost"},
	"crit_chance": {"zh": "暴击率", "en": "Crit chance"}, "crit_damage": {"zh": "暴击伤害", "en": "Crit damage"},
}
## 乘区 → 名字
const CATEGORY_NAMES := {"EMPOWER": {"zh": "增伤", "en": "Empower"}, "SHARP": {"zh": "物理增伤", "en": "Sharpness"},
	"ELEMENT": {"zh": "元素增伤", "en": "Elemental power"}, "HASTE": {"zh": "急速", "en": "Haste"}}


## 一张「语言 → 文字」的小表按当前语言取；没有就中文；传进来的不是表就原样
static func _pick(entry: Variant, fallback: String = "") -> String:
	if entry is Dictionary:
		var d := entry as Dictionary
		return String(d.get(UiText.lang, d.get("zh", fallback)))
	return String(entry) if entry != null else fallback


static func stat_name(key: StringName) -> String:
	return _pick(STAT_NAMES.get(String(key), null), String(key))


## 一条属性修饰给人看：「伤害 +10%」「防护 +4」
static func mod_text(m: StatModifier) -> String:
	if m == null:
		return ""
	var parts: Array[String] = []
	if m.mult_category >= 0 and m.mult_percent != 0:
		var cat := _pick(CATEGORY_NAMES.get(StatMath.category_name(m.mult_category), null), StatMath.category_name(m.mult_category))
		if m.stat == BattleStats.DAMAGE:
			parts.append("%s %+d%%" % [cat, m.mult_percent])
		else:
			parts.append("%s %+d%%（%s）" % [stat_name(m.stat), m.mult_percent, cat])
	if m.flat != 0.0 and BattleStats.PERCENT_DISPLAY.has(m.stat):
		parts.append("%s %+d%%" % [stat_name(m.stat), roundi(m.flat * 100.0)])     # 104：暴击按百分数写
	elif m.flat != 0.0:
		var f := m.flat
		parts.append("%s %s" % [stat_name(m.stat), ("%+d" % roundi(f)) if is_equal_approx(f, roundf(f)) else "%+.1f" % f])
	return "、".join(parts) if not parts.is_empty() else "%s（无效果）" % stat_name(m.stat)


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
	var stacks := "不可叠层" if not def.is_stackable() else ("不限层" if def.max_stacks <= 0 else "至多 %d 层" % def.max_stacks)
	var duration := def.duration_text()
	# 103：默认永续、可叠层；不可叠层与会过期是例外，用例外色标出来，作者 / 玩家一眼看出「这个不是默认」
	if not def.is_stackable():
		stacks = _exception(stacks)
	if not def.is_permanent():
		duration = _exception(duration)
	lines.append("%s　%s　%s" % [kind, stacks, duration])
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
	return "\n".join(lines)


## 例外色（103）：buff 的默认是永续、可叠层，不是默认的那几个字染成这个色
const EXCEPTION_COLOR := Color("e0b45c")


static func _exception(text: String) -> String:
	return "[color=#%s]%s[/color]" % [EXCEPTION_COLOR.to_html(false), text]


## 一条规则的一句：「[自发] 每 1.0 秒　造成 poison 伤害」
static func rule_text(rule: AbilityRule) -> String:
	var when := trigger_name(rule.trigger)
	var line := ("[%s] " % when) if when != "" else ""
	if rule.cadence is CooldownCadence:
		line += "每 %.1f 秒　" % (rule.cadence as CooldownCadence).seconds
	line += effects_text(rule.effects)
	return line


static func effects_text(effects: Array) -> String:
	var bits: Array[String] = []
	for e in effects:
		if e == null:
			continue
		var d: String = e.describe() if e.has_method("describe") else ""
		bits.append(d if d != "" else String(ContentExporter._registry_name_of(e)))
	return "，".join(bits) if not bits.is_empty() else "（没有效果）"


const TRIGGER_NAMES := {"on_schedule": "自发", "on_battle_start": "开战时", "on_item_fired": "出手时", "on_damage": "受伤时",
	"on_before_damage": "受伤前", "on_stacks_at_least": "层数够时", "on_resource_below": "资源低于时", "on_resource_changed": "资源变化时"}


static func trigger_name(trigger: Trigger) -> String:
	if trigger == null:
		return ""
	var key := String(ContentExporter._registry_name_of(trigger))
	return String(TRIGGER_NAMES.get(key, key))


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
		var ap := e as ApplyStatus
		if ap == null or ap.buff == null or out.has(ap.buff.id):
			continue
		out[ap.buff.id] = ap.buff
		buffs_in_rules(ap.buff.rules, out)
		_buffs_in_effects(ap.buff.on_apply, out)
		_buffs_in_effects(ap.buff.on_expire, out)
#endregion


#region 找词、标色
## 剥掉 BBCode 标签，只留文字
static func strip_bbcode(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\[/?[a-zA-Z][^\\]]*\\]")
	return re.sub(text, "", true)


## 文字里出现了哪些词条：固定词条 + [param extra]（名字 → 解释，buff 词条），按第一次出现的位置排。
## 返回 `[{"name": 词, "text": 解释}]`；同一个词只出一次
static func terms_in(text: String, extra: Dictionary = {}) -> Array:
	var plain := strip_bbcode(text)
	var found: Array = []
	var names := {}
	for name in extra:
		names[String(name)] = String(extra[name])
	for name in TERMS:
		if not names.has(name) and term_tip(name):     # 107：tip 关掉的词不进侧窗，也因此不被 mark 标色
			names[name] = term_text(name)
	for name in names:
		var at := plain.find(name)
		if at >= 0:
			found.append({"name": name, "text": names[name], "at": at})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["at"]) < int(b["at"]) if int(a["at"]) != int(b["at"]) else String(a["name"]).length() > String(b["name"]).length())
	var out: Array = []
	for f in found:
		out.append({"name": f["name"], "text": f["text"]})
	return out


## 把词条在文字里标出来（颜色 + 下划线）。长的词先替，替进去的先用占位符挡住，免得短词把长词切开
static func mark(text: String, terms: Array) -> String:
	var names: Array[String] = []
	for t in terms:
		names.append(String((t as Dictionary)["name"]))
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out := text
	var holders: Array[String] = []
	for i in names.size():
		var holder := "\u0001%d\u0002" % i
		holders.append(holder)
		out = out.replace(names[i], holder)
	for i in names.size():
		out = out.replace(holders[i], "[color=#%s][u]%s[/u][/color]" % [TERM_COLOR.to_html(false), names[i]])
	return out
#endregion
