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

## 193 补充一（作者定）：倒计时这口钟的消耗与剩余都说「倒计时」，不说「步」；走路的距离仍说「步」
const COUNTDOWN_WORD := "倒计时"

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
	"寸步难行": {"text": "负重超过上限的 1.5 倍：超重的减益照旧，地图上每走一步（传送也算）" + COUNTDOWN_WORD + " −2；原地等待不翻倍。"},
	"地上": {"text": "棋盘之外的整块屏幕：拖出棋盘放哪就落在哪。不参战、不吃邻接、不算套装、撤离不带走；留在这个点上，回来还在原处。", "tip": false},
	# 以下都带玩家猜不到的规则（换算、结算顺序、叠层方式），照弹
	"急速": {"text": "出手速度的倍率，越高冷却越短。"},
	# 153（作者定）：防护改名格挡，只有盾牌给，几面盾只算最高的一面
	"格挡": {"text": "只有盾牌给格挡。每次受到直接伤害（武器造成的）固定减少这个数，减到零为止；带几面盾只算最高的一面，加固 / 破绽在它之上加减，破绽为负时反而多挨。buff 造成的灼烧、中毒、流血不算直接伤害，格挡挡不住。"},
	"护甲": {"text": "先于生命被扣的一层。开战时按护甲上限充满，之后不自己回复。中毒、流血无视护甲。"},
	"直接伤害": {"text": "武器造成的伤害。格挡（加固 / 破绽）只减它；buff 造成的伤害（灼烧、中毒、流血）不是直接伤害。"},
	"永续": {"text": "不会过期，一直到战斗结束（除非被清除）。"},
	"叠层": {"text": "同一个状态可以叠多层，效果按层数累加；没写上限就不限层。"},
	"合成": {"text": "把一件道具拖到另一件上面，两件有配方就立刻合成一件新的；装不下就到地上。"},
	"增益槽": {"text": "这件道具的一种格位：邻居占着它，邻居就得到写着的加成。"},
	"受益槽": {"text": "这件道具的一种格位：每被邻居点亮一格，自己就得一份写着的加成。"},
	"装载槽": {"text": "法杖的晶石座：放上去的魔晶石把它带的供给交给法杖。一颗晶石只给一把法杖（压着两把的给后放的那把），占了同一把的几个装载槽也只算一份。"},
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


#region 175 补 5.4：伤害类型字与元素状态关键词的颜色
## 伤害类型 → 样式名（[constant TextTemplate.STYLE_NAMES]）。「火焰伤害」整段染这个色、**不是关键词**；没列的（物理、反伤、流失）不染
const DAMAGE_STYLES := {&"fire": "fire", &"ice": "frost", &"lightning": "thunder", &"poison": "toxin", &"bleed": "true"}
## 元素 → 元素状态关键词的样式名（同系、更亮）。状态是关键词：下划线 + 这个色，弹词条
const ELEMENT_STYLES := {&"fire": "scorch", &"ice": "chill", &"lightning": "shock", &"poison": "poison", &"bleed": "bleed"}


## 一个状态当关键词时用哪个色：元素状态用它元素的那个，别的用词条色 `term`
static func status_style(def: BuffDef) -> String:
	if def != null and ELEMENT_STYLES.has(def.element):
		return String(ELEMENT_STYLES[def.element])
	return "term"


## 「火焰伤害」这几个字（整段带色；物理之类没有色的原样）
static func damage_words(type: StringName) -> String:
	var words := "%s伤害" % damage_type_name(type)
	if not DAMAGE_STYLES.has(type):
		return words
	return "[color=%s%s]%s[/color]" % [TextTemplate.STYLE_PREFIX, DAMAGE_STYLES[type], words]


## 标关键词，同时把文字里的「X伤害」染成伤害类型色。先挡住伤害字再标关键词 ——
## 不然「流血伤害」里的「流血」会被当成流血状态的关键词（伤害类型和状态同名）
static func mark_rich(text: String, terms: Array) -> String:
	var holders: Array = []
	var out := text
	var types: Array = DAMAGE_STYLES.keys()
	types.sort_custom(func(a, b) -> bool: return damage_type_name(a).length() > damage_type_name(b).length())
	for type in types:
		var words := "%s伤害" % damage_type_name(type)
		if not out.contains(words):
			continue
		var token := "\u0003%d\u0003" % holders.size()
		holders.append([token, damage_words(type)])
		out = out.replace(words, token)
	out = mark(out, terms)
	for h in holders:
		out = out.replace(String(h[0]), String(h[1]))
	return out
#endregion


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


#region 185（作者 2026-10-17 定稿）：效果悬浮窗 —— 名字行 + 现在的合计
## 玩家看到的只有两段：名字行（名字、×层数、增益 / 减益 / 系统）与效果（每条一行，写**这个状态现在的合计**）。
## 叠层、计时、减半、元素印、不可解除这些机制说明是内部说明（作者 16:07：不该给玩家看），只进 [method buff_rule_lines] 给作者工具。
## 限时状态写时间（作者 16:24）：战斗里写还剩几秒，别处写持续几秒。数值统一走 [method val] 上色（样式 `val`）

const NAME_SIZE := 19
const KIND_SIZE := 13
const BODY_SIZE := 15
## 名字描边（同 [constant UiTheme.OUTLINE_SIZE] / [constant UiTheme.OUTLINE_COLOR]；core 不引界面）
const NAME_OUTLINE := "[outline_size=2][outline_color=#000000bf]%s[/outline_color][/outline_size]"
## 系统状态（衰竭、鏖战）的名字色（同 [constant CombatantPanel.SYSTEM_COLOR]）
const SYSTEM_NAME_COLOR := "#e0b45c"

static var _num_re: RegEx = null


## 一个数值上数值色
static func val(text: String) -> String:
	return "[color=%sval]%s[/color]" % [TextTemplate.STYLE_PREFIX, text]


## 一段字里的数字（连同正负号与 %）都上数值色；方括号标签里面不动
static func val_numbers(text: String) -> String:
	if _num_re == null:
		_num_re = RegEx.create_from_string("[+\\-−]?\\d+(?:\\.\\d+)?%?")
	var out := ""
	var at := 0
	while at < text.length():
		var open := text.find("[", at)
		if open < 0:
			out += _val_plain(text.substr(at))
			break
		out += _val_plain(text.substr(at, open - at))
		var close := text.find("]", open)
		if close < 0:
			out += text.substr(open)
			break
		out += text.substr(open, close - open + 1)
		at = close + 1
	return out


static func _val_plain(s: String) -> String:
	var out := ""
	var last := 0
	for m in _num_re.search_all(s):
		out += s.substr(last, m.get_start() - last) + val(m.get_string())
		last = m.get_end()
	return out + s.substr(last)


## 增益 / 减益 / 系统
static func buff_kind(def: BuffDef) -> String:
	if def != null and def.system:
		return "系统"
	return "减益" if def != null and def.is_debuff else "增益"


## 名字行（BBCode）：名字（状态色、描边）+ 可叠层的 ×层数 + 右边的增益 / 减益 / 系统小字。[param stacks] ≤ 0 = 不写层数（图鉴、子窗）
static func buff_head(def: BuffDef, stacks: int = 0) -> String:
	if def == null:
		return ""
	var name := Names.of(def) if Names.of(def) != "" else String(def.id)
	var color := SYSTEM_NAME_COLOR if def.system else TextTemplate.STYLE_PREFIX + status_style(def)
	return tip_head(name, color, "×" + str(stacks) if stacks > 0 and def.is_stackable() else "", buff_kind(def))


## 名字行的通用版（轴格、鏖战、格挡、常驻格也用）：名字（[param color]、描边）+ 层数 / 读数（数值色）+ 右边的小字
static func tip_head(name: String, color: String, count: String = "", kind: String = "") -> String:
	var line := NAME_OUTLINE % ("[b][color=%s]%s[/color][/b]" % [color, name])
	if count != "":
		line += " [b][color=%stip_fg]%s[/color][/b]" % [TextTemplate.STYLE_PREFIX, val_numbers(count)]
	var out := "[font_size=%d]%s[/font_size]" % [NAME_SIZE, line]
	if kind != "":
		out += "　　[font_size=%d][color=%stip_meta]%s[/color][/font_size]" % [KIND_SIZE, TextTemplate.STYLE_PREFIX, kind]
	return out


## 效果段（纯文字，一条一行）：每层的量 × [param stacks]（≤ 0 按 1 层）。顺序：恢复 / 规则伤害 → 轴 → 属性 → 按类型易伤 → 出手 / 付耐力 → 上身 / 到期
static func buff_effect_lines(def: BuffDef, stacks: int = 1) -> Array[String]:
	var lines: Array[String] = []
	if def == null:
		return lines
	var n := maxi(1, stacks)
	var dmg: Array[String] = []
	for r in def.rules:
		var rule := r as AbilityRule
		if rule == null:
			continue
		var line := _self_damage_text(rule, n)
		dmg.append(line if line != "" else rule_text(rule))
	var heal: Array[String] = []
	if def.heal_cut > 0:
		heal.append("恢复量减半" if def.heal_cut == 50 else "恢复量归零" if def.heal_cut >= 100 else "恢复量少 %d%%" % def.heal_cut)
	if def.heal_echo != &"":
		var per := def.heal_echo_per_point
		heal.append(("每次恢复获得等量的%s" if is_equal_approx(per, 1.0) else "每次恢复按 " + TextTemplate.num(per) + " 倍获得%s") % status_name(def.heal_echo))
	if not heal.is_empty():
		heal.append_array(dmg)     # 作者原话：「恢复量归零，每秒受到 N 点火焰伤害」一句说完
		lines.append("，".join(heal))
	else:
		lines.append_array(dmg)
	for a in def.axes:
		var ba := a as BuffAxis
		if ba != null:
			lines.append(StatAxes.effect_text(ba.axis, ba.stacks * n))
	for m in def.mods:
		var mod := m as StatModifier
		if mod == null:
			continue
		var total := mod.duplicate() as StatModifier
		total.amount = mod.amount * n
		lines.append(mod_text(total))
	for k in def.damage_taken_by_type.keys():
		lines.append("受到的%s伤害 +%s%%" % [damage_type_name(StringName(String(k))), TextTemplate.num(float(def.damage_taken_by_type[k]) * n)])
	var pct := TextTemplate.num(def.per_stack_percent * n)
	match def.decay_halve_on:
		BuffDef.HALVE_WEAPON_FIRED:
			lines.append("下一次出手的冷却 +%s%%" % pct)
		BuffDef.HALVE_STAMINA_PAID:
			lines.append("下一次付耐力多付 %s%%" % pct)
	if not def.on_apply.is_empty():
		lines.append("上身时：" + effects_text(def.on_apply))
	if not def.on_expire.is_empty():
		lines.append("到期时：" + effects_text(def.on_expire))
	return lines


## 按层对自己的定时伤害（中毒、流血、灼伤、燃血）：「每秒受到 5 点毒素伤害」；不是这种规则返回空
static func _self_damage_text(rule: AbilityRule, n: int) -> String:
	if not _scheduled(rule) or rule.effects.size() != 1:
		return ""
	var d := rule.effects[0] as DealDamage
	if d == null or d.target != CombatEffect.Target.SELF or not d.per_stack or d.percent_of != &"":
		return ""
	var secs := (rule.cadence as CooldownCadence).seconds
	var every := "每秒" if is_equal_approx(secs, 1.0) else "每 %s 秒" % TextTemplate.num(secs)
	return "%s受到 %s 点%s伤害" % [every, TextTemplate.num(d.amount * n), damage_type_name(d.damage_type)]


## 时间那一行：[param time_left] ≥ 0（战斗里，回放时刻）写「还剩 N 秒」；< 0 写定义里的时长；永续的没有
static func buff_time_line(def: BuffDef, time_left: float = -1.0) -> String:
	if def == null:
		return ""
	if time_left >= 0.0:
		return "还剩 %d 秒" % ceili(time_left)
	if def.seconds_per_stack > 0 and def.is_stackable():
		return "每层 %d 秒" % def.seconds_per_stack
	return "" if def.is_permanent() else "持续 %s 秒" % TextTemplate.num(def.duration_sec)


## 效果段（BBCode）：效果行 + 时间行，数值上色；[param marked] 时同时标关键词（菌血句里的「中毒」）与伤害色
static func buff_body(def: BuffDef, stacks: int = 1, time_left: float = -1.0) -> String:
	var lines := buff_effect_lines(def, stacks)
	var time := buff_time_line(def, time_left)
	if time != "":
		lines.append(time)
	return mark_rich(val_numbers("\n".join(lines)), buff_terms(def))


## 效果段里能开子窗的状态词条（`terms_in` 的格式）：恢复叠层叠的那个、规则里施加的那些；不含它自己
static func buff_terms(def: BuffDef) -> Array:
	if def == null:
		return []
	var refs := {}
	buffs_in_rules(def.rules, refs)
	if def.heal_echo != &"":
		var echo := ReactionResolver.mark_buff(def.heal_echo)
		if echo != null:
			refs[echo.id] = echo
	refs.erase(def.id)
	var extra := {}
	for id in refs:
		var b: BuffDef = refs[id]
		extra[Names.of(b)] = {"id": "buff:" + String(id), "text": describe_buff(b), "style": status_style(b)}
	# 属性 / 轴名（护甲上限、格挡）用正文色不另染：只标状态词
	return terms_in("\n".join(buff_effect_lines(def, 1)), extra).filter(func(f: Dictionary) -> bool: return String(f["id"]).begins_with("buff:"))


## 悬浮窗的两块：`{"head", "body", "terms"}`（terms 是 `{id: {"name", "text"}}`，钉住后开子窗）
static func buff_tip_parts(def: BuffDef, stacks: int = 0, time_left: float = -1.0) -> Dictionary:
	var found := buff_terms(def)
	var terms := {}
	for f in found:
		terms[String(f["id"])] = {"name": f["name"], "text": f["text"]}
	return {"head": buff_head(def, stacks),
		"body": "[font_size=%d][color=%stip_fg]%s[/color][/font_size]" % [BODY_SIZE, TextTemplate.STYLE_PREFIX, buff_body(def, stacks, time_left)],
		"terms": terms}


## 一个状态的整段说明（名字行 + 效果），给子窗与只写一段字的地方。不传层数按 1 层、名字行不写 ×N
static func describe_buff(def: BuffDef, stacks: int = 0) -> String:
	if def == null:
		return ""
	return buff_head(def, stacks) + "\n" + buff_body(def, stacks)


## 机制说明（叠层、时长、计时、减半、元素印、不可解除）：**只给作者工具**（buff 制作器预览、check_content 的词条报告），玩家的窗不拼
static func buff_rule_lines(def: BuffDef) -> Array[String]:
	var lines: Array[String] = []
	if def == null:
		return lines
	lines.append("%s　%s　%s" % [buff_kind(def), "不限层" if def.is_stackable() else "不可叠层", def.duration_text()])
	if def.seconds_per_stack > 0:
		lines.append("每层持续 %d 秒" % def.seconds_per_stack)
	match def.decay_halve_on:
		BuffDef.HALVE_TICK:
			lines.append("每次生效后层数减半")
		BuffDef.HALVE_WEAPON_FIRED:
			lines.append("武器出手后层数减半")
		BuffDef.HALVE_STAMINA_PAID:
			lines.append("付耐力后层数减半")
	if def.element != &"":
		lines.append("%s元素印" % ReactionResolver.element_name(def.element))
	if def.system:
		lines.append("系统效果，不可解除")
	return lines
#endregion


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
	var out := ""
	var prev: Variant = null
	for e in effects:
		if e == null:
			continue
		var d: String = e.describe() if e.has_method("describe") else ""
		if d == "":
			d = String(ContentSchema.registry_name_of(e))
		if out != "":
			# 175 补 5.4（作者定）：造成伤害之后紧跟施加，写成一句两段「造成 X 点火焰伤害，并施加 N 层灼伤」
			out += "，并" if (prev is DealDamage or prev is FireEnchant) and e is ApplyStatus else "，"
		out += d
		prev = e
	return out if out != "" else "（没有效果）"


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


## 142：状态 id 给人看。175 补 5.4：先按状态自己的名字（中毒），没登记的状态再借同名伤害类型的名字（伤害类型「毒素」和状态「中毒」不同名了）；
## 都查不到原样返回（测试守着：道具的规则行里不出现英文 id）
static func status_name(id: StringName) -> String:
	if id == &"":
		return "?"
	var b := ReactionResolver.mark_buff(id)
	if b != null and Names.of(b) != "":
		return Names.of(b)
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
			found.append({"name": name, "text": String(names[name]["text"]), "id": String(names[name].get("id", name)), "at": at,
				"style": String(names[name].get("style", "term"))})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["at"]) < int(b["at"]) if int(a["at"]) != int(b["at"]) else String(a["name"]).length() > String(b["name"]).length())
	var out: Array = []
	for f in found:
		var entry := {"name": f["name"], "text": f["text"], "id": f["id"]}
		if String(f["style"]) != "term":
			entry["style"] = f["style"]
		out.append(entry)
	return out


## 把词条在文字里标出来：170 起是**关键词** —— `[url=term:<id>]` 包着词条色 + 下划线；悬浮窗钉住后停上去开子窗（[HoverTip]）
static func mark(text: String, terms: Array) -> String:
	var names: Array[String] = []
	var ids := {}
	var styles := {}
	for t in terms:
		var d := t as Dictionary
		names.append(String(d["name"]))
		ids[String(d["name"])] = String(d.get("id", d["name"]))
		styles[String(d["name"])] = String(d.get("style", "term"))     # 175 补 5.4：元素状态用它自己的关键词色
	return wrap_terms(text, names, func(name: String) -> String:
		return "[url=term:%s][color=%s%s][u]%s[/u][/color][/url]" % [ids[name], TextTemplate.STYLE_PREFIX, styles[name], name])


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
