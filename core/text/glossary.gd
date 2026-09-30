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

## 固定词条：关键词 → 解释。键就是主文字里出现的原词
const TERMS := {
	"自发": "不等任何事件，按自己的冷却周期反复出手 —— 武器的普通攻击都是自发的。",
	"开战时": "战斗开始那一瞬触发一次。",
	"出手时": "有道具出手时跟着触发（连带）。",
	"受伤时": "受到伤害之后触发。",
	"层数够时": "身上某个状态叠到指定层数时触发。",
	"资源低于时": "生命 / 耐力等降到阈值以下时触发。",
	"冷却": "两次出手之间的间隔（秒），急速会缩短它。",
	"急速": "出手速度的倍率，越高冷却越短。",
	"护甲": "每次受到的伤害固定减少这个数，减到 0 为止。中毒、流血无视护甲。",
	"护盾": "先于生命被扣的一层。开战时按护盾上限充满，之后不自己回复。中毒、流血无视护盾。",
	"耐力": "出手要花的资源，每秒按回复速度补回；不够就出不了手，等回够再动。",
	"耗耐力": "这一下出手要花的耐力。",
	"永续": "不会过期，一直到战斗结束（除非被清除）。",
	"叠层": "同一个状态可以叠多层，效果按层数累加；没写上限就不限层。",
	"休眠": "别的信仰激活着，这件信仰道具不起信仰的作用：只留它本身的通用效果（盾的减伤、武器的攻击力），护符这类彻底失效。",
	"信力": "按信仰要求的行为攒的点数；过了阈值，这个信仰的道具解锁更多功能。",
	"合成": "两件有配方的道具在棋盘上相邻，走到下一个点时自动合成一件新的；装不下就进暂存区。",
	"增益槽": "这件道具的一种格位：邻居占着它，邻居就得到写着的加成。",
	"受益槽": "这件道具的一种格位：每被邻居点亮一格，自己就得一份写着的加成。",
	"中毒": "每层每秒造成毒伤，无视护甲与护盾，永续叠层。",
	"流血": "每层每秒造成流血伤害，无视护甲与护盾，永续叠层。",
}

## 标签 → 中文（093：献祭品、信仰条件的说明用；没登记的原样）
const TAG_NAMES := {
	"weapon": "武器", "melee": "近战", "ranged": "远程", "gun": "枪械", "gear": "防具", "armor": "护甲", "shield": "盾", "heavy": "重型",
	"consumable": "消耗品", "tool": "工具", "part": "零件", "material": "材料", "ammo": "弹药", "food": "食物", "nature": "自然",
	"bone": "骨制品", "flesh": "血肉", "metal": "金属", "fire": "火焰", "gem": "宝石", "faith": "信仰", "sigil": "符号", "blessed": "赐福",
	"treasure": "珍宝", "relic": "遗物", "sealed": "封印", "poison": "毒", "bleed": "流血", "imperial": "帝国", "barbarian": "蛮族",
}
## 伤害类型 → 中文
const DAMAGE_TYPE_NAMES := {"physical": "物理", "fire": "火焰", "poison": "毒", "bleed": "流血", "reflect": "反射", "drain": "流失"}


static func tag_name(tag: StringName) -> String:
	return String(TAG_NAMES.get(String(tag), String(tag)))


static func damage_type_name(type: StringName) -> String:
	return String(DAMAGE_TYPE_NAMES.get(String(type), String(type)))


## 属性键 → 中文
const STAT_NAMES := {
	"damage": "伤害", "armor": "护甲", "max_hp": "生命", "max_stamina": "耐力上限", "haste": "急速", "cooldown": "冷却",
	"regen_stamina": "每秒回耐力", "regen_hp": "每秒回血", "max_shield": "护盾", "max_mana": "法力", "regen_mana": "每秒回法力",
	"stamina_cost": "耗耐力", "mana_cost": "耗法力",
}
## 乘区 → 中文
const CATEGORY_NAMES := {"EMPOWER": "增伤", "SHARP": "物理增伤", "FIRE": "火焰增伤", "HASTE": "急速"}


static func stat_name(key: StringName) -> String:
	return String(STAT_NAMES.get(String(key), String(key)))


## 一条属性修饰给人看：「伤害 +10%」「护甲 +4」
static func mod_text(m: StatModifier) -> String:
	if m == null:
		return ""
	var parts: Array[String] = []
	if m.mult_category >= 0 and m.mult_percent != 0:
		var cat := String(CATEGORY_NAMES.get(StatMath.category_name(m.mult_category), StatMath.category_name(m.mult_category)))
		if m.stat == BattleStats.DAMAGE:
			parts.append("%s %+d%%" % [cat, m.mult_percent])
		else:
			parts.append("%s %+d%%（%s）" % [stat_name(m.stat), m.mult_percent, cat])
	if m.flat != 0.0:
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
	lines.append("%s　%s　%s" % [kind, stacks, def.duration_text()])
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
		if not names.has(name):
			names[name] = TERMS[name]
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
