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
	"自发": {"text": "不等任何事件，按自己的冷却周期反复出手 —— 武器的普通攻击都是自发的。", "tip": false, "en": {"name": "Automatic", "text": "Fires on its own cooldown, again and again, without waiting for anything. A weapon's normal attack is automatic."}},
	"开战时": {"text": "战斗开始那一瞬触发一次。", "tip": false, "en": {"name": "At battle start", "text": "Triggers once, the moment the battle begins."}},
	"出手时": {"text": "有道具出手时跟着触发（连带）。", "tip": false, "en": {"name": "On use", "text": "Triggers along with an item when that item fires (chained)."}},
	"受伤时": {"text": "受到伤害之后触发。", "tip": false, "en": {"name": "When hit", "text": "Triggers after taking damage."}},
	"层数够时": {"text": "身上某个状态叠到指定层数时触发。", "tip": false, "en": {"name": "At stacks", "text": "Triggers when a status on you reaches the given number of stacks."}},
	# 130
	"施加时": {"text": "某个状态被施加、层数增加的那一瞬触发；叠满后只刷新时长的那一下不算。默认只认自己施加的。", "tip": false, "en": {"name": "On apply", "text": "Triggers the moment a status is applied and its stacks go up. Refreshing the duration of a capped status doesn't count. By default only counts statuses you applied."}},
	"资源低于时": {"text": "生命 / 耐力等降到阈值以下时触发。", "tip": false, "en": {"name": "Below threshold", "text": "Triggers when Health, Stamina or similar drops below the threshold."}},
	"冷却": {"text": "两次出手之间的间隔（秒），急速会缩短它。", "tip": false, "en": {"name": "Cooldown", "text": "The time between two uses, in seconds. Haste shortens it."}},
	"耐力": {"text": "出手要花的资源，每秒按回复速度补回；不够就出不了手，等回够再动。", "tip": false, "en": {"name": "Stamina", "text": "What using an item costs. It refills every second at your regen rate; if you don't have enough, the item waits until you do."}},
	"耗耐力": {"text": "这一下出手要花的耐力。", "tip": false, "en": {"name": "Stamina cost", "text": "How much Stamina this use costs."}},
	"信力": {"text": "按信仰要求的行为攒的点数；过了阈值，这个信仰的道具解锁更多功能。", "tip": false, "en": {"name": "Faith", "text": "Points earned by doing what a Faith asks. Past each threshold, that Faith's items unlock more."}},
	# 129：负重
	"负重": {"text": "作战棋盘上所有东西（包本身也算）的重量之和；地上、保险箱、仓库里的不算。超过角色的负重上限就开始吃力。", "en": {"name": "Load", "text": "The total weight of everything on your battle Board, bags included. Things on the Ground, in Safes or in the Warehouse don't count. Go over your character's Load limit and you start to struggle."}},
	"吃力": {"text": "负重超过上限：急速 −10%、耐力回复 −10%。", "en": {"name": "Burdened", "text": "Load over the limit: Haste −10%, Stamina regen −10%."}},
	"超重": {"text": "负重超过上限的 1.25 倍：急速 −25%、耐力回复 −25%、耐力上限 −20%。", "en": {"name": "Overloaded", "text": "Load over 1.25 times the limit: Haste −25%, Stamina regen −25%, Max stamina −20%."}},
	"寸步难行": {"text": "负重超过上限的 1.5 倍：超重的减益照旧，地图上每走一步（传送也算）" + COUNTDOWN_WORD + " −2；原地等待不翻倍。", "en": {"name": "Immobile", "text": "Load over 1.5 times the limit: the Overloaded penalties still apply, and every step on the map (teleports too) costs Countdown −2. Waiting in place is not doubled."}},
	"地上": {"text": "棋盘之外的整块屏幕：拖出棋盘放哪就落在哪。不参战、不吃邻接、不算套装、撤离不带走；留在这个点上，回来还在原处。", "tip": false, "en": {"name": "Ground", "text": "The whole screen outside the Board: drop something off the Board and it lands where you let go. It doesn't fight, doesn't count for adjacency or sets, and isn't taken when you extract. It stays at this spot, right where you left it."}},
	# 以下都带玩家猜不到的规则（换算、结算顺序、叠层方式），照弹
	"急速": {"text": "出手速度的倍率，越高冷却越短。", "en": {"name": "Haste", "text": "A multiplier on attack speed. The higher it is, the shorter the cooldown."}},
	# 153（作者定）：防护改名格挡，只有盾牌给，几面盾只算最高的一面
	"格挡": {"text": "只有盾牌给格挡。每次受到直接伤害（武器造成的）固定减少这个数，减到零为止；带几面盾只算最高的一面，加固 / 破绽在它之上加减，破绽为负时反而多挨。buff 造成的灼烧、中毒、流血不算直接伤害，格挡挡不住。", "en": {"name": "Block", "text": "Only shields give Block. Every hit of direct damage (from weapons) is reduced by this amount, down to zero. With several shields only the highest counts; Fortified / Exposed add to or subtract from it, and if Exposed takes it below zero you take extra. Burn, Poison and Bleed from buffs are not direct damage, so Block doesn't stop them."}},
	"护甲": {"text": "先于生命被扣的一层。开战时按护甲上限充满，之后不自己回复。中毒、流血无视护甲。", "en": {"name": "Armor", "text": "A layer lost before Health. It fills to Max Armor at the start of a battle and doesn't recover on its own. Poison and Bleed ignore Armor."}},
	"直接伤害": {"text": "武器造成的伤害。格挡（加固 / 破绽）只减它；buff 造成的伤害（灼烧、中毒、流血）不是直接伤害。", "en": {"name": "Direct damage", "text": "Damage dealt by weapons. Block (Fortified / Exposed) only reduces this. Damage from buffs (Burn, Poison, Bleed) is not direct damage."}},
	"永续": {"text": "不会过期，一直到战斗结束（除非被清除）。", "en": {"name": "Permanent", "text": "Never expires; lasts until the end of the battle (unless removed)."}},
	"叠层": {"text": "同一个状态可以叠多层，效果按层数累加；没写上限就不限层。", "en": {"name": "Stacking", "text": "A status can stack many times, and its effect adds up per stack. If no cap is written, there is none."}},
	"合成": {"text": "把一件道具拖到另一件上面，两件有配方就立刻合成一件新的；装不下就到地上。", "en": {"name": "Crafting", "text": "Drag one item onto another; if the two have a recipe, they instantly craft into a new item. If it doesn't fit, it goes to the Ground."}},
	"增益槽": {"text": "这件道具的一种格位：邻居占着它，邻居就得到写着的加成。", "en": {"name": "Grant slot", "text": "A kind of cell on this item: a neighbor sitting on it gets the bonus written there."}},
	"受益槽": {"text": "这件道具的一种格位：每被邻居点亮一格，自己就得一份写着的加成。", "en": {"name": "Receive slot", "text": "A kind of cell on this item: for each one a neighbor lights up, this item gets one share of the bonus written there."}},
	"装载槽": {"text": "法杖的晶石座：放上去的魔晶石把它带的供给交给法杖。一颗晶石只给一把法杖（压着两把的给后放的那把），占了同一把的几个装载槽也只算一份。", "en": {"name": "Load slot", "text": "A staff's crystal socket: a Crystal placed on it hands its supply to the staff. One Crystal feeds only one staff (if it covers two, the one placed later), and several load slots of the same staff count once."}},
	# 107（作者定）：这两条写的是**buff**（每层每秒掉血、无视格挡与护甲），不是武器的伤害类型 —— 同名的标签
	# 「中毒」「流血」指类型，那边 tip 为 false。两边文字都保留
	"中毒": {"text": "每层每秒造成毒伤，无视格挡与护甲，永续叠层。", "en": {"name": "Poison", "text": "Deals poison damage every second per stack, ignores Block and Armor, permanent, stacks."}},
	"流血": {"text": "每层每秒造成流血伤害，无视格挡与护甲，永续叠层。", "en": {"name": "Bleed", "text": "Deals bleed damage every second per stack, ignores Block and Armor, permanent, stacks."}},
}


## 一条固定词条的说明文字（词条不存在给空）。107：`tip` 关掉的词照样取得到文字。221 F4：按当前语言取（`en` 写了用它），
## [param name] 可以是中文键，也可以是当前语言下的名字（[method term_key]）
static func term_text(name: String) -> String:
	var entry = TERMS.get(term_key(name), null)
	if entry == null:
		return ""
	if not (entry is Dictionary):
		return String(entry)
	var tr: Variant = (entry as Dictionary).get(UiText.lang, null)
	if tr is Dictionary and String((tr as Dictionary).get("text", "")) != "":
		return String(tr["text"])
	return String((entry as Dictionary).get("text", ""))


## 221 F4：固定词条在当前语言下叫什么（[param key] 是 [constant TERMS] 的中文键；没写这种语言的名字照原词）
static func term_name(key: String, lang: String = "") -> String:
	var entry = TERMS.get(key, null)
	var tr: Variant = (entry as Dictionary).get(lang if lang != "" else UiText.lang, null) if entry is Dictionary else null
	return String((tr as Dictionary).get("name", key)) if tr is Dictionary else key


## 221 F4：一个词对应哪条固定词条（中文键本身，或某种语言下的名字）；不是词条给空
static func term_key(word: String) -> String:
	if TERMS.has(word):
		return word
	for key in TERMS:
		var entry = TERMS[key]
		if entry is Dictionary:
			for lang in entry:
				if entry[lang] is Dictionary and String((entry[lang] as Dictionary).get("name", "")) == word:
					return String(key)
	return ""


## 这条固定词条要不要弹词条（107：没写按 true；词条不存在给 false）
static func term_tip(name: String) -> bool:
	var entry = TERMS.get(term_key(name), null)
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
	var words := UiText.t("gloss.damage_words") % damage_type_name(type)
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
		var words := UiText.t("gloss.damage_words") % damage_type_name(type)
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
## 250：faith / faith_anchor 两个标签删了，它们的说明改成归神道具自带的两条词条（悬浮窗信物那行写着这两个词）
const FAITH_TERMS := {
	"faith": {"zh": {"name": "信仰", "text": "信仰道具：别的信仰激活时休眠。"}, "en": {"name": "Faith", "text": "A faith item: dormant while another faith is active."}},
	"anchor": {"zh": {"name": "信物", "text": "只有信物能激活信仰：带着神的标记、又不是赐福版的那件。"}, "en": {"name": "Anchor", "text": "Only anchors activate a faith: items that carry a god's mark and are not blessed copies."}},
}


## 250：归神道具的词条（[method tag_terms] 的格式）—— 归神就有「信仰」，是信物再加「信物」
static func faith_terms(def: ItemDef) -> Dictionary:
	var out := {}
	if def == null or not def.has_faith():
		return out
	for key in (["faith", "anchor"] if def.is_anchor() else ["faith"]):
		var entry: Dictionary = FAITH_TERMS[key]
		var tr: Dictionary = entry.get(UiText.lang, entry["zh"])
		out[String(tr["name"])] = {"id": key, "text": String(tr["text"])}
	return out


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
		return UiText.t("gloss.no_effect_stat") % stat_name(m.stat)
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
	return UiText.t("hud.buff_sep").join(out)


#region 185（作者 2026-10-17 定稿）：效果悬浮窗 —— 名字行 + 现在的合计
## 玩家看到的只有两段：名字行（名字、×层数、增益 / 减益 / 系统）与效果（每条一行，写**这个状态现在的合计**）。
## 叠层、计时、减半、元素印、不可解除这些机制说明是内部说明（作者 16:07：不该给玩家看），只进 [method buff_rule_lines] 给作者工具。
## 限时状态写时间（作者 16:24）：战斗里写还剩几秒，别处写持续几秒。数值统一走 [method val] 上色（样式 `val`）

const NAME_SIZE := 20
const KIND_SIZE := 14
const BODY_SIZE := 16
## 名字描边（同 [constant UiTheme.OUTLINE_SIZE] / [constant UiTheme.OUTLINE_COLOR]；core 不引界面）
const NAME_OUTLINE := "[outline_size=2][outline_color=#000000bf]%s[/outline_color][/outline_size]"
## 系统状态（衰竭、鏖战）的名字色（同 [constant CombatantPanel.SYSTEM_COLOR]）
const SYSTEM_NAME_COLOR := "#e0b45c"

static var _num_re: RegEx = null
static var _bonus_re: RegEx = null


## 一个数值上数值色
static func val(text: String) -> String:
	return "[color=%sval]%s[/color]" % [TextTemplate.STYLE_PREFIX, text]


## 一段字里的数字（连同正负号与 %）都上数值色；方括号标签里面不动。
## 257：只给整句都是加成的地方用（状态说明、战斗栏）；信仰窗里条件和加成混在一句的走 [method bonus_numbers]
static func val_numbers(text: String) -> String:
	if _num_re == null:
		_num_re = RegEx.create_from_string("[+\\-−]?\\d+(?:\\.\\d+)?%?")
	return _paint_numbers(text, _num_re, func(m: RegExMatch) -> String: return val(m.get_string()))


## 257：信力本身（点数、阈值、信力来源的所得、献祭倍率）—— 每个数都上信力色 `@faith`
static func faith_numbers(text: String) -> String:
	if _num_re == null:
		val_numbers("")
	return _paint_numbers(text, _num_re, func(m: RegExMatch) -> String: return faith(m.get_string()))


## 257：条件与加成混在一句里（神赐、赐福道具的加成）：只有加成的数上 `@val` —— 带正负号或 × 的、「提高 / 降低 N」、「N 层」；
## 「N 信力」上 `@faith`；别的数（生命低于 30%、花 1 体力、10 秒）是条件，不上色（257 §三）
static func bonus_numbers(text: String) -> String:
	if _bonus_re == null:
		_bonus_re = RegEx.create_from_string(
			"(?<faith>\\d+(?=\\s?(?:信力|Faith)))"
			+ "|(?<![\\d.])(?:[+\\-−×]\\s?\\d+(?:\\.\\d+)?%?"
			+ "|(?<=提高 |降低 |increased by |reduced by )\\d+(?:\\.\\d+)?%?"
			+ "|\\d+(?:\\.\\d+)?(?=\\s?(?:层|stacks?\\b)))")
	return _paint_numbers(text, _bonus_re, func(m: RegExMatch) -> String:
		return faith(m.get_string()) if m.get_string("faith") != "" else val(m.get_string()))


## 一个数上信力色
static func faith(text: String) -> String:
	return "[color=%sfaith]%s[/color]" % [TextTemplate.STYLE_PREFIX, text]


## 257：悬浮窗里的两列（信仰窗的神赐 / 赐福之物 / 信力来源、道具窗的赐福小节）—— 富文本表格默认按内容收窄，
## 末尾垫一行 1 像素高的透明图把各列撑到 [param widths]，最后一列 [param right] 为真时靠右（阶号、所得、加成贴着窗的右边）。
## [param rows] 每行是各列的 BBCode
const TIP_WIDTH := 360     # = HoverTip.MAX_WIDTH（core 不引界面）
## 列之间的缝（富文本表格自带）：撑宽行少垫这么多，免得加起来比窗宽、右边被裁
const COL_SLACK := 8
const SPACER := "res://assets/ui/tip/blank.png"


static func columns(rows: Array, widths: Array[int], right: bool = true) -> String:
	var n := widths.size()
	var cells := ""
	for row in rows:
		for i in n:
			var c: String = String((row as Array)[i]) if i < (row as Array).size() else ""
			if right and i == n - 1 and c != "":
				c = "[right]%s[/right]" % c
			cells += ("[cell expand=1]%s[/cell]" if i == n - 1 and n > 1 else "[cell]%s[/cell]") % c
	for w in widths:     # 撑宽行
		cells += "[cell][font_size=1][img=%dx1]%s[/img][/font_size][/cell]" % [maxi(1, w), SPACER]
	return "[table=%d]%s[/table]" % [n, cells]


## 257：两列各要多宽 —— 按字估（[method est_width]），两列都放得下就右列刚好、左列拿剩下的；放不下就在
## 右列 25%～75% 之间挑一个让各行加起来行数最少的分法（一样少的取中间那个，两列匀一点）。[param size] 是正文字号
static func two_widths(rows: Array, size: int = BODY_SIZE, avail: int = TIP_WIDTH - COL_SLACK) -> Array[int]:
	var ests: Array[Vector2] = []
	var a := 0.0
	var b := 0.0
	for row in rows:
		var e := Vector2(est_width(String((row as Array)[0]), size), est_width(String((row as Array)[1]), size))
		ests.append(e)
		a = maxf(a, e.x)
		b = maxf(b, e.y)
	if a + b <= avail:
		return [avail - ceili(b), ceili(b)] as Array[int]
	var cands: Array[int] = []
	var best_cost := 1 << 30
	for right in range(int(avail * 0.25), int(avail * 0.75) + 1, 4):
		var cost := 0
		for e in ests:
			cost += maxi(_wrap_lines(e.x, avail - right), _wrap_lines(e.y, right))
		if cost < best_cost:
			best_cost = cost
			cands.clear()
		if cost == best_cost:
			cands.append(right)
	var best: int = cands[cands.size() >> 1]
	return [avail - best, best] as Array[int]


## 估宽 [param w] 的字放进 [param col] 宽的格子折成几行（按词折行会浪费行尾，按 85% 算）
static func _wrap_lines(w: float, col: int) -> int:
	return 1 if w <= col else ceili(w / (col * 0.85))


## 一段字大概多宽（去掉 BBCode；汉字与全角符号按一个字号，别的按 0.6 个）
static func est_width(text: String, size: int = BODY_SIZE) -> float:
	var plain := strip_bbcode(text)
	var w := 4.0 if plain != "" else 0.0     # 留一点余量，估短了会折出单独一个字
	for i in plain.length():
		w += float(size) if plain.unicode_at(i) >= 0x2E80 else float(size) * 0.6
	return w


## 方括号标签外的每处 [param re] 命中换成 [param paint] 的结果（标签里面不动）
static func _paint_numbers(text: String, re: RegEx, paint: Callable) -> String:
	var out := ""
	var at := 0
	while at < text.length():
		var open := text.find("[", at)
		var plain := text.substr(at) if open < 0 else text.substr(at, open - at)
		var last := 0
		for m in re.search_all(plain):
			out += plain.substr(last, m.get_start() - last) + String(paint.call(m))
			last = m.get_end()
		out += plain.substr(last)
		if open < 0:
			break
		var close := text.find("]", open)
		if close < 0:
			out += text.substr(open)
			break
		out += text.substr(open, close - open + 1)
		at = close + 1
	return out


## 增益 / 减益 / 系统
static func buff_kind(def: BuffDef) -> String:
	if def != null and def.system:
		return UiText.t("gloss.kind_system")
	return UiText.t("gloss.kind_debuff") if def != null and def.is_debuff else UiText.t("gloss.kind_buff")


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
	if def.heal_cut > 0 and not def.heal_cut_tags.is_empty():     # 255：只截某几类道具的治疗
		var tag_names: Array[String] = []
		for t in def.heal_cut_tags:
			tag_names.append(TagRegistry.name_of(t))
		heal.append(UiText.t("gloss.heal_cut_tags") % [UiText.t("gloss.tag_or").join(tag_names), def.heal_cut])
	elif def.heal_cut > 0:
		heal.append(UiText.t("gloss.heal_half") if def.heal_cut == 50 else UiText.t("gloss.heal_zero") if def.heal_cut >= 100 else UiText.t("gloss.heal_cut") % def.heal_cut)
	for k in def.regen_cut.keys():     # 255
		var res := resource_name(StringName(String(k)))
		var cut := int(def.regen_cut[k])
		heal.append(UiText.t("gloss.regen_cut_below") % [res, def.regen_cut_below, res, cut] if def.regen_cut_below > 0 else UiText.t("gloss.regen_cut") % [res, cut])
	if def.heal_echo != &"":
		var per := def.heal_echo_per_point
		heal.append(UiText.t("gloss.heal_echo") % status_name(def.heal_echo) if is_equal_approx(per, 1.0) else UiText.t("gloss.heal_echo_mult") % [TextTemplate.num(per), status_name(def.heal_echo)])
	if not heal.is_empty():
		heal.append_array(dmg)     # 作者原话：「恢复量归零，每秒受到 N 点火焰伤害」一句说完
		lines.append(UiText.t("gloss.clause_sep").join(heal))
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
		lines.append(UiText.t("gloss.damage_taken") % [damage_type_name(StringName(String(k))), TextTemplate.num(float(def.damage_taken_by_type[k]) * n)])
	var pct := TextTemplate.num(def.per_stack_percent * n)
	match def.decay_halve_on:
		BuffDef.HALVE_WEAPON_FIRED:
			lines.append(UiText.t("gloss.next_fire_cooldown") % pct)
		BuffDef.HALVE_STAMINA_PAID:
			lines.append(UiText.t("gloss.next_stamina_cost") % pct)
	if not def.on_apply.is_empty():
		lines.append(UiText.t("gloss.on_apply") % effects_text(def.on_apply))
	if not def.on_expire.is_empty():
		lines.append(UiText.t("gloss.on_expire") % effects_text(def.on_expire))
	return lines


## 按层对自己的定时伤害（中毒、流血、灼伤、燃血）：「每秒受到 5 点毒素伤害」；不是这种规则返回空
static func _self_damage_text(rule: AbilityRule, n: int) -> String:
	if not _scheduled(rule) or rule.effects.size() != 1:
		return ""
	var d := rule.effects[0] as DealDamage
	if d == null or d.target != CombatEffect.Target.SELF or not d.per_stack or d.percent_of != &"":
		return ""
	var secs := (rule.cadence as CooldownCadence).seconds
	var key := "gloss.self_damage_per_sec" if is_equal_approx(secs, 1.0) else "gloss.self_damage_every"
	return UiText.t(key).format({"s": TextTemplate.num(secs), "n": TextTemplate.num(d.amount * n), "t": damage_type_name(d.damage_type)})


## 时间那一行：[param time_left] ≥ 0（战斗里，回放时刻）写「还剩 N 秒」；< 0 写定义里的时长；永续的没有
static func buff_time_line(def: BuffDef, time_left: float = -1.0) -> String:
	if def == null:
		return ""
	if time_left >= 0.0:
		return UiText.t("gloss.time_left") % ceili(time_left)
	if def.seconds_per_stack > 0 and def.is_stackable():
		return UiText.t("gloss.time_per_stack") % def.seconds_per_stack
	return "" if def.is_permanent() else UiText.t("gloss.time_lasts") % TextTemplate.num(def.duration_sec)


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
			line += cad + UiText.t("gloss.clause_sep")
	var bits: Array[String] = []
	var costs := costs_text(rule, skip_stamina)
	if costs != "":
		bits.append(costs)
	bits.append(effects_text(rule.effects))
	return line + cap(UiText.t("gloss.clause_sep").join(bits))


## 221 F5：英文句首大写（中文原样）
static func cap(text: String) -> String:
	if UiText.lang == "zh" or text == "":
		return text
	return text.left(1).to_upper() + text.substr(1)


## 自发且有冷却：方括号里直接写「每 N 秒」
static func _scheduled(rule: AbilityRule) -> bool:
	return rule.trigger is OnSchedule and rule.cadence is CooldownCadence


## 145：节奏那半句。自发的「每 N 秒」，别的扳机带冷却「每 N 秒最多一次」，没冷却为空
static func cadence_text(rule: AbilityRule) -> String:
	var cd := rule.cadence as CooldownCadence
	if cd == null:
		return ""
	return UiText.t("gloss.every_sec" if _scheduled(rule) else "gloss.every_sec_max_once") % cd.seconds


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
	return UiText.t("gloss.clause_sep").join(bits)


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
			out += UiText.t("gloss.and_then") if (prev is DealDamage or prev is FireEnchant) and e is ApplyStatus else UiText.t("gloss.clause_sep")
		out += d
		prev = e
	return out if out != "" else UiText.t("gloss.no_effect")


const TRIGGER_NAMES := {"on_schedule": {"zh": "自发", "en": "Automatic"}, "on_battle_start": {"zh": "开战时", "en": "At battle start"},
	"on_item_fired": {"zh": "出手时", "en": "On attack"}, "on_damage": {"zh": "受伤时", "en": "When hit"},
	"on_before_damage": {"zh": "受伤前", "en": "Before damage"}, "on_stacks_at_least": {"zh": "层数够时", "en": "At enough stacks"},
	"on_resource_below": {"zh": "资源低于时", "en": "When a resource runs low"},
	"on_status_applied": {"zh": "施加时", "en": "On apply"}, "on_status_removed": {"zh": "状态掉光时", "en": "When a status runs out"},
	"on_overtime": {"zh": "加时开始时", "en": "When overtime starts"}}


## 时机的类别名（百科「时机」那一页的词条用）：自发 / 开战时 / 施加时……
static func trigger_name(trigger: Trigger) -> String:
	if trigger == null:
		return ""
	var key := String(ContentSchema.registry_name_of(trigger))
	return trigger_key_name(key)


## 221 F5：时机类别名按语言取（百科「时机」页也用）
static func trigger_key_name(key: String) -> String:
	return UiText.pick(TRIGGER_NAMES.get(key, null), key)


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
	for key in TERMS:
		var name := term_name(String(key))     # 221 F4：英文正文里认英文名，id 还是中文键
		if not names.has(name) and term_tip(key):     # 107：tip 关掉的词不弹，也因此不被 mark 标出
			names[name] = {"id": key, "text": term_text(key)}
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
