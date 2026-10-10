## JSON → 引擎资源（架构文档 10.2）。
##
## [b]本类不认识任何一种具体效果。[/b] 它只做三件事：
##
## 1. 问 Godot 目标类有哪些属性、各是什么类型（[ContentSchema]）；
## 2. 碰到抽象基类就按 JSON 里的 `type` 去 [ContentRegistries] 查；
## 3. 严格校验，有错就一个资产都不产出。
##
## 因此新增一种时机／频率／消耗／效果，这个文件一行都不用改。
##
## 只有三处例外，都是「JSON 里的写法和资源结构本来就不同构」，各自注明了理由：
## 形状（0/1 数字串）、增益引用（按 id）、以及 combat.rules 的糖。
class_name ContentImporter
extends RefCounted


## 导入过程中的共享上下文：先导入的东西，后面的可以按 id 引用。
class Context:
	extends RefCounted
	## id -> BuffDef
	var buffs: Dictionary = {}
	## id -> ItemDef。敌人的招牌道具与流派标签对着它查
	var items: Dictionary = {}
	## id -> EnemyDef。池的条目对着它查
	var enemies: Dictionary = {}
	## id -> EnemyPool。章节对着它查
	var pools: Dictionary = {}
	## id -> DropRule。章节对着它查
	var drop_rules: Dictionary = {}
	## 126：id -> CarryRule。章节对着它查
	var carry_rules: Dictionary = {}
	## 129：id -> EncumbranceRules。章节对着它查
	var encumbrance_rules: Dictionary = {}
	## id -> NodeRules。章节对着它查
	var node_rules: Dictionary = {}
	## id -> EconomyRules。章节对着它查
	var economy_rules: Dictionary = {}
	## id -> LoadoutDef
	var loadouts: Dictionary = {}
	## 096：id -> TagDef。道具的标签对着它提醒（没登记只是警告）
	var tags: Dictionary = {}

	## 按 id 登记；没有 id 的（导入已报错）不进表。下面那排 register_* 只是带类型的入口
	func _put(table: Dictionary, def) -> void:
		if def != null and def.id != &"":
			table[def.id] = def

	func register_tag(def: TagDef) -> void:
		_put(tags, def)

	func register_buff(def: BuffDef) -> void:
		_put(buffs, def)

	## 146：id -> RulePartDef。规则里的 `"@id"` 对着它查
	var rule_parts: Dictionary = {}

	func register_rule_part(def: RulePartDef) -> void:
		_put(rule_parts, def)

	## 146：批量导入（import_content / normalize_content）设 true —— 只认这一趟登记过的 buff 与构件。
	## 默认 false：单件导入（编辑器、测试读一份真实道具）登记表里没有的，到盘上的库（[ContentLibrary]）里找
	var strict: bool = false

	func find_buff(id: StringName) -> BuffDef:
		var def: BuffDef = buffs.get(id, null)
		if def == null and not strict:
			def = ContentLibrary.buffs().get(id, null)
		return def

	func find_rule_part(id: StringName) -> RulePartDef:
		var def: RulePartDef = rule_parts.get(id, null)
		if def == null and not strict:
			def = ContentLibrary.part(id)
		return def

	## 146：正在填 buff / 构件的第几层（>0 时规则里不许再引用构件：buff 的规则请内联；构件不套构件）
	var buff_depth: int = 0
	var part_depth: int = 0

	func register_item(def: ItemDef) -> void:
		_put(items, def)

	func register_enemy(def: EnemyDef) -> void:
		_put(enemies, def)

	func register_pool(pool: EnemyPool) -> void:
		_put(pools, pool)

	func register_encumbrance_rules(rules: EncumbranceRules) -> void:
		_put(encumbrance_rules, rules)

	func register_carry_rule(rule: CarryRule) -> void:
		_put(carry_rules, rule)

	func register_drop_rule(rule: DropRule) -> void:
		_put(drop_rules, rule)

	func register_node_rules(rules: NodeRules) -> void:
		_put(node_rules, rules)

	func register_economy_rules(rules: EconomyRules) -> void:
		_put(economy_rules, rules)

	func register_loadout(def: LoadoutDef) -> void:
		_put(loadouts, def)

	## id -> CharacterDef
	var characters: Dictionary = {}

	func register_character(def: CharacterDef) -> void:
		_put(characters, def)

	## id -> DifficultyDef
	var difficulties: Dictionary = {}

	func register_difficulty(def: DifficultyDef) -> void:
		_put(difficulties, def)

	## id -> HunterDef
	var hunters: Dictionary = {}

	func register_hunter(def: HunterDef) -> void:
		_put(hunters, def)

	## id -> MetaRules
	var meta_rules: Dictionary = {}

	func register_meta_rules(rules: MetaRules) -> void:
		_put(meta_rules, rules)

	## id -> FaithDef（8-4）。道具的信仰对象标签对着它查
	var faiths: Dictionary = {}

	func register_faith(def: FaithDef) -> void:
		_put(faiths, def)

	## id -> RunBuffDef
	var run_buffs: Dictionary = {}

	func register_run_buff(def: RunBuffDef) -> void:
		_put(run_buffs, def)

	## id -> EventDef。节点规则对着它查
	var events: Dictionary = {}

	func register_event(def: EventDef) -> void:
		_put(events, def)

	## id -> HelpPageDef（114）。「相关」对着它查
	var help_pages: Dictionary = {}

	func register_help_page(def: HelpPageDef) -> void:
		_put(help_pages, def)

	## id -> TechDef（118）。树（前置、成环、撞位）全部导完才查得全
	var techs: Dictionary = {}

	func register_tech(def: TechDef) -> void:
		_put(techs, def)

	## id -> AchievementDef（091）
	var achievements: Dictionary = {}

	func register_achievement(def: AchievementDef) -> void:
		_put(achievements, def)

	## 道具里带某个标签的有几件。批量导入时才有意义 —— 单独导一个敌人时上下文是空的，
	## 这类「对着别的东西查」的校验就跳过（见 _validate_enemy）
	func items_tagged(tag: StringName) -> int:
		var n := 0
		for id in items:
			if (items[id] as ItemDef).tags.has(tag):
				n += 1
		return n


## 25 种内容都先查这一条。返回有没有 id，好让调用方把「id 格式」的检查接在后面
static func _require_id(id: StringName, what: String, report: ImportReport) -> bool:
	if id == &"":
		report.error("id", what + "必须有 id")
		return false
	return true


#region 顶层入口
## 按种类分派到各导入函数。`tools/import_content.gd` 与 `tools/normalize_content.gd` 共用这一张表 ——
## 加一种内容就在这儿接一臂（种类名与 [constant ContentPaths.KINDS] 一致）。不认识的种类报错并返回 null
static func import_of(kind: String, data: Dictionary, ctx: Context, report: ImportReport) -> Resource:
	match kind:
		"tags":
			return import_tag(data, ctx, report)
		"damage_types":
			return import_damage_type(data, ctx, report)
		"buffs":
			return import_buff(data, ctx, report)
		"rule_parts":
			return import_rule_part(data, ctx, report)
		"sets":
			return import_set(data, ctx, report)
		"enemies":
			return import_enemy(data, ctx, report)
		"enemy_pools":
			return import_enemy_pool(data, ctx, report)
		"drop_rules":
			return import_drop_rule(data, ctx, report)
		"carry_rules":
			return import_carry_rule(data, ctx, report)
		"encumbrance_rules":
			return import_encumbrance_rules(data, ctx, report)
		"node_rules":
			return import_node_rules(data, ctx, report)
		"economy_rules":
			return import_economy_rules(data, ctx, report)
		"loadouts":
			return import_loadout(data, ctx, report)
		"characters":
			return import_character(data, ctx, report)
		"difficulties":
			return import_difficulty(data, ctx, report)
		"hunters":
			return import_hunter(data, ctx, report)
		"meta_rules":
			return import_meta_rules(data, ctx, report)
		"run_buffs":
			return import_run_buff(data, ctx, report)
		"faiths":
			return import_faith(data, ctx, report)
		"recipes":
			return import_recipe(data, ctx, report)
		"events":
			return import_event(data, ctx, report)
		"chapters":
			return import_chapter(data, ctx, report)
		"achievements":
			return import_achievement(data, ctx, report)
		"techs":
			return import_tech(data, ctx, report)
		"help_pages":
			return import_help_page(data, ctx, report)
		"items":
			return import_item(data, ctx, report)
		_:
			report.error("", "不认识的内容种类 '%s'（登记在 ContentPaths.KINDS，并在 ContentImporter.import_of 接一臂）" % kind)
			return null


static func import_buff(data: Dictionary, ctx: Context, report: ImportReport) -> BuffDef:
	var def := BuffDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "增益", report)
	validate_buff_duration(def, "", report)
	warn_axis_candidate(def, "", report)
	ctx.register_buff(def)
	return def


## 146：规则构件库里的一份。四类里正好填一个
static func import_rule_part(data: Dictionary, ctx: Context, report: ImportReport) -> RulePartDef:
	var def := RulePartDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "规则构件", report)
	if def.filled() != 1:
		report.error("", "一份构件只填扳机 / 节奏 / 消耗 / 效果中的一个（现在填了 %d 个）" % def.filled())
	ctx.register_rule_part(def)
	return def


## 146：规则里的 `"@id"` —— 到库里找那份构件，复制一份打上 `part_ref`。类不对（把扳机填进效果）、
## 在 buff 的规则里、在构件里面都报错
static func _resolve_part(class_id: StringName, id: String, path: String, ctx: Context, report: ImportReport) -> Object:
	if ctx.buff_depth > 0:
		report.error(path, "buff 的规则请内联，不能引用规则构件（@%s）" % id)
		return null
	if ctx.part_depth > 0:
		report.error(path, "构件里不能再引用构件（@%s）" % id)
		return null
	var def := ctx.find_rule_part(StringName(id))
	if def == null:
		report.error(path, "找不到规则构件 '@%s'（data/authoring/rule_parts）" % id)
		return null
	if def.root() != class_id:
		report.error(path, "规则构件 '@%s' 是 %s，这里要的是 %s" % [id, def.root(), class_id])
		return null
	return ContentLibrary.instance_of(def)


## 作者定的规矩（085）：可叠层的 buff 永续，不许填时长；不可叠层的才可以过期
static func validate_buff_duration(def: BuffDef, path: String, report: ImportReport) -> void:
	if def != null and def.is_stackable() and def.duration_sec > 0.0:
		report.error(path + "duration_sec", "「%s」可叠层，可叠层的 buff 永续，不填时长（要会过期就写 stackable: false）" % def.id)


## 道具里内联的 buff（apply_status.buff）也按同一条规矩查
static func _validate_item_buffs(def: ItemDef, report: ImportReport) -> void:
	if def.combat == null:
		return
	for i in def.combat.rules.size():
		var rule := def.combat.rules[i] as AbilityRule
		if rule == null:
			continue
		for j in rule.effects.size():
			var e := rule.effects[j] as ApplyStatus
			if e != null and e.buff != null:
				validate_buff_duration(e.buff, "combat.rules[%d].effects[%d].buff." % [i, j], report)
				warn_axis_candidate(e.buff, "combat.rules[%d].effects[%d].buff." % [i, j], report)


## 107（作者定）：**毒与流血没有「直接伤害」形态** —— 它们天生就是 buff（每层每秒掉血、无视护盾与防护），
## 武器顶多给对手加【中毒】/【流血】。所以道具自己的出手规则（以及信力规则）里不许出现 `poison` / `bleed` 的 deal_damage；
## buff 内部的那条照旧（内容里毒刀、毒瓶、弯刀、剁刀都是这样写的）
const BUFF_ONLY_DAMAGE: Array[StringName] = [&"poison", &"bleed"]


## 道具里所有装规则的地方：[路径, 规则数组]。下面四条校验遍历的是同一组 —— 加一种规则容器只改这里
static func _rule_groups(def: ItemDef) -> Array:
	var groups: Array = []
	if def.combat != null:
		groups.append(["combat.rules", def.combat.rules])
	for k in def.faith_bonuses.size():
		var fb := def.faith_bonuses[k] as FaithBonus
		if fb != null:
			groups.append(["faith_bonuses[%d].rules" % k, fb.rules])
	if def.adjacency != null:
		groups.append(["adjacency.grant_rules", def.adjacency.grant_rules])     # 108：附加规则同样适用
		groups.append(["adjacency.receive_rules", def.adjacency.receive_rules])     # 132
		groups.append(["adjacency.feed_rules", def.adjacency.feed_rules])     # 148
	return groups


static func _validate_buff_only_damage(def: ItemDef, report: ImportReport) -> void:
	for g in _rule_groups(def):
		var rules: Array = g[1]
		for i in rules.size():
			var rule := rules[i] as AbilityRule
			if rule == null:
				continue
			for j in rule.effects.size():
				var dd := rule.effects[j] as DealDamage
				if dd != null and BUFF_ONLY_DAMAGE.has(dd.damage_type):
					report.error("%s[%d].effects[%d].damage_type" % [g[0], i, j],
						"「%s」直接打出 %s 伤害 —— 毒与流血没有直接伤害形态，只能由 buff 每秒造成（用 apply_status 加【中毒】/【流血】）" % [def.id, dd.damage_type])


## 130：状态联动的两条死路，导入器拦下 ——
## 「转化」不许转成自己（`convert_status.to` 就是 `from`）；「某状态被施加时」的规则不许再施加同一个状态（含转化成它）：
## 本方施加 X → 触发 → 又施加 X → 又触发……一直连锁到派发上限被截断
static func _validate_status_loops(def: ItemDef, report: ImportReport) -> void:
	for g in _rule_groups(def):
		validate_status_loops(g[1], g[0], report)


static func validate_status_loops(rules: Array, path: String, report: ImportReport) -> void:
	for i in rules.size():
		var rule := rules[i] as AbilityRule
		if rule == null:
			continue
		var listen := rule.trigger as OnStatusApplied
		for j in rule.effects.size():
			var at := "%s[%d].effects[%d]" % [path, i, j]
			var e = rule.effects[j]
			var gives: StringName = &""
			if e is ConvertStatus:
				var cv := e as ConvertStatus
				if cv.to != null and cv.to.id == cv.from:
					report.error(at + ".to", "「转化状态」把 %s 转成它自己 —— to 不能是 from" % cv.from)
				gives = cv.to.id if cv.to != null else &""
			elif e is ApplyStatus and (e as ApplyStatus).buff != null:
				gives = (e as ApplyStatus).buff.id
			if listen != null and gives != &"" and gives == listen.buff_id:
				report.error(at, "「%s被施加时」又施加 %s —— 自己点燃自己，会一直连锁到派发上限" % [listen.buff_id, gives])


## 132：规则的「配了也没用」与各构件自己的校验。
## 警告（不拦）：改写伤害包的效果不在受伤前；`per_stack` 写在道具自己的规则里（只有 buff 规则与「施加时」才有层数可读）；
## 自发配 always；按伤害比例的回复不在受伤后；「只在暴击时」配受到。错误：比例伤害没填比例、资源条件一个界都没填、
## 轴不存在、改伤害类型改成不存在的或毒 / 血
const PACKET_EFFECTS := ["ModifyDamage", "ReflectDamage", "LowHpEmpower", "ConvertDamageType"]


static func _validate_rule_shapes(def: ItemDef, ctx: Context, report: ImportReport) -> void:
	for g in _rule_groups(def):
		validate_rule_shapes(g[1], g[0], report, true, ctx)


static func validate_rule_shapes(rules: Array, path: String, report: ImportReport, item_level: bool, ctx: Context = null, depth: int = 0) -> void:
	for i in rules.size():
		var rule := rules[i] as AbilityRule
		if rule == null:
			continue
		var at := "%s[%d]" % [path, i]
		if rule.trigger is OnSchedule and rule.cadence is Always:
			report.warn(at + ".cadence", "自发配「每次都行」：没有冷却就排不出下一次出手，改成 cooldown")
		if rule.trigger is OnDamage and (rule.trigger as OnDamage).crit_only \
				and (rule.trigger as OnDamage).direction == DamageTrigger.Direction.TAKEN:
			report.warn(at + ".trigger.crit_only", "「只在暴击时」配「受到」：暴击旗说的是这一下是不是暴击，挨打一方一般不该听它，确认一下")
		if rule.trigger is OnItemFired and ctx != null and not ctx.tags.is_empty():
			for tag in (rule.trigger as OnItemFired).source_tags:
				if not ctx.tags.has(tag):
					report.warn(at + ".trigger.source_tags", "没有登记的标签 '%s'：确认没拼错" % tag)
		for c in rule.costs:
			if c is ResourceCondition and not (c as ResourceCondition).has_bounds():
				report.error(at + ".costs", "资源条件一个界都没填（min_percent / max_percent / absolute_min / absolute_max 至少一个）")
			if c is AxisCondition and not StatAxes.has((c as AxisCondition).axis):
				report.error(at + ".costs", "没有这条标准轴：%s" % (c as AxisCondition).axis)
			if c is AxisCost and not StatAxes.has((c as AxisCost).axis):
				report.error(at + ".costs", "没有这条标准轴：%s" % (c as AxisCost).axis)
		for j in rule.effects.size():
			var e = rule.effects[j]
			var eat := "%s.effects[%d]" % [at, j]
			var cls := RegistryLookup.class_of(e, false)
			if PACKET_EFFECTS.has(cls) and not (rule.trigger is OnBeforeDamage):
				report.warn(eat, "%s 只在受伤前阶段有效，这条规则的时机不是 on_before_damage，触发了也改不到伤害" % cls)
			if item_level and not (rule.trigger is OnStatusApplied) and _effect_per_stack(e):
				report.warn(eat + ".per_stack", "per_stack 读的是来源 buff 的层数，写在道具自己的规则里恒为 1（只有 buff 的规则与「施加时」读得到层数）")
			if e is ChangeResource and (e as ChangeResource).percent_of_damage > 0 and not (rule.trigger is OnDamage):
				report.warn(eat + ".percent_of_damage", "按伤害比例回复只在受伤后（on_damage）有那一包伤害，别的时机这部分恒为 0")
			if e is DealDamage and (e as DealDamage).percent_of != &"":
				var dd := e as DealDamage
				if not DealDamage.PERCENT_OF.has(dd.percent_of):
					report.error(eat + ".percent_of", "percent_of 只能是 max_hp / current_hp / missing_hp")
				elif dd.percent <= 0:
					report.error(eat + ".percent", "填了 percent_of 就得填 percent（> 0）")
			if e is ConvertDamageType:
				var to := (e as ConvertDamageType).to
				if BUFF_ONLY_DAMAGE.has(to):
					report.error(eat + ".to", "不能改成 %s —— 毒与流血只由 buff 造成" % to)
				elif to == &"" or not DamageTypes.has(to):
					report.error(eat + ".to", "没有这种伤害类型：%s" % to)
			if e is ApplyStatus and (e as ApplyStatus).buff != null and depth < 3:     # buff 的规则可以再施加 buff：限深，防自引用
				validate_rule_shapes((e as ApplyStatus).buff.rules, eat + ".buff.rules", report, false, ctx, depth + 1)


static func _effect_per_stack(e) -> bool:
	return (e is DealDamage and (e as DealDamage).per_stack) or (e is ChangeResource and (e as ChangeResource).per_stack) \
		or (e is ApplyStatus and (e as ApplyStatus).per_stack) or (e is ShiftAxis and (e as ShiftAxis).per_stack)


## 108（作者定）：附加规则（增益格挂给邻居的 `grant_rules`）的意义是「宿主出手时附带」，所以
## 触发器必须是 `on_item_fired`（受伤 / 开战这类时机写在道具自己身上）；不许有 costs（宿主出手已经付过耐力，附带不二次扣）；
## 必须有频率（建议 always，写冷却也行：「每 3 秒最多附带一次」）。直接毒伤 / 流血伤由 [method _validate_buff_only_damage] 一并拦
## 132：[param strict] = false 是受益规则（`receive_rules`）—— 跑在本件身上，时机不限，只保留「不许 costs」与「要有频率」
static func validate_attached_rules(rules: Array, path: String, report: ImportReport, strict: bool = true) -> void:
	for i in rules.size():
		var rule := rules[i] as AbilityRule
		var at := "%s[%d]" % [path, i]
		if rule == null:
			report.error(at, "空的附加规则")
			continue
		if strict and not (rule.trigger is OnItemFired):
			report.error(at + ".trigger", "附加规则听的是宿主出手（on_item_fired）；受伤 / 开战这类时机写在道具自己身上")
		if not rule.costs.is_empty():
			report.error(at + ".costs", "附加规则不能有消耗 —— 宿主出手已经付过耐力，附带的不再二次扣")
		if rule.cadence == null:
			report.error(at + ".cadence", "规则必须有频率（附加规则一般写 always）")
		if rule.effects.is_empty():
			report.warn(at + ".effects", "附加规则没有任何效果")


## 103 4e：能用标准轴表达的简单增减一律走轴 —— 只有一条落在轴属性上的 mod、没有规则的可叠层 buff，提示改成 shift_axis
static func warn_axis_candidate(def: BuffDef, path: String, report: ImportReport) -> void:
	if def == null:
		return
	for i in def.axes.size():     # 152：带的轴得是轴表里有的
		var a := def.axes[i] as BuffAxis
		if a != null and not StatAxes.has(a.axis):
			report.error("%saxes[%d].axis" % [path, i], "没有这条标准轴 '%s'（可用：%s）" % [a.axis, ", ".join(StatAxes.ORDER)])
		elif a != null and a.stacks == 0:
			report.warn("%saxes[%d].stacks" % [path, i], "「%s」带 0 层 %s，这条不起作用" % [def.id, a.axis])
	if def.is_stackable() and def.mods.size() == 1 and def.axes.is_empty() and def.rules.is_empty() \
			and def.on_apply.is_empty() and def.on_expire.is_empty():
		var only := StatAxes.axis_for_stat((def.mods[0] as StatModifier).stat)
		if only != &"":
			report.warn(path + "mods", "「%s」只是一条 %s 的增减，改用标准轴：shift_axis(%s)（增益正、减益负，直接相抵）" % [def.id, (def.mods[0] as StatModifier).stat, only])
			return
	# 152（作者定）：buff 里落在标准轴上的增减，改成「每层带几层轴」（axes），不直接写百分比 / 固定值
	for i in def.mods.size():
		var m := def.mods[i] as StatModifier
		var axis := StatAxes.axis_for_stat(m.stat) if m != null else &""
		if axis != &"" and axis != StatAxes.ARMOR:     # 防护（格挡）另有方案，先不提醒
			report.warn("%smods[%d]" % [path, i], "「%s」的 %s 增减落在标准轴上：改写成 axes —— 每层带几层【%s】（152）" % [
				def.id, m.stat, StatAxes.name_of(axis, 1 if m.amount >= 0.0 else -1)])


## 103 第 1、2 条（作者定）：带武器标签的道具必须造成伤害；只有带武器标签的道具才消耗耐力。
## 「造成伤害」只认道具自己规则里直接的 deal_damage —— 施加会掉血的 buff 是施毒，不算；
## 反过来不限：不带武器标签的也可以造成伤害，武器也可以不耗耐力
static func _validate_item_combat(def: ItemDef, report: ImportReport) -> void:
	var is_weapon := def.tags.has(&"weapon")
	var deals_damage := false
	if def.combat != null:
		for r in def.combat.rules:
			var rule := r as AbilityRule
			if rule == null:
				continue
			for e in rule.effects:
				if e is DealDamage:
					deals_damage = true
	if is_weapon and not deals_damage:
		report.error("tags", "「%s」带武器标签却不造成伤害 —— 武器至少要有一条直接造成伤害的规则" % def.id)
	if is_weapon:
		return
	for g in _rule_groups(def):
		var rules: Array = g[1]
		for i in rules.size():
			var rule := rules[i] as AbilityRule
			if rule == null:
				continue
			for c in rule.effective_costs():
				var rc := c as ResourceCost
				if rc != null and rc.resource_key == &"stamina":
					report.error("%s[%d].costs" % [g[0], i], "「%s」不带武器标签却消耗耐力 —— 耐力只归武器" % def.id)


static func import_set(data: Dictionary, ctx: Context, report: ImportReport) -> ItemSetDef:
	var def := ItemSetDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "套装", report)
	if def.tiers.is_empty():
		report.warn("tiers", "套装没有任何档位，永远不会生效")
	return def


static func import_item(data: Dictionary, ctx: Context, report: ImportReport) -> ItemDef:
	var def := ItemDef.new()
	_fill(def, data, "", ctx, report)
	_validate_item(def, report)
	_validate_item_tags(def, ctx, report)
	_validate_item_faith(def, ctx, report)
	_validate_item_buffs(def, report)
	_validate_buff_only_damage(def, report)
	_validate_item_combat(def, report)
	_validate_status_loops(def, report)
	_validate_rule_shapes(def, ctx, report)
	_validate_power(def, ctx, report)
	ctx.register_item(def)
	return def


## 151（待定 5 按推荐）：武器的稀有度和战斗力估算推荐的差两档以上才提醒（流派件单看偏弱是故意的，差一档正常）。只提醒、不拦
static var _power_weights: PowerWeights = null


static func _validate_power(def: ItemDef, ctx: Context, report: ImportReport) -> void:
	if not def.tags.has(&"weapon") or def.combat == null or def.combat.rules.is_empty():
		return
	if _power_weights == null:
		_power_weights = PowerWeights.load_from()
	var est := PowerEstimate.estimate(def, _power_weights, ctx.buffs)
	if est.rarity >= 0 and absi(est.rarity - def.rarity) >= 2:
		report.warn("rarity", "稀有度 %d 和战斗力估算推荐的 %d 差两档以上（战斗力 %.1f，格数预算比 %.2f）：改数值或改 data/authoring/balance/power_weights.json（151）" % [
			def.rarity, est.rarity, est.power, est.ratio])


## 122：材料的出身标签，三选一（作者补正：魔晶石等魔法类不算自然也不算工艺，归【魔法】）
const MATERIAL_ORIGINS: Array[StringName] = [&"crafted", &"nature", &"magic"]


## 096：标签是内容 —— 没登记的标签不是错（随手加的词照样能用），但提醒一句：登记了才有名字、别的语言和词条
static func _validate_item_tags(def: ItemDef, ctx: Context, report: ImportReport) -> void:
	if ctx.tags.is_empty():
		return
	for t in def.tags:
		if String(t).begins_with(FaithTags.PREFIX):
			continue
		if not ctx.tags.has(t):
			report.warn("tags", "没有登记的标签 '%s'：界面上只能显示原词（在 data/authoring/tags 里加一份就有名字与说明）" % t)
	# 122：材料按出身分【工艺】/【自然】/【魔法】—— 必有一个、只能有一个（提醒，不拦；和「标签未登记」同级）
	if def.tags.has(&"material"):
		var kinds := 0
		for k in MATERIAL_ORIGINS:
			if def.tags.has(k):
				kinds += 1
		if kinds != 1:
			report.warn("tags", "材料得在 %s 里恰好带一个（人造 / 取自自然 / 魔法），现在带了 %d 个" % [" / ".join(PackedStringArray(MATERIAL_ORIGINS)), kinds])


## 096：标签定义 —— 得有 id 与名字
static func import_tag(data: Dictionary, ctx: Context, report: ImportReport) -> TagDef:
	var def := TagDef.new()
	_fill(def, data, "", ctx, report)
	if _require_id(def.id, "标签", report) and (String(def.id).contains(":") or String(def.id).contains(" ")):
		report.error("id", "标签 id 里别带冒号或空格（`faith:<id>` 这类动态标签不用登记）")
	if def.display_name.strip_edges() == "":
		report.error("display_name", "标签得有名字（没名字就不用登记）")
	for k in def.display_names:
		if not (def.display_names[k] is String):
			report.error("display_names", "'%s' 的值得是文字" % k)
	ctx.register_tag(def)
	return def


## 096：伤害类型定义 —— 得有 id 与名字；三个性质是布尔，反射填错了导入器之前就拦
static func import_damage_type(data: Dictionary, ctx: Context, report: ImportReport) -> DamageTypeDef:
	var def := DamageTypeDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "伤害类型", report)
	if def.display_name.strip_edges() == "":
		report.error("display_name", "伤害类型得有名字")
	return def


## 信仰体系（8-4，报告 081）
## 合成配方（084）：恰好两件输入、一件产物，都得是道具库里有的（批量导入时道具在前，查得到）
static func import_recipe(data: Dictionary, ctx: Context, report: ImportReport) -> RecipeDef:
	var def := RecipeDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "配方", report)
	if def.inputs.size() != 2:
		report.error("inputs", "配方是两件合一件：inputs 得恰好两个")
	if def.output == &"":
		report.error("output", "配方得有产物")
	for i in def.inputs.size():
		if not ctx.items.is_empty() and not ctx.items.has(def.inputs[i]):
			report.error("inputs[%d]" % i, "道具库里没有 %s" % def.inputs[i])
	if not ctx.items.is_empty() and def.output != &"" and not ctx.items.has(def.output):
		report.error("output", "道具库里没有 %s" % def.output)
	return def


static func import_faith(data: Dictionary, ctx: Context, report: ImportReport) -> FaithDef:
	var def := FaithDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "信仰", report)
	if String(def.id).begins_with(FaithTags.PREFIX) or String(def.id).contains(":"):
		report.error("id", "id 里别带前缀或冒号：道具上的标签会自动写成 %s<id>" % FaithTags.PREFIX)
	if def.display_name.strip_edges() == "":
		report.error("display_name", "信仰得有名字")
	# 信力（082）：阈值正数、非递减；行为非空、点数正
	for i in def.thresholds.size():
		if def.thresholds[i] < 1:
			report.error("thresholds[%d]" % i, "阈值得是正数")
		elif i > 0 and def.thresholds[i] < def.thresholds[i - 1]:
			report.error("thresholds[%d]" % i, "阈值得非递减")
	for i in def.deeds.size():
		var d := def.deeds[i] as FaithDeed
		if d == null:
			report.error("deeds[%d]" % i, "空的行为")
		elif d.amount < 1:
			report.error("deeds[%d].amount" % i, "每次至少给 1 点")
	ctx.register_faith(def)
	return def


## 104（作者定，架构文档 3.8）：每位神的信物里必然有一枚 **1 格护符** —— 批量导入完了检查：每个诸神信仰
## 至少有一件 1 格、带 `faith_anchor` 的道具（新教是占位，不查）。只在上下文里道具与信仰都有时查
static func validate_faith_charms(ctx: Context, report: ImportReport) -> void:
	if ctx.items.is_empty() or ctx.faiths.is_empty():
		return
	for fid in ctx.faiths:
		var faith := ctx.faiths[fid] as FaithDef
		if faith == null or faith.camp == FaithDef.Camp.CHURCH:
			continue
		var found := false
		for iid in ctx.items:
			var item := ctx.items[iid] as ItemDef
			if item != null and item.is_anchor() and item.faith_tag() == faith.tag() and ItemVolume.cells_of(item) == 1:
				found = true
				break
		if not found:
			report.error("faiths/%s" % fid, "%s 没有 1 格的信物护符（带 faith、%s、faith_anchor 的 1 格道具）—— 每位神的信物必然包含一枚" % [faith.display_name, faith.tag()])


## 信仰标签（作者定的机制）：信仰道具带 `faith` + 恰好一个 `faith:<id>`；对象标签得是登记过的信仰（批量导入时）
static func _validate_item_faith(def: ItemDef, ctx: Context, report: ImportReport) -> void:
	var objects: Array[StringName] = []
	for t in def.tags:
		if String(t).begins_with(FaithTags.PREFIX):
			objects.append(t)
	if def.has_faith() and objects.size() != 1:
		report.error("tags", "带 faith 的道具得恰好有一个信仰对象标签（%s<id>），现在有 %d 个" % [FaithTags.PREFIX, objects.size()])
	elif not def.has_faith() and not objects.is_empty():
		report.error("tags", "带了信仰对象标签 %s 却没有 faith 标签" % objects[0])
	if def.has_faith() and objects.size() == 1 and not ctx.faiths.is_empty():
		var fid := FaithTags.id_of_tag(objects[0])
		if not ctx.faiths.has(fid):
			report.error("tags", "没有登记过的信仰 '%s'（已知：%s）" % [fid, ", ".join(ctx.faiths.keys())])
	# 信力解锁的功能（082）只对信仰道具有意义；阶从 1 起
	if not def.faith_bonuses.is_empty() and not def.has_faith():
		report.error("faith_bonuses", "只有信仰道具才有按信力解锁的功能")
	for i in def.faith_bonuses.size():
		var b := def.faith_bonuses[i] as FaithBonus
		if b == null:
			report.error("faith_bonuses[%d]" % i, "空的加成")
		elif not _string_choices(b, "mode").has(b.mode):
			# 111：可选值读 `@export_enum`，加一种方式只改 FaithBonus 那一行
			report.error("faith_bonuses[%d].mode" % i, "生效方式只能是 %s" % " / ".join(_string_choices(b, "mode")))
		elif b.mode == "tier" and b.tier < 1:
			report.error("faith_bonuses[%d].tier" % i, "阶从 1 起")
		elif b.mode == "tier" and _faith_tiers(def, ctx) > 0 and b.tier > _faith_tiers(def, ctx):
			report.error("faith_bonuses[%d].tier" % i, "「%s」的信仰只有 %d 阶，写了第 %d 阶永远达不到" % [def.id, _faith_tiers(def, ctx), b.tier])
		elif b.mode == "scaled" and b.per_points < 1:
			report.error("faith_bonuses[%d].per_points" % i, "每份至少 1 信力")
		elif b.mods.is_empty() and b.rules.is_empty():
			report.error("faith_bonuses[%d]" % i, "加成得有修饰或规则")


## 111：字符串枚举字段的可选值（`@export_enum`）
static func _string_choices(owner: Object, key: String) -> Array[String]:
	for prop in owner.get_property_list():
		if String(prop["name"]) == key:
			return ContentSchema.enum_options(owner, prop)
	return [] as Array[String]


## 111：这件信仰道具所属信仰有几阶（阈值数）；不知道（单件导入、没登记）返回 0 = 不查
static func _faith_tiers(def: ItemDef, ctx: Context) -> int:
	if ctx == null or ctx.faiths.is_empty() or not def.has_faith():
		return 0
	var faith := ctx.faiths.get(FaithTags.id_of_tag(def.faith_tag()), null) as FaithDef
	return faith.thresholds.size() if faith != null else 0


## 112：说明文本里引用的道具 / 敌人（`{item:id}` `{enemy:id}` `{item_stat:id:字段}`）得存在 —— 写错了当场报，
## 不然游戏里原样露出一个花括号。库是空的（单件导入）就不查
static func check_text_refs(text: String, at: String, ctx: Context, report: ImportReport) -> void:
	for ref in TextTemplate.refs(text):
		var id := StringName(String(ref["id"]))
		if ref["kind"] == "enemy":
			if not ctx.enemies.is_empty() and not ctx.enemies.has(id):
				report.error(at, "文本里的 {enemy:%s}：敌人库里没有它" % id)
		elif ref["kind"] == "faith":
			if not ctx.faiths.is_empty() and not ctx.faiths.has(id):
				report.error(at, "文本里引用的信仰 %s 不存在" % id)
		elif not ctx.items.is_empty() and not ctx.items.has(id):
			report.error(at, "文本里引用的道具 %s 在道具库里没有" % id)


## 112：事件导入时敌人还没导（事件排在敌人前面），所以事件文本的引用在全部导完后统一查
static func validate_event_text_refs(ctx: Context, report: ImportReport) -> void:
	var ids: Array = ctx.events.keys()
	ids.sort()
	for eid in ids:
		var def := ctx.events[eid] as EventDef
		if def == null:
			continue
		report.source = "events/%s.json" % eid
		check_text_refs(def.title, "title", ctx, report)
		check_text_refs(def.text, "text", ctx, report)
		for lang in def.titles:
			check_text_refs(String(def.titles[lang]), "titles.%s" % lang, ctx, report)
		for lang in def.texts:
			check_text_refs(String(def.texts[lang]), "texts.%s" % lang, ctx, report)
		for i in def.options.size():
			var opt := def.options[i] as EventOption
			if opt != null:
				check_text_refs(opt.label, "options[%d].label" % i, ctx, report)
				check_text_refs(opt.hint_when_hidden, "options[%d].hint_when_hidden" % i, ctx, report)


## 敌人（M4-1）。校验里「对着道具查」的那几条只在批量导入（上下文里有道具）时生效。
static func import_enemy(data: Dictionary, ctx: Context, report: ImportReport) -> EnemyDef:
	var def := EnemyDef.new()
	_fill(def, data, "", ctx, report)
	_validate_enemy(def, ctx, report)
	ctx.register_enemy(def)
	return def


static func import_enemy_pool(data: Dictionary, ctx: Context, report: ImportReport) -> EnemyPool:
	var pool := EnemyPool.new()
	_fill(pool, data, "", ctx, report)
	_validate_enemy_pool(pool, ctx, report)
	ctx.register_pool(pool)
	return pool


## 126：敌人携带规则 —— 件数区间非负且 min ≤ max、value_power > 0
static func import_carry_rule(data: Dictionary, ctx: Context, report: ImportReport) -> CarryRule:
	var rule := CarryRule.new()
	_fill(rule, data, "", ctx, report)
	_require_id(rule.id, "携带规则", report)
	for i in rule.count_by_strength.size():
		var c := rule.count_by_strength[i]
		if c.x < 0 or c.y < c.x:
			report.error("count_by_strength[%d]" % i, "件数区间得是 [min, max]，0 ≤ min ≤ max")
	if rule.value_power <= 0.0:
		report.error("value_power", "得大于 0（越大越偏向便宜货）")
	if rule.tags.is_empty():
		report.warn("tags", "没有标签，什么都抽不到")
	ctx.register_carry_rule(rule)
	return rule


## 129：负重规则 —— 每级 over ≥ 1 且严格递增、travel_mult ≥ 1、减益不碰伤害（作者定）
static func import_encumbrance_rules(data: Dictionary, ctx: Context, report: ImportReport) -> EncumbranceRules:
	var rules := EncumbranceRules.new()
	_fill(rules, data, "", ctx, report)
	_require_id(rules.id, "负重规则", report)
	var last := 0.0
	for i in rules.levels.size():
		var lv := rules.levels[i]
		if lv == null:
			report.error("levels[%d]" % i, "空的一级")
			continue
		if lv.over < 1.0 or lv.over < last:
			report.error("levels[%d].over" % i, "得 ≥ 1 且不比上一级小（超过上限的倍数）")
		last = lv.over
		if lv.travel_mult < 1:
			report.error("levels[%d].travel_mult" % i, "走路倍数至少 1")
		for m in lv.mods:
			if m != null and m.stat == BattleStats.DAMAGE:
				report.error("levels[%d].mods" % i, "负重不直接减伤害（作者定：只减耐力回复、耐力上限、急速）")
	ctx.register_encumbrance_rules(rules)
	return rules


static func import_drop_rule(data: Dictionary, ctx: Context, report: ImportReport) -> DropRule:
	var rule := DropRule.new()
	_fill(rule, data, "", ctx, report)
	_validate_drop_rule(rule, report)
	ctx.register_drop_rule(rule)
	return rule


static func import_economy_rules(data: Dictionary, ctx: Context, report: ImportReport) -> EconomyRules:
	var rules := EconomyRules.new()
	_fill(rules, data, "", ctx, report)
	_validate_economy_rules(rules, report)
	ctx.register_economy_rules(rules)
	return rules


## 开局装备（M6）。「对着道具查」的两条只在批量导入（上下文里有道具）时生效
static func import_loadout(data: Dictionary, ctx: Context, report: ImportReport) -> LoadoutDef:
	var def := LoadoutDef.new()
	_fill(def, data, "", ctx, report)
	_validate_loadout_def(def, ctx, report)
	ctx.register_loadout(def)
	return def


## 角色（058 第 2 条，067）：体力上限、棋盘都得是正数；初始包至少一个、每个得存在且是包（对着道具查的只在批量导入时生效）；上限 -1 = 不限
## 149 铁律：科技只做所有人都能做的事，角色只做别人做不到的事 —— 角色被动用的一局规则构件，不许也出现在科技的局外 buff（`tech_*`）里。
## 批量导入时 run_buffs 先导（[constant ContentPaths.ORDER]），单独导一个角色时上下文是空的，跳过
static func _check_not_in_techs(e: Effect, at: String, ctx: Context, report: ImportReport) -> void:
	if e.get_script() == null:
		return
	var ids := ctx.run_buffs.keys()
	ids.sort()
	for bid in ids:
		if not String(bid).begins_with(TechsTable.BUFF_PREFIX):
			continue
		for other in (ctx.run_buffs[bid] as RunBuffDef).effects:
			if other != null and (other as Object).get_script() == e.get_script():
				report.error(at, "和科技「%s」用了同一种效果：科技只做谁都能做的事，角色只做别人做不到的事（149）" % bid)
				return


static func import_character(data: Dictionary, ctx: Context, report: ImportReport) -> CharacterDef:
	var def := CharacterDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "角色", report)
	if def.vitality_max < 1:
		report.error("vitality_max", "体力上限至少 1")
	if def.board_size.x < 1 or def.board_size.y < 1:
		report.error("board_size", "棋盘至少 1×1")
	if def.carry_max_items < -1 or def.carry_rarity_cap < -1:
		report.error("carry_max_items", "上限只能是 -1（不限）或非负数")
	if def.starting_funds < -1:
		report.error("starting_funds", "开局钱只能是 -1（用全局的）或非负数")
	if def.starting_bags.is_empty():
		report.error("starting_bags", "至少一个初始包：棋盘上只有包里的东西参战（3.2），没有包一格都用不了")
	for key in def.base_stats:
		if not (def.base_stats[key] is float or def.base_stats[key] is int):
			report.error("base_stats", "'%s' 的值得是数" % key)
	var seen_skills := {}
	for i in def.skills.size():
		var sk := def.skills[i] as RunSkill
		if sk == null:
			report.error("skills[%d]" % i, "空的技能")
			continue
		if sk.id == &"":
			report.error("skills[%d].id" % i, "技能必须有 id（记次数与冷却用）")
		elif seen_skills.has(sk.id):
			report.error("skills[%d].id" % i, "技能 id 重复：%s" % sk.id)
		seen_skills[sk.id] = true
		if sk.uses < -1:
			report.error("skills[%d].uses" % i, "次数只能是 -1（不限）或非负数")
		if sk.cooldown_steps < 0:
			report.error("skills[%d].cooldown_steps" % i, "冷却不能为负")
		if sk is AssaultSkill and ((sk as AssaultSkill).hp_fraction <= 0.0 or (sk as AssaultSkill).hp_fraction > 1.0):
			report.error("skills[%d].hp_fraction" % i, "突击扣的比例应在 (0, 1]")
		if sk is EvadeSkill and (sk as EvadeSkill).steps < 1:
			report.error("skills[%d].steps" % i, "躲避至少 1 步")
		for j in sk.passive.size():
			var e := sk.passive[j] as Effect
			if e == null:
				report.error("skills[%d].passive[%d]" % [i, j], "空的效果")
			elif e.scope() != EffectScope.LOOT and e.scope() != EffectScope.RUN:
				report.error("skills[%d].passive[%d]" % [i, j], "技能的被动只放掉落或一局规则的效果；战斗效果写进基线或道具")
			else:
				_check_not_in_techs(e, "skills[%d].passive[%d]" % [i, j], ctx, report)
	if not ctx.items.is_empty():
		for i in def.starting_bags.size():
			var item: ItemDef = ctx.items.get(def.starting_bags[i], null)
			if item == null:
				report.error("starting_bags[%d]" % i, "找不到道具 '%s'" % def.starting_bags[i])
			elif not item.is_bag:
				report.error("starting_bags[%d]" % i, "'%s' 不是包" % def.starting_bags[i])
			elif item.is_sealed():
				report.error("starting_bags[%d]" % i, "'%s' 已封存" % def.starting_bags[i])
	ctx.register_character(def)
	return def


## 进阶难度（069）：档位非负；机制不能是空的；effects 只放掉落或一局规则的效果（和 buff 一样）
static func import_difficulty(data: Dictionary, ctx: Context, report: ImportReport) -> DifficultyDef:
	var def := DifficultyDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "难度", report)
	if def.level < 0:
		report.error("level", "档位不能为负（0 = 普通）")
	# 127：搜索保底的覆盖只有 normal / advanced 两种，值是逐件稀有度下限
	for key in def.search_floors.keys():
		if not ["normal", "advanced"].has(String(key)):
			report.error("search_floors", "键只能是 normal / advanced，不认识 '%s'" % key)
			continue
		def.search_floors[key] = _floor_rows([def.search_floors[key]], "search_floors.%s" % key, report)[0] if def.search_floors[key] is Array else []
		if not (def.search_floors[key] is Array) or (def.search_floors[key] as Array).is_empty():
			report.error("search_floors.%s" % key, "应为非空的稀有度下限表，比如 [1, 0]")
	for i in def.mechanics.size():
		if def.mechanics[i] == null:
			report.error("mechanics[%d]" % i, "空的机制")
		elif def.mechanics[i] is ErosionMechanic:
			var em := def.mechanics[i] as ErosionMechanic
			if em.first_at_action < 0 or em.interval_actions < 1:
				report.error("mechanics[%d]" % i, "侵蚀：第一次不能为负、间隔至少 1")
			if em.warn_lead_actions < 1:
				report.error("mechanics[%d].warn_lead_actions" % i, "侵蚀必须预警（5.7）：提前量至少 1")
			for j in em.effects.size():
				var ee := em.effects[j] as ErosionEffect
				if ee == null:
					report.error("mechanics[%d].effects[%d]" % [i, j], "空的侵蚀效果")
				elif ee.chance < 0.0 or ee.chance > 1.0 or ee.from_depth < 0:
					report.error("mechanics[%d].effects[%d]" % [i, j], "概率应在 0～1、起始层非负")
		elif def.mechanics[i] is HunterMechanic:
			var hm := def.mechanics[i] as HunterMechanic
			if hm.bracket_steps.is_empty() or hm.bracket_steps[0] != 0:
				report.error("mechanics[%d].bracket_steps" % i, "段位表第一项得是 0")
			for j in range(1, hm.bracket_steps.size()):
				if hm.bracket_steps[j] < hm.bracket_steps[j - 1]:
					report.error("mechanics[%d].bracket_steps[%d]" % [i, j], "段位表得非递减")
	for i in def.effects.size():
		var e := def.effects[i] as Effect
		if e == null:
			report.error("effects[%d]" % i, "空的效果")
		elif e.scope() != EffectScope.LOOT and e.scope() != EffectScope.RUN:
			report.error("effects[%d]" % i, "难度的 effects 只放掉落或一局规则的效果")
	ctx.register_difficulty(def)
	return def


## 成就（091）：种类得认识；要对象的种类得写 target；数至少 1；对象是道具的批量导入时对着道具库查
static func import_achievement(data: Dictionary, ctx: Context, report: ImportReport) -> AchievementDef:
	var def := AchievementDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "成就", report)
	if def.display_name.strip_edges() == "":
		report.error("display_name", "成就得有名字")
	if not AchievementDef.KINDS.has(def.kind):
		report.error("kind", "认不得的条件种类 '%s'（可用：%s）" % [def.kind, ", ".join(AchievementDef.KINDS)])
	if AchievementDef.TARGETED.has(def.kind) and def.target == &"":
		report.error("target", "条件 '%s' 得写对象（target）" % def.kind)
	if not AchievementDef.TARGETED.has(def.kind) and def.target != &"":
		report.warn("target", "条件 '%s' 不看对象，target 不会生效" % def.kind)
	if def.amount < 1:
		report.error("amount", "要达到的数至少 1")
	if (def.kind == &"codex_has" or def.kind == &"keepsake") and not ctx.items.is_empty() and not ctx.items.has(def.target):
		report.error("target", "道具库里没有 %s" % def.target)
	for i in def.grants.size():
		if def.grants[i] == &"":
			report.error("grants[%d]" % i, "空的解锁 id")
	ctx.register_achievement(def)
	return def


## 局外科技（110）：得有 id、名字、效果、至少一级；每级的钱不为负；材料件数至少 1，批量导入时对着道具库查
static func import_tech(data: Dictionary, ctx: Context, report: ImportReport) -> TechDef:
	var def := TechDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "科技", report)
	if def.display_name.strip_edges() == "":
		report.error("display_name", "科技得有名字")
	if def.effect == null:
		report.error("effect", "科技得写每升一级做什么（effect）")
	if def.tiers.is_empty():
		report.error("tiers", "科技至少一级")
	for i in def.tiers.size():
		var tier := def.tiers[i]
		if tier == null:
			report.error("tiers[%d]" % i, "空的一级")
			continue
		if tier.funds < 0:
			report.error("tiers[%d].funds" % i, "钱不能是负的")
		for key in tier.items:
			var n := int(tier.items[key])
			if n < 1:
				report.error("tiers[%d].items.%s" % [i, key], "件数至少 1")
			if not ctx.items.is_empty() and not ctx.items.has(StringName(String(key))):
				report.error("tiers[%d].items.%s" % [i, key], "道具库里没有 %s" % key)
	# 118：树的字段
	if def.column < 0:
		report.error("column", "列从 0 起")
	for i in def.requires.size():
		if def.requires[i] == def.id:
			report.error("requires[%d]" % i, "前置不能是自己")
	check_text_refs(def.description, "description", ctx, report)
	# 118：每级给一条局外 buff —— 条数等于级数，每条得存在且是局外（META）的
	if def.effect is TechRunBuff:
		var rb := def.effect as TechRunBuff
		if rb.buffs.size() != def.tiers.size():
			report.error("effect.buffs", "每一级给一条 buff：写了 %d 条，科技有 %d 级" % [rb.buffs.size(), def.tiers.size()])
		for i in rb.buffs.size():
			var b: RunBuffDef = ctx.run_buffs.get(rb.buffs[i], null)
			if not ctx.run_buffs.is_empty() and b == null:
				report.error("effect.buffs[%d]" % i, "没有局外 buff %s（data/authoring/run_buffs）" % rb.buffs[i])
			elif b != null and not b.is_meta():
				report.error("effect.buffs[%d]" % i, "buff %s 不是局外的（scope 得是 META）" % rb.buffs[i])
	ctx.register_tech(def)
	return def


## 118：全部科技导完后查树：前置存在、没有环；同列同深度撞位只警告（按 order 左右排）
static func validate_techs(ctx: Context, report: ImportReport) -> void:
	var defs: Array = ctx.techs.values()
	for def in defs:
		var d := def as TechDef
		for i in d.requires.size():
			if not ctx.techs.has(d.requires[i]):
				report.error("techs/%s.requires[%d]" % [d.id, i], "前置科技 %s 不存在" % d.requires[i])
	var loop := TechService.cycle_members(defs)
	if not loop.is_empty():
		report.error("techs", "科技的前置成环：%s" % ", ".join(loop))
		return
	var slots := {}
	var lay := TechService.layout(defs)
	var ids: Array = lay.keys()
	ids.sort()
	for id in ids:
		var at: Vector2i = lay[id]
		if slots.has(at):
			report.warn("techs/%s" % id, "和 %s 撞位（第 %d 列、深度 %d）：按 order 左右排" % [slots[at], at.x, at.y])
		else:
			slots[at] = id


## 114：百科的一页机制说明。分类在固定清单里、有标题有正文、相关道具是真道具、文本里的引用存在。
## 「相关」指到的页要等全部导完才查得全（[method validate_help_pages]）
static func import_help_page(data: Dictionary, ctx: Context, report: ImportReport) -> HelpPageDef:
	var def := HelpPageDef.new()
	_fill(def, data, "", ctx, report)
	if _require_id(def.id, "百科页", report) and String(def.id).contains(":"):
		report.error("id", "百科页的 id 不能带冒号（冒号留给自动生成的词条页）")
	if def.display_name.strip_edges() == "":
		report.error("display_name", "百科页得有标题")
	if def.text.strip_edges() == "":
		report.error("text", "百科页得有正文")
	if not HelpPageDef.CATEGORIES.has(String(def.category)):
		report.error("category", "分类 %s 不在 %s 里" % [def.category, str(HelpPageDef.CATEGORIES)])
	for i in def.see_items.size():
		if not ctx.items.is_empty() and not ctx.items.has(def.see_items[i]):
			report.error("see_items[%d]" % i, "道具库里没有 %s" % def.see_items[i])
	check_text_refs(def.text, "text", ctx, report)
	for lang in def.texts:
		check_text_refs(String(def.texts[lang]), "texts.%s" % lang, ctx, report)
	ctx.register_help_page(def)
	return def


## 114：全部导完后查百科页的「相关」：得是另一页的 id，或固定词条名
static func validate_help_pages(ctx: Context, report: ImportReport) -> void:
	var ids: Array = ctx.help_pages.keys()
	ids.sort()
	for pid in ids:
		var def := ctx.help_pages[pid] as HelpPageDef
		report.source = "help_pages/%s.json" % pid
		for i in def.related.size():
			var r := def.related[i]
			if not ctx.help_pages.has(StringName(r)) and not Glossary.TERMS.has(r):
				report.error("related[%d]" % i, "「%s」既不是百科页 id 也不是词条名" % r)


## 猎手（069 / 071）：数全得合理；行动逻辑可空（= 不动）；战败后果不能是空的；指定的敌人池得存在（批量导入时）
static func import_hunter(data: Dictionary, ctx: Context, report: ImportReport) -> HunterDef:
	var def := HunterDef.new()
	# 140：134 之前的 loss_outcomes（只有一档）删了 —— 写了就报错，让作者挪进 loss_options 的某一档
	var body := data
	if data.has("loss_outcomes"):
		report.error("loss_outcomes", "loss_outcomes 已删（140）：请改用 loss_options，把这几条后果放进某一档的 outcomes")
		body = data.duplicate()
		body.erase("loss_outcomes")
	_fill(def, body, "", ctx, report)
	_require_id(def.id, "猎手", report)
	if def.level < 0:
		report.error("level", "等级不能为负")
	if def.speed < 0:
		report.error("speed", "速度不能为负")
	if def.sense_range < 0.0 or def.engage_range < 0.0 or def.near_range < 0.0:
		report.error("sense_range", "距离不能为负")
	if def.drop_mult < 0.0:
		report.error("drop_mult", "掉落倍数不能为负")
	if def.flee_chance < 0.0 or def.flee_chance > 1.0:
		report.error("flee_chance", "逃跑成功率应在 0～1 之间")
	if def.flee_fail_vitality < 0 or def.flee_cooldown < 0:
		report.error("flee_fail_vitality", "逃跑的代价与冷却不能为负")
	if def.loss_cost < -2:
		report.error("loss_cost", "战败代价只能是 -1（按规则）、-2（必死）、0（无代价）或正数")
	# 134：战败结果档。至少一档；档名不空、不重，权重不为负，后果不空
	if def.loss_options.is_empty():
		report.error("loss_options", "至少写一档战败结果（loss_options）")
	var seen_opts := {}
	for i in def.loss_options.size():
		var o := def.loss_options[i] as HunterLossOption
		var at := "loss_options[%d]" % i
		if o == null:
			report.error(at, "空的战败结果档")
			continue
		if o.id == &"":
			report.error(at + ".id", "结果档要有 id（如 repel / expel）")
		elif seen_opts.has(o.id):
			report.error(at + ".id", "结果档 id '%s' 重复" % o.id)
		seen_opts[o.id] = true
		if o.weight < 0.0:
			report.error(at + ".weight", "权重不能为负")
		for j in o.outcomes.size():
			if o.outcomes[j] == null:
				report.error("%s.outcomes[%d]" % [at, j], "空的战败后果")
	if def.loss_pick is LossPickFixed and ((def.loss_pick as LossPickFixed).index < 0 or (def.loss_pick as LossPickFixed).index >= maxi(1, def.options().size())):
		report.error("loss_pick.index", "固定选第 %d 档，可这个猎手只有 %d 档" % [(def.loss_pick as LossPickFixed).index, def.options().size()])
	for i in def.strength_by_bracket.size():
		if def.strength_by_bracket[i] < 0:
			report.error("strength_by_bracket[%d]" % i, "档位不能为负")
	if def.enemy_pool != &"" and not ctx.pools.is_empty() and not ctx.pools.has(def.enemy_pool):
		report.error("enemy_pool", "找不到敌人池 '%s'" % def.enemy_pool)
	ctx.register_hunter(def)
	return def


## buff（059）：局外的或一局里的。战斗效果得带扳机、放 rules；effects 里只能是掉落或一局规则的效果
static func import_run_buff(data: Dictionary, ctx: Context, report: ImportReport) -> RunBuffDef:
	var def := RunBuffDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "buff", report)
	if def.duration_steps < 0:
		report.error("duration_steps", "时限不能为负（0 = 整局）")
	for i in def.effects.size():
		var e := def.effects[i] as Effect
		if e == null:
			report.error("effects[%d]" % i, "空的效果")
		elif e.scope() != EffectScope.LOOT and e.scope() != EffectScope.RUN:
			report.error("effects[%d]" % i, "buff 的 effects 只放掉落或一局规则的效果；战斗效果要带扳机，写进 rules")
	if def.effects.is_empty() and def.mods.is_empty() and def.rules.is_empty() and def.tags.is_empty():
		report.warn("effects", "这个 buff 什么都不改、也没有标记 —— 要当标记用至少给一个 tag")
	ctx.register_run_buff(def)
	return def


## 事件（063）：至少一个选项、选项得有字；给的道具得存在、给的地图 buff 得存在且是地图作用域（对着别的东西查的只在批量导入时生效）
static func import_event(data: Dictionary, ctx: Context, report: ImportReport) -> EventDef:
	var def := EventDef.new()
	_fill(def, data, "", ctx, report)
	_require_id(def.id, "事件", report)
	if def.options.is_empty():
		report.error("options", "事件至少一个选项，不然关不掉")
	else:
		# 作者定的：至少一个不带条件的选项 —— 否则条件全没过时玩家被困在这一屏
		var has_free := false
		for o in def.options:
			var free_opt := o as EventOption
			if free_opt != null and free_opt.requires.is_empty():
				has_free = true
		if not has_free:
			report.error("options", "至少一个不带条件的选项：条件全没过时玩家得有路走")
	for i in def.options.size():
		var opt := def.options[i] as EventOption
		if opt == null:
			report.error("options[%d]" % i, "空的选项")
			continue
		if opt.label.strip_edges() == "":
			report.error("options[%d].label" % i, "选项得有字")
		for k in opt.outcomes.size():
			var o := opt.outcomes[k] as EventOutcome
			var at := "options[%d].outcomes[%d]" % [i, k]
			if o == null:
				report.error(at, "空的后果")
			elif o is GiveItem and not ctx.items.is_empty() and not ctx.items.has((o as GiveItem).item):
				report.error(at, "找不到道具 '%s'" % (o as GiveItem).item)
			elif o is GiveItem and not ctx.items.is_empty() and (ctx.items[(o as GiveItem).item] as ItemDef).is_sealed():
				report.error(at, "'%s' 已封存，事件不能给它" % (o as GiveItem).item)
			elif (o is GrantMapBuff or o is RemoveMapBuff) and not ctx.run_buffs.is_empty():
				var bid: StringName = (o as GrantMapBuff).buff if o is GrantMapBuff else (o as RemoveMapBuff).buff
				var b: RunBuffDef = ctx.run_buffs.get(bid, null)
				if b == null:
					report.error(at, "找不到 buff '%s'" % bid)
				elif not b.is_map():
					report.error(at, "'%s' 是局外 buff，事件只能给地图 buff" % bid)
			elif o is Teleport:
				var tp := o as Teleport
				if tp.action_cost < 0:
					report.error(at, "传送的代价不能是负的")
				if tp.max_steps >= 0 and tp.max_steps < tp.min_steps:
					report.error(at, "传送的步数区间反了：%d～%d" % [tp.min_steps, tp.max_steps])
				for nt in tp.node_types:
					if not MapNodeTypes.has(nt):
						report.error(at, "认不得的节点类型 '%s'" % nt)
			elif o is ChangeNodeType:
				var ct := (o as ChangeNodeType).node_type
				if not MapNodeTypes.has(ct):
					report.error(at, "认不得的节点类型 '%s'" % ct)
				elif MapNodeTypes.STRUCTURAL.has(ct):
					report.error(at, "'%s' 是结构性的类型（由拓扑定），事件不能把点变成它" % ct)
			elif o is LoseItem and (o as LoseItem).pick == LoseItem.Pick.BY_ID \
					and not ctx.items.is_empty() and not ctx.items.has((o as LoseItem).item):
				report.error(at, "找不到道具 '%s'" % (o as LoseItem).item)
			elif o is PassTime and (o as PassTime).actions <= 0:
				report.error(at, "耗时得是正数")
		# 8-3：同一个选项里挪人和留在这里的事撞车 —— 传送走了，搜索 / 商店 / 下一个事件就没了；给的东西离开时也清掉
		var teleports := false
		var stays := false
		var gives := false
		for o in opt.outcomes:
			teleports = teleports or o is Teleport
			stays = stays or o is OpenSearch or o is OpenShop or o is NextEvent
			gives = gives or o is GiveItem or o is GiveRandomItem
		if teleports and stays:
			report.error("options[%d].outcomes" % i, "传送不能和搜索 / 开店 / 接下一个事件放在同一个选项里：人走了会话就断了")
		if teleports and gives:
			report.error("options[%d].outcomes" % i, "传送不能和给道具放在同一个选项里：离开发生过事的点地上会清空，给的东西立刻没了")
		for k in opt.requires.size():
			var cond := opt.requires[k] as EventCondition
			var cat := "options[%d].requires[%d]" % [i, k]
			if cond == null:
				report.error(cat, "空的条件")
			elif cond is HasItem and (cond as HasItem).item != &"" and not ctx.items.is_empty() and not ctx.items.has((cond as HasItem).item):
				report.error(cat, "找不到道具 '%s'" % (cond as HasItem).item)
			elif cond is NodeTypeIs:
				if (cond as NodeTypeIs).types.is_empty():
					report.error(cat, "节点类型名单是空的：永远不满足")
				for nt in (cond as NodeTypeIs).types:
					if not MapNodeTypes.has(nt):
						report.error(cat, "认不得的节点类型 '%s'" % nt)
			elif cond is StepsWithin and (cond as StepsWithin).max_steps >= 0 and (cond as StepsWithin).max_steps < (cond as StepsWithin).min_steps:
				report.error(cat, "步数区间反了")
			elif cond is BracketWithin and (cond as BracketWithin).max_bracket >= 0 and (cond as BracketWithin).max_bracket < (cond as BracketWithin).min_bracket:
				report.error(cat, "段位区间反了")
			elif cond is ErosionDepthWithin and (cond as ErosionDepthWithin).max_depth >= 0 and (cond as ErosionDepthWithin).max_depth < (cond as ErosionDepthWithin).min_depth:
				report.error(cat, "侵蚀深度区间反了")
	ctx.register_event(def)
	return def


## 局外规则（058 第 6 条）：仓库多大
static func import_meta_rules(data: Dictionary, ctx: Context, report: ImportReport) -> MetaRules:
	var rules := MetaRules.new()
	_fill(rules, data, "", ctx, report)
	_require_id(rules.id, "局外规则", report)
	if rules.warehouse_size.x < 1 or rules.warehouse_size.y < 1:
		report.error("warehouse_size", "仓库至少 1×1")
	if rules.first_kit != &"" and not ctx.loadouts.is_empty() and not ctx.loadouts.has(rules.first_kit):
		report.error("first_kit", "找不到开局装备 '%s'" % rules.first_kit)
	ctx.register_meta_rules(rules)
	return rules


## 清单不能空；每件得存在；至少一个包 —— 棋盘上只有包里的东西参战（3.2），没有包一格都用不了
static func _validate_loadout_def(def: LoadoutDef, ctx: Context, report: ImportReport) -> void:
	_require_id(def.id, "开局装备", report)
	if def.items.is_empty():
		report.error("items", "开局装备至少带一件")
		return
	if ctx.items.is_empty():
		return
	var has_bag := false
	for i in def.items.size():
		var item: ItemDef = ctx.items.get(def.items[i], null)
		if item == null:
			report.error("items[%d]" % i, "找不到道具 '%s'" % def.items[i])
		elif item.is_sealed():
			report.error("items[%d]" % i, "'%s' 已封存（现代道具，世界观见 docs/worldview.md），不能进开局装备" % def.items[i])
		elif item.is_bag:
			has_bag = true
	if not has_bag and not def.preset:
		report.error("items", "开局至少带一个包：棋盘上只有包里的东西参战（3.2），没有包一格都用不了（预设套 preset=true 例外：角色的初始包装它）")


## 钱的数全得非负；商店至少一格、至少有一档稀有度能上架；刷新不能越刷越便宜
static func _validate_economy_rules(rules: EconomyRules, report: ImportReport) -> void:
	_require_id(rules.id, "经济规则", report)
	for pair in [["starting_balance", rules.starting_balance], ["reward_base", rules.reward_base],
			["reward_per_strength", rules.reward_per_strength], ["shop_refresh_cost", rules.shop_refresh_cost],
			["shop_refresh_step", rules.shop_refresh_step], ["paid_extracts", rules.paid_extracts], ["extract_fee", rules.extract_fee]]:
		if int(pair[1]) < 0:
			report.error(String(pair[0]), "不能为负")
	for pair in [["reward_depth_gain", rules.reward_depth_gain], ["reward_difficulty_gain", rules.reward_difficulty_gain],
			["shop_depth_gain", rules.shop_depth_gain]]:
		if float(pair[1]) < 0.0:
			report.error(String(pair[0]), "不能为负 —— 越深越少、越难越少不是这个字段的意思")
	if rules.shop_price_mult <= 0.0:
		report.error("shop_price_mult", "售价倍数应为正")
	if rules.shop_slots < 1:
		report.error("shop_slots", "商店至少摆一件")
	var any_weight := false
	for i in rules.shop_rarity_weights.size():
		if rules.shop_rarity_weights[i] < 0.0:
			report.error("shop_rarity_weights[%d]" % i, "权重不能为负")
		elif rules.shop_rarity_weights[i] > 0.0:
			any_weight = true
	if not any_weight:
		report.error("shop_rarity_weights", "没有一档稀有度能上架")


static func import_node_rules(data: Dictionary, ctx: Context, report: ImportReport) -> NodeRules:
	var rules := NodeRules.new()
	_fill(rules, data, "", ctx, report)
	_validate_node_rules(rules, ctx, report)
	ctx.register_node_rules(rules)
	return rules


## 随机点只能变成 A/S/R/V/Q（5.4：不会变成精英或 BOSS）；遭遇曲线非递减、在 0～1；件数范围合法；扣的体力非负。
static func _validate_node_rules(rules: NodeRules, ctx: Context, report: ImportReport) -> void:
	_require_id(rules.id, "节点规则", report)
	if rules.random_weights.is_empty():
		report.error("random_weights", "随机点得能变成点什么")
	for key in rules.random_weights:
		if not NodeRules.RANDOM_ALLOWED.has(StringName(String(key))):
			report.error("random_weights", "随机点不能变成 '%s'（只能是 %s）" % [key, ", ".join(NodeRules.RANDOM_ALLOWED)])
		if float(rules.random_weights[key]) < 0.0:
			report.error("random_weights", "'%s' 的权重不能为负" % key)
	for key in rules.loss_cost:
		if int(rules.loss_cost[key]) < 0:
			report.error("loss_cost", "'%s' 扣的体力不能为负" % key)
		if String(key) == "core":
			report.error("loss_cost", "core 不在这里：BOSS 输了直接战败，那是规则不是数值（7.1）")
	for type in rules.events_by_type:
		var table = rules.events_by_type[type]
		if not (table is Dictionary):
			report.error("events_by_type", "'%s' 下该是 {事件 id: 权重}" % type)
			continue
		for eid in table:
			if float(table[eid]) < 0.0:
				report.error("events_by_type", "'%s' 里 '%s' 的权重不能为负" % [type, eid])
			if not ctx.events.is_empty() and not ctx.events.has(StringName(String(eid))):
				report.error("events_by_type", "'%s' 里找不到事件 '%s'（已知：%s）" % [type, eid, ", ".join(ctx.events.keys())])
	for gname in rules.event_groups:
		var g = rules.event_groups[gname]
		if not (g is Dictionary) or not ((g as Dictionary).get("events", null) is Dictionary):
			report.error("event_groups", "'%s' 下该是 {max_per_map, early, chance, events: {事件 id: 权重}}" % gname)
			continue
		for eid in (g as Dictionary)["events"]:
			if not ctx.events.is_empty() and not ctx.events.has(StringName(String(eid))):
				report.error("event_groups", "'%s' 里找不到事件 '%s'" % [gname, eid])
	for key in rules.event_weights:
		if not NodeRules.EVENT_OUTCOMES.has(StringName(String(key))):
			report.error("event_weights", "认不得的事件结果 '%s'（只能是 %s）" % [key, ", ".join(NodeRules.EVENT_OUTCOMES)])
	if rules.rest_restore < 0 or rules.event_restore < 0:
		report.error("rest_restore", "回的体力不能为负")
	if rules.battle_time_limit <= 0.0:
		report.error("battle_time_limit", "战斗时限应为正")
	if rules.overtime != null:
		for pr in rules.overtime.problems():
			report.error("overtime." + String(pr[0]), String(pr[1]))
	if rules.search == null:
		report.error("search", "没有搜索规则，搜索点不知道怎么搜")
		return
	var s := rules.search
	if s.max_searches < 1:
		report.error("search.max_searches", "至少能搜一次")
	if s.encounter_curve.is_empty():
		report.error("search.encounter_curve", "没有遭遇曲线")
	for i in s.encounter_curve.size():
		var p := s.encounter_curve[i]
		if p < 0.0 or p > 1.0:
			report.error("search.encounter_curve[%d]" % i, "概率应在 0～1 之间")
		if i > 0 and p < s.encounter_curve[i - 1]:
			report.error("search.encounter_curve[%d]" % i, "第 %d 次的遭遇概率 %.2f 低于第 %d 次的 %.2f —— 每搜一次该更险"
				% [i, p, i - 1, s.encounter_curve[i - 1]])
	if s.items_per_search.x < 0 or s.items_per_search.y < s.items_per_search.x:
		report.error("search.items_per_search", "件数范围应为 [min, max] 且 min ≥ 0")
	if s.rarity_weights.is_empty():
		report.error("search.rarity_weights", "没有稀有度权重")
	for i in s.rarity_weights.size():
		if s.rarity_weights[i] < 0.0:
			report.error("search.rarity_weights[%d]" % i, "权重不能为负")
	if s.haul_board.x < 1 or s.haul_board.y < 1:
		report.error("search.haul_board", "容器至少 1×1")
	if s.reveal_seconds.is_empty():
		report.error("search.reveal_seconds", "没有揭示耗时表")
	for i in s.reveal_seconds.size():
		if s.reveal_seconds[i] < 0.0:
			report.error("search.reveal_seconds[%d]" % i, "耗时不能为负")
		if i > 0 and s.reveal_seconds[i] < s.reveal_seconds[i - 1]:
			report.error("search.reveal_seconds[%d]" % i, "稀有度 %d 的耗时 %.2f 低于稀有度 %d 的 %.2f —— 越稀有搜得越久" % [i, s.reveal_seconds[i], i - 1, s.reveal_seconds[i - 1]])
	# 127：保底阶梯 —— 每行是逐件稀有度下限（0～5）；JSON 的数读回来是小数，还原成整数
	s.search_floors = _floor_rows(s.search_floors, "search.search_floors", report)


## 127：逐件稀有度下限的表（几行）—— 每行非空、每项 0～5，统一成整数
static func _floor_rows(rows: Array, at: String, report: ImportReport) -> Array:
	var out: Array = []
	for i in rows.size():
		var row: Variant = rows[i]
		if not (row is Array) or (row as Array).is_empty():
			report.error("%s[%d]" % [at, i], "每行得是非空的稀有度下限表，比如 [1, 0]")
			out.append([])
			continue
		var clean: Array = []
		for v in row:
			var r := int(v)
			if r < 0 or r > 5:
				report.error("%s[%d]" % [at, i], "稀有度下限得在 0～5（现在 %d）" % r)
			clean.append(r)
		out.append(clean)
	return out


## 作者定的形状写成校验：概率在 0～1，**稀有度越高基础掉落率越低**（非递增），珍宝的稀有度得是真的稀有度、权重为正。
static func _validate_drop_rule(rule: DropRule, report: ImportReport) -> void:
	_require_id(rule.id, "掉落规则", report)
	if rule.base_chance.is_empty():
		report.error("base_chance", "没有基础掉落率表")
	for i in rule.base_chance.size():
		var p := rule.base_chance[i]
		if p < 0.0 or p > 1.0:
			report.error("base_chance[%d]" % i, "概率应在 0～1 之间")
		if i > 0 and p > rule.base_chance[i - 1]:
			report.error("base_chance[%d]" % i, "稀有度 %d 的掉落率 %.2f 高于稀有度 %d 的 %.2f —— 越稀有该越难掉"
				% [i, p, i - 1, rule.base_chance[i - 1]])
	if rule.treasure_chance < 0.0 or rule.treasure_chance > 1.0:
		report.error("treasure_chance", "概率应在 0～1 之间")
	if rule.treasure_weights.is_empty():
		report.warn("treasure_weights", "没有珍宝档位，永远不掉珍宝")
	for key in rule.treasure_weights:
		var text := String(key)
		if not text.is_valid_int() or int(text) < 0:
			report.error("treasure_weights", "键 '%s' 不是稀有度（应为非负整数的字符串）" % text)
		if float(rule.treasure_weights[key]) <= 0.0:
			report.error("treasure_weights", "稀有度 %s 的权重应为正" % text)
	if rule.treasure_tag == &"":
		report.error("treasure_tag", "珍宝得有个标签，不然不知道哪些道具算珍宝")


## 比引擎严格：流派没有道具就组不出来，招牌道具得存在，档位不能为负。
static func _validate_enemy(def: EnemyDef, ctx: Context, report: ImportReport) -> void:
	_require_id(def.id, "敌人", report)
	if def.strength < 0:
		report.error("strength", "档位不能为负")
	if def.schools.is_empty():
		report.warn("schools", "没有流派，只会背通用道具")
	if def.loadout != null:
		_validate_loadout(def.loadout, "loadout", report)
	if ctx.items.is_empty():
		return
	for s in def.schools:
		if ctx.items_tagged(s) == 0:
			report.error("schools", "流派 '%s' 没有任何道具带这个标签，组不出流派道具" % s)
	var sigs: Array = []
	for sid in def.signature:
		sigs.append(["signature", sid])
	for key in def.signature_by_strength:
		if not String(key).is_valid_int() or int(String(key)) < 0:
			report.error("signature_by_strength", "档位键 '%s' 得是非负整数" % String(key))
		var list = def.signature_by_strength[key]
		if not (list is Array):
			report.error("signature_by_strength.%s" % String(key), "得是道具 id 列表")
			continue
		for raw in list:
			sigs.append(["signature_by_strength.%s" % String(key), StringName(String(raw))])
	for pair in sigs:
		var at: String = pair[0]
		var sid: StringName = pair[1]
		if not ctx.items.has(sid):
			report.error(at, "找不到招牌道具 '%s'" % sid)
		elif (ctx.items[sid] as ItemDef).is_bag:
			report.error(at, "招牌道具 '%s' 是个包 —— 敌人的棋盘不放包" % sid)
		elif (ctx.items[sid] as ItemDef).is_sealed():
			report.error(at, "招牌道具 '%s' 已封存" % sid)
		elif not def.allows_item(ctx.items[sid]):
			report.error(at, "招牌道具 '%s' 不带这个身份的任何标签（item_tags）" % sid)
	# 087：身份标签得真的圈得住东西，而且圈里得有会打的
	if not def.item_tags.is_empty():
		var any := 0
		var weapons := 0
		for id in ctx.items:
			var d := ctx.items[id] as ItemDef
			if d == null or d.is_bag or d.is_sealed() or not def.allows_item(d):
				continue
			any += 1
			if d.tags.has(&"weapon"):
				weapons += 1
		if any == 0:
			report.error("item_tags", "没有任何道具带这些身份标签，组不出东西")
		elif weapons == 0:
			report.warn("item_tags", "身份标签圈住的道具里没有武器：这个敌人不会出手")


static func _validate_loadout(rule: EnemyLoadout, at: String, report: ImportReport) -> void:
	if rule.school_share < 0.0 or rule.school_share > 1.0:
		report.error(at + ".school_share", "份额应在 0～1 之间")
	if rule.min_school < 0:
		report.error(at + ".min_school", "不能为负")


## 池：条目指向存在的敌人、档位表不空不重、每条规则都在。
static func _validate_enemy_pool(pool: EnemyPool, ctx: Context, report: ImportReport) -> void:
	_require_id(pool.id, "敌人池", report)
	if pool.entries.is_empty():
		report.error("entries", "池里一个敌人都没有")
	if pool.tiers.is_empty():
		report.error("tiers", "没有档位表，不知道该背几件")
	if pool.strength_rule == null:
		report.error("strength_rule", "没有档位规则，不知道哪个点该多强")
	if pool.loadout == null:
		report.error("loadout", "没有默认组装规则")
	else:
		_validate_loadout(pool.loadout, "loadout", report)
	if pool.combat_types.is_empty():
		report.error("combat_types", "没有一种节点类型放敌人")
	var seen := {}
	for i in pool.tiers.size():
		var t := pool.tiers[i]
		var at := "tiers[%d]" % i
		if t == null:
			report.error(at, "档位为空")
			continue
		if seen.has(t.strength):
			report.error(at, "档位 %d 重复" % t.strength)
		seen[t.strength] = true
		if t.item_count.x < 1 or t.item_count.y < t.item_count.x:
			report.error(at + ".item_count", "件数范围应为 [min, max] 且 min ≥ 1")
		if t.board.x < 1 or t.board.y < 1:
			report.error(at + ".board", "棋盘至少 1×1")
	for i in pool.entries.size():
		var e := pool.entries[i]
		var at := "entries[%d]" % i
		if e == null:
			report.error(at, "条目为空")
			continue
		if e.weight <= 0.0:
			report.error(at + ".weight", "权重应为正")
		for nt in e.node_types:
			if not pool.combat_types.has(nt):
				report.error(at + ".node_types", "'%s' 不在池的 combat_types 里，永远不会出现" % nt)
		if not ctx.enemies.is_empty() and not ctx.enemies.has(e.enemy):
			report.error(at + ".enemy", "找不到敌人 '%s'（已知：%s）" % [e.enemy, ", ".join(ctx.enemies.keys())])


## 章节（M3-5）。结构和道具完全不同，走的却是同一条 _fill ——
## 这是「导入器不认识具体类型」的第一次真实检验。
static func import_chapter(data: Dictionary, ctx: Context, report: ImportReport) -> ChapterDef:
	var def := ChapterDef.new()
	_fill(def, data, "", ctx, report)
	_validate_chapter(def, ctx, report)
	for i in def.rules.size():     # 112：规则卡也认 {item:} {enemy:}
		check_text_refs(def.rules[i], "rules[%d]" % i, ctx, report)
	return def


## 比引擎严格：地图来源得真的能拿出图来。生成器没登记、预设文件不在，都是内容错误。
static func _validate_chapter(def: ChapterDef, ctx: Context, report: ImportReport) -> void:
	_require_id(def.id, "章节", report)
	if def.difficulty < 0:
		report.error("difficulty", "难度不能为负")
	if def.enemy_pool != &"" and not ctx.pools.is_empty() and not ctx.pools.has(def.enemy_pool):
		report.error("enemy_pool", "找不到敌人池 '%s'（已知：%s）" % [def.enemy_pool, ", ".join(ctx.pools.keys())])
	if def.drop_rule != &"" and not ctx.drop_rules.is_empty() and not ctx.drop_rules.has(def.drop_rule):
		report.error("drop_rule", "找不到掉落规则 '%s'（已知：%s）" % [def.drop_rule, ", ".join(ctx.drop_rules.keys())])
	if def.carry_rule != &"" and not ctx.carry_rules.is_empty() and not ctx.carry_rules.has(def.carry_rule):
		report.error("carry_rule", "找不到携带规则 '%s'（已知：%s）" % [def.carry_rule, ", ".join(ctx.carry_rules.keys())])
	if def.encumbrance_rules != &"" and not ctx.encumbrance_rules.is_empty() and not ctx.encumbrance_rules.has(def.encumbrance_rules):
		report.error("encumbrance_rules", "找不到负重规则 '%s'（已知：%s）" % [def.encumbrance_rules, ", ".join(ctx.encumbrance_rules.keys())])
	if def.node_rules != &"" and not ctx.node_rules.is_empty() and not ctx.node_rules.has(def.node_rules):
		report.error("node_rules", "找不到节点规则 '%s'（已知：%s）" % [def.node_rules, ", ".join(ctx.node_rules.keys())])
	if def.economy_rules != &"" and not ctx.economy_rules.is_empty() and not ctx.economy_rules.has(def.economy_rules):
		report.error("economy_rules", "找不到经济规则 '%s'（已知：%s）" % [def.economy_rules, ", ".join(ctx.economy_rules.keys())])
	for i in def.characters.size():
		if not ctx.characters.is_empty() and not ctx.characters.has(def.characters[i]):
			report.error("characters[%d]" % i, "找不到角色 '%s'（已知：%s）" % [def.characters[i], ", ".join(ctx.characters.keys())])
	# 088：开局发的特殊道具得存在、得是特殊道具
	for i in def.starting_keepsakes.size():
		var kid := def.starting_keepsakes[i]
		if not ctx.items.is_empty() and not ctx.items.has(kid):
			report.error("starting_keepsakes[%d]" % i, "找不到特殊道具 '%s'" % kid)
		elif ctx.items.has(kid) and not (ctx.items[kid] as ItemDef).is_keepsake():
			report.error("starting_keepsakes[%d]" % i, "'%s' 不是特殊道具（没有 keepsake 标签）" % kid)
	# 091：本图规则卡最多三条（作者定：≤ 3 条，一页看完）
	if def.rules.size() > 3:
		report.warn("rules", "本图规则卡写了 %d 条，作者定的是最多 3 条" % def.rules.size())
	if def.map_source == null:
		report.error("map_source", "章节必须有地图来源（随机生成或载入预设）")
		return
	var src := def.map_source
	match src.mode:
		MapSource.Mode.PRESET:
			if src.preset_path == "" or not FileAccess.file_exists(src.preset_path):
				report.error("map_source.preset_path", "找不到预设地图 '%s'" % src.preset_path)
		_:
			if not MapGeneratorRegistry.has(src.generator_id):
				report.error("map_source.generator_id", "没有登记过的生成器 '%s'（已登记：%s）"
					% [src.generator_id, ", ".join(MapGeneratorRegistry.ids())])
			elif src.generator_config == null:
				report.error("map_source.generator_config", "随机生成得有一份生成器配置")
			else:
				# 造一个生成器看它认不认这份配置 —— 装错类的配置到开局才炸，那时离文件已经很远了
				var gen := MapGeneratorRegistry.create(src.generator_id)
				var probe := gen.default_config() if gen != null else null
				if probe != null and ContentSchema.class_name_of(probe) != ContentSchema.class_name_of(src.generator_config):
					report.error("map_source.generator_config", "生成器 '%s' 要的是 %s，给的是 %s"
						% [src.generator_id, ContentSchema.class_name_of(probe),
							ContentSchema.class_name_of(src.generator_config)])


## 比引擎严格（10.3）：引擎能接受的半成品，这里一律拒绝。
static func _validate_item(def: ItemDef, report: ImportReport) -> void:
	_require_id(def.id, "物品", report)
	if def.shape == null:
		report.error("shape", "物品必须有形状")
	elif not def.shape.is_valid():
		report.error("shape", "形状非法：为空或有重复格")
	if def.rarity < 0:
		report.error("rarity", "稀有度不能为负")

	if not def.is_bag:
		if not def.bag_accept_tags.is_empty():
			report.warn("bag_accept_tags", "不是包，准入标签不会生效")
		if not def.bag_mods.is_empty():
			report.warn("bag_mods", "不是包，包体效果不会生效")

	if def.combat != null:
		for i in def.combat.rules.size():
			var r := def.combat.rules[i] as AbilityRule
			var at := "combat.rules[%d]" % i
			if r == null:
				report.error(at, "规则为空")
				continue
			if r.trigger == null:
				report.error(at + ".trigger", "规则必须有时机")
			if r.cadence == null:
				report.error(at + ".cadence", "规则必须有频率")
			if r.effects.is_empty():
				report.warn(at + ".effects", "规则没有任何效果，触发了也什么都不做")

	if def.adjacency != null:
		var ap := def.adjacency
		if not ap.grant_cells.is_empty() and ap.grant_mods.is_empty() and ap.grant_rules.is_empty():
			report.warn("adjacency.grant", "标了增益格却没有加成也没有附加规则，不会点亮任何东西")
		if not ap.grant_rules.is_empty() and ap.grant_cells.is_empty():
			report.warn("adjacency.grant_rules", "写了附加规则却没有增益格，挂不到任何邻居身上")
		validate_attached_rules(ap.grant_rules, "adjacency.grant_rules", report)
		# 148：受益格只认某类邻居（法杖只收魔晶石）的，数值由那类邻居的供给给，自己不写加成是对的
		if not ap.receive_cells.is_empty() and ap.receive_mods.is_empty() and ap.receive_rules.is_empty() and ap.receive_filter.is_empty():
			report.warn("adjacency.receive", "标了受益格却没有加成也没有受益规则")
		if not ap.receive_rules.is_empty() and ap.receive_cells.is_empty():
			report.warn("adjacency.receive_rules", "写了受益规则却没有受益格，永远挂不上")
		validate_attached_rules(ap.receive_rules, "adjacency.receive_rules", report, false)
		validate_attached_rules(ap.feed_rules, "adjacency.feed_rules", report, false)     # 148：供给的规则挂到宿主身上、跑在宿主身上，同受益规则（时机不限，不许 costs）
		if not ap.feed_filter.is_empty() and not ap.has_feed():
			report.warn("adjacency.feed_filter", "写了「只供给」却没有供给的加成或规则")
		_warn_overlapping_markers(def, report)
	_validate_belt_and_wear(def, report)


## 147 / 148：随身道具只进腰带（带【随身】、不参战、1 格）；耐久要有正的次数
static func _validate_belt_and_wear(def: ItemDef, report: ImportReport) -> void:
	if def.belt_use != null:
		if not def.is_belt():
			report.error("belt_use", "能随身用的道具要带「%s」标签（腰带只收它）" % ItemDef.BELT)
		if def.combat != null:
			report.error("combat", "随身道具不上棋盘，写了战斗也不会生效")
		if def.cell_count() != 1:
			report.error("shape", "随身道具只占 1 格（腰带一格一件）")
		if def.belt_use.effects.is_empty():
			report.warn("belt_use.effects", "能用却什么都不做")
	elif def.is_belt():
		report.warn("tags", "带了「%s」却没写怎么用：只能放在腰带里看着" % ItemDef.BELT)
	if def.wear != null and def.wear.max_charges <= 0:
		report.error("wear.max_charges", "耐久至少 1 次")


## 标记格压在自己轮廓上时提醒。
##
## [b]不是错误，但一定是死数据。[/b] 编译器点亮邻居时会跳过 holder 自己
## （见 BattleCompiler._lit_neighbors 里的 `other == holder.uid`），
## 所以这种格子永远点不亮 —— 既不报错也不生效，是最难自查的一类配置。
##
## 画板已经不让点在自己身上了，但手写的 JSON 和早先存下来的数据还会有。
static func _warn_overlapping_markers(def: ItemDef, report: ImportReport) -> void:
	if def.shape == null or not def.shape.is_valid():
		return
	var own := {}
	for c in def.shape.cells_rotated(0):
		own[c] = true
	for pair in [["grant", def.adjacency.grant_cells], ["receive", def.adjacency.receive_cells]]:
		for c in pair[1]:
			if own.has(c):
				report.warn(
					"adjacency.%s_cells" % pair[0],
					"标记格 (%d, %d) 压在物品自己的格子上，永远点不亮 —— 标记格要在轮廓之外"
						% [(c as Vector2i).x, (c as Vector2i).y]
				)
#endregion


#region 通用填充
## 按反射把 [param data] 的每个键写进 [param obj]。
##
## 未知键**报错而不是忽略** —— 打错一个字段名却静默生效为默认值，
## 是内容作者最难自查的一类问题，报出来才有得改。
static func _fill(
	obj: Object, data: Dictionary, path: String, ctx: Context, report: ImportReport
) -> void:
	var props := {}
	for p in ContentSchema.properties_of(obj):
		props[String(p["name"])] = p
	# 146：记住正在填 buff / 构件，里面的规则不许引用构件
	var in_buff := obj is BuffDef and ctx != null
	var in_part := obj is RulePartDef and ctx != null
	if in_buff:
		ctx.buff_depth += 1
	if in_part:
		ctx.part_depth += 1
	if obj is StatModifier:
		data = _migrate_stat_modifier(data, path, report)
	elif obj is BuffDef:
		data = _migrate_buff(data, path, report)
	elif obj is FaithBonus:
		data = _migrate_faith_bonus(data, path, report)

	for key in data:
		var at := _join(path, String(key))
		if key == "type":
			continue  # 由调用方消费，用来决定造哪个类
		if not props.has(String(key)):
			report.error(at, "未知字段（可用：%s）" % ", ".join(props.keys()))
			continue
		var prop: Dictionary = props[String(key)]
		var coerced = _coerce(obj, prop, obj.get(prop["name"]), data[key], at, ctx, report)
		if coerced != null:
			obj.set(prop["name"], coerced)
	if in_buff:
		ctx.buff_depth -= 1
	if in_part:
		ctx.part_depth -= 1
	# 104（作者定）：暴击的加成一律加算 —— 作用于它们的修饰只能是 ADD
	if obj is StatModifier and BattleStats.additive_only((obj as StatModifier).stat) and (obj as StatModifier).is_mult():
		report.error(path, "%s 只接受加算（mode = ADD）；不能写乘算" % (obj as StatModifier).stat)
	_percent_in(obj, path, report)


## 作者反馈：暴击率 / 暴击伤害这类百分比属性，作者数据按百分数写（20 = 20%），导入时 ÷100 存成运行时的小数。
## 管两处：加算的属性修饰的 amount、基础属性表（`base_stats`）里这类键的值。导出时 [ContentExporter] 乘回去
static func _percent_in(obj: Object, path: String, report: ImportReport) -> void:
	if obj is StatModifier:
		var m := obj as StatModifier
		if not m.is_mult() and BattleStats.is_percent(m.stat):
			_warn_tiny_percent(m.amount, _join(path, "amount"), m.stat, report)
			m.amount = BattleStats.from_percent(m.amount)
		return
	var stats = obj.get("base_stats") if "base_stats" in obj else null
	if not (stats is Dictionary):
		return
	for key in (stats as Dictionary).keys():
		var v = stats[key]
		if (v is float or v is int) and BattleStats.is_percent(StringName(String(key))):
			_warn_tiny_percent(float(v), _join(path, "base_stats." + String(key)), StringName(String(key)), report)
			stats[key] = BattleStats.from_percent(float(v))


static func _warn_tiny_percent(v: float, at: String, stat: StringName, report: ImportReport) -> void:
	if v != 0.0 and absf(v) < 1.0:
		report.warn(at, "%s 按百分数写（20 = 20%%）：%s 只有 %s%%，是不是写成了小数" % [stat, str(v), str(v)])


## 133：旧格式的属性修饰（`mult_category` / `mult_percent` / `flat`）换成 `mode` + `amount`。
## 乘区已经取消，写了 mult_category 只提醒、忽略；一条同时乘又加的拆不了，报错让作者拆成两条
static func _migrate_stat_modifier(data: Dictionary, path: String, report: ImportReport) -> Dictionary:
	if not (data.has("mult_category") or data.has("mult_percent") or data.has("flat")):
		return data
	var out := data.duplicate()
	var pct := float(out.get("mult_percent", 0))
	var flat := float(out.get("flat", 0.0))
	if out.has("mult_category"):
		report.warn(_join(path, "mult_category"), "乘区已取消（133），忽略；乘算都在同一个区里相加")
	out.erase("mult_category")
	out.erase("mult_percent")
	out.erase("flat")
	if pct != 0.0 and flat != 0.0:
		report.error(path, "一条属性修饰只能乘或加（133）：mult_percent 与 flat 都填了，拆成两条")
		return out
	if pct != 0.0:
		out["mode"] = "MULT"
		out["amount"] = pct
	elif flat != 0.0:
		out["mode"] = "ADD"
		out["amount"] = flat
	return out


## 137：buff 的叠层上限取消 —— 老字段 `max_stacks` 换成 `stackable`（1 → 不可叠，其余 → 可叠），提醒一句
static func _migrate_buff(data: Dictionary, path: String, report: ImportReport) -> Dictionary:
	if not data.has("max_stacks"):
		return data
	var out := data.duplicate()
	var cap := int(out["max_stacks"])
	out.erase("max_stacks")
	if not out.has("stackable"):
		out["stackable"] = cap != 1
	report.warn(_join(path, "max_stacks"), "max_stacks 已改成 stackable（137）：可叠层不再有上限%s" % ("（这里原来封顶 %d 层）" % cap if cap > 1 else ""))
	return out


## 137：信仰加成的「最多几份」从 `max_stacks` 改名 `max_shares`（和 buff 的旧字段分开）。旧键照收、不提醒
static func _migrate_faith_bonus(data: Dictionary, _path: String, _report: ImportReport) -> Dictionary:
	if not data.has("max_stacks"):
		return data
	var out := data.duplicate()
	if not out.has("max_shares"):
		out["max_shares"] = out["max_stacks"]
	out.erase("max_stacks")
	return out


static func _join(path: String, key: String) -> String:
	return key if path == "" else path + "." + key


static func _coerce(
	owner: Object, prop: Dictionary, current: Variant, value: Variant,
	path: String, ctx: Context, report: ImportReport
) -> Variant:
	var type := int(prop["type"])
	match type:
		TYPE_BOOL:
			if value is bool:
				return value
			report.error(path, "应为布尔值")
		TYPE_INT:
			if value is String:
				var resolved = ContentSchema.enum_value(owner, prop, value)
				if resolved == null:
					var opts := ContentSchema.enum_options(owner, prop)
					report.error(path, "认不得的取值 '%s'%s" % [
						value, ("（可用：%s）" % ", ".join(opts)) if not opts.is_empty() else ""
					])
					return null
				return resolved
			if value is float or value is int:
				return int(value)
			report.error(path, "应为整数")
		TYPE_FLOAT:
			if value is float or value is int:
				return float(value)
			report.error(path, "应为数字")
		TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2I, TYPE_VECTOR2:
			return _coerce_scalar(type, value, path, report)
		TYPE_DICTIONARY:
			if value is Dictionary:
				# JSON 没有整数：{"shop": [0, 1]} 读回来是 [0.0, 1.0]。还原成整数，
				# 不然导出再导入的文本就变了（约定见 MapGraph.normalize）
				return MapGraph.normalize((value as Dictionary).duplicate(true))
			report.error(path, "应为对象")
		TYPE_ARRAY:
			return _coerce_array(current as Array, value, path, ctx, report)
		TYPE_OBJECT:
			return _make_object(StringName(prop["hint_string"]), value, path, ctx, report)
		_:
			report.error(path, "暂不支持的字段类型 %d" % type)
	return null


## 字符串 / StringName / 向量这几种标量：字段值与数组元素同一套转法。
## int / float **不在这里**：字段值认枚举名、类型不对就报错（[method _coerce]），数组元素直接强转（[method _coerce_array]），两边本来就不同，各留各的
static func _coerce_scalar(builtin: int, value: Variant, path: String, report: ImportReport) -> Variant:
	match builtin:
		TYPE_STRING:
			return str(value)
		TYPE_STRING_NAME:
			return StringName(str(value))
		TYPE_VECTOR2I:
			return _to_vec(value, path, report, true)
		TYPE_VECTOR2:
			return _to_vec(value, path, report, false)
	return null


## `[x, y]` → Vector2i（[param as_int]）/ Vector2；不是两个数的数组报错给 null
static func _to_vec(value: Variant, path: String, report: ImportReport, as_int: bool) -> Variant:
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int(value[0]), int(value[1])) if as_int else Vector2(float(value[0]), float(value[1]))
	report.error(path, "应为 [x, y]")
	return null


static func _coerce_array(
	current: Array, value: Variant, path: String, ctx: Context, report: ImportReport
) -> Variant:
	if not (value is Array):
		report.error(path, "应为数组")
		return null
	var out := ContentSchema.empty_like(current)
	var element_class := ContentSchema.array_element_class(current)
	var builtin := current.get_typed_builtin()
	var i := -1
	for raw in value:
		i += 1
		var at := "%s[%d]" % [path, i]
		var item: Variant = null
		match builtin:
			TYPE_OBJECT:
				item = _make_object(element_class, raw, at, ctx, report)
			TYPE_STRING_NAME, TYPE_STRING, TYPE_VECTOR2I, TYPE_VECTOR2:
				item = _coerce_scalar(builtin, raw, at, report)
			TYPE_INT:
				item = int(raw)
			TYPE_FLOAT:
				item = float(raw)
			_:
				item = raw
		if item != null:
			out.append(item)
	return out
#endregion


#region 造对象
## 造一个 [param class_id] 类型（或其子类）的实例。
static func _make_object(
	class_id: StringName, value: Variant, path: String, ctx: Context, report: ImportReport
) -> Object:
	if value == null:
		return null

	# --- 例外一：形状。JSON 里是 0/1 数字串，和 ItemShape 的字段不同构，
	#     硬要作者写 {"cells": [[0,0],[1,0]]} 是在为难人。
	if class_id == &"ItemShape":
		return _make_shape(value, path, report)

	# --- 例外二：增益可以按 id 引用先前导入的那一份。
	#     内联也允许 —— 只被一件道具用到的 buff 没必要单开一个文件。
	if class_id == &"BuffDef" and value is String:
		var found := ctx.find_buff(StringName(value))
		if found == null:
			report.error(path, "找不到增益 '%s'（已知：%s）" % [
				value, ", ".join(ctx.buffs.keys())
			])
		return found

	# --- 例外三（146）：规则构件按 `"@id"` 引用，复制一份
	if value is String and String(value).begins_with("@") and RulePartDef.SLOTS.values().has(class_id):
		return _resolve_part(class_id, String(value).substr(1), path, ctx, report)

	if not (value is Dictionary):
		report.error(path, "应为对象")
		return null
	var data := value as Dictionary

	var inst: Object = null
	if ContentSchema.ABSTRACT_ROOTS.has(class_id):
		inst = _from_registry(class_id, data, path, report)
	else:
		var script := ContentSchema.script_of(class_id)
		# 字段声明成引擎基类（`generator_config: Resource`）时，JSON 里的 type 说造哪个脚本类。
		# 只认 class_name 过的类，而且造出来得真是那个基类的东西
		if script == null and data.has("type"):
			var wanted := StringName(str(data["type"]))
			script = ContentSchema.script_of(wanted)
			if script == null:
				report.error(path, "认不得的 type '%s'" % wanted)
				return null
		if script == null:
			report.error(path, "认不得的类型 %s" % class_id)
			return null
		inst = script.new()
		if data.has("type") and String(class_id) != "" and not ContentSchema.instance_is(inst, class_id) \
				and not ClassDB.is_parent_class(inst.get_class(), String(class_id)):
			report.error(path, "'%s' 不是 %s" % [data["type"], class_id])
			return null

	if inst == null:
		return null
	_fill(inst, data, path, ctx, report)
	return inst


## 抽象基类按 `type` 去注册表查。**这是导入器唯一认识「效果」的地方**，
## 而它认识的也只是一张名字到脚本路径的表。
static func _from_registry(
	class_id: StringName, data: Dictionary, path: String, report: ImportReport
) -> Object:
	if not data.has("type"):
		report.error(path, "%s 必须写明 type" % class_id)
		return null
	var type_name := StringName(str(data["type"]))
	var tables: Array = ContentSchema.ABSTRACT_ROOTS[class_id]

	for table in tables:
		if ContentRegistries.has_type(table, type_name):
			var inst := ContentRegistries.instantiate(table, type_name)
			# 同名可能落在别的作用域里，确认它真的是要的那一支
			if not ContentSchema.instance_is(inst, class_id):
				report.error(path, "'%s' 不是 %s" % [type_name, class_id])
				return null
			return inst

	var known: Array[String] = []
	for table in tables:
		for n in ContentRegistries.type_names(table):
			known.append(String(n))
	known.sort()
	report.error(path, "认不得的 type '%s'（可用：%s）" % [type_name, ", ".join(known)])
	return null


## 形状：接受 "11\n10" 或 ["11", "10"]，1 为占格、0 为空。
static func _make_shape(value: Variant, path: String, report: ImportReport) -> ItemShape:
	var text := ""
	if value is String:
		text = value
	elif value is Array or value is PackedStringArray:
		var rows: Array[String] = []
		for r in value:
			rows.append(str(r))
		text = "\n".join(rows)
	else:
		report.error(path, "形状应为 0/1 数字串，或每行一个的字符串数组")
		return null

	var shape := ItemShape.from_bits(text)
	if not shape.is_valid():
		report.error(path, "形状为空 —— 至少要有一个 1")
		return null
	return shape
#endregion
