## JSON → 引擎资源（架构文档 10.2）。
##
## [b]本类不认识任何一种具体效果。[/b] 它只做三件事：
##
## 1. 问 Godot 目标类有哪些属性、各是什么类型（[ContentSchema]）；
## 2. 碰到抽象基类就按 JSON 里的 `type` 去 [EffectRegistry] 查；
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
	## id -> NodeRules。章节对着它查
	var node_rules: Dictionary = {}
	## id -> EconomyRules。章节对着它查
	var economy_rules: Dictionary = {}
	## id -> LoadoutDef
	var loadouts: Dictionary = {}

	func register_buff(def: BuffDef) -> void:
		if def != null and def.id != &"":
			buffs[def.id] = def

	func register_item(def: ItemDef) -> void:
		if def != null and def.id != &"":
			items[def.id] = def

	func register_enemy(def: EnemyDef) -> void:
		if def != null and def.id != &"":
			enemies[def.id] = def

	func register_pool(pool: EnemyPool) -> void:
		if pool != null and pool.id != &"":
			pools[pool.id] = pool

	func register_drop_rule(rule: DropRule) -> void:
		if rule != null and rule.id != &"":
			drop_rules[rule.id] = rule

	func register_node_rules(rules: NodeRules) -> void:
		if rules != null and rules.id != &"":
			node_rules[rules.id] = rules

	func register_economy_rules(rules: EconomyRules) -> void:
		if rules != null and rules.id != &"":
			economy_rules[rules.id] = rules

	func register_loadout(def: LoadoutDef) -> void:
		if def != null and def.id != &"":
			loadouts[def.id] = def

	## id -> CharacterDef
	var characters: Dictionary = {}

	func register_character(def: CharacterDef) -> void:
		if def != null and def.id != &"":
			characters[def.id] = def

	## id -> DifficultyDef
	var difficulties: Dictionary = {}

	func register_difficulty(def: DifficultyDef) -> void:
		if def != null and def.id != &"":
			difficulties[def.id] = def

	## id -> HunterDef
	var hunters: Dictionary = {}

	func register_hunter(def: HunterDef) -> void:
		if def != null and def.id != &"":
			hunters[def.id] = def

	## id -> MetaRules
	var meta_rules: Dictionary = {}

	func register_meta_rules(rules: MetaRules) -> void:
		if rules != null and rules.id != &"":
			meta_rules[rules.id] = rules

	## id -> FaithDef（8-4）。道具的信仰对象标签对着它查
	var faiths: Dictionary = {}

	func register_faith(def: FaithDef) -> void:
		if def != null and def.id != &"":
			faiths[def.id] = def

	## id -> RunBuffDef
	var run_buffs: Dictionary = {}

	func register_run_buff(def: RunBuffDef) -> void:
		if def != null and def.id != &"":
			run_buffs[def.id] = def

	## id -> EventDef。节点规则对着它查
	var events: Dictionary = {}

	func register_event(def: EventDef) -> void:
		if def != null and def.id != &"":
			events[def.id] = def

	## id -> AchievementDef（091）
	var achievements: Dictionary = {}

	func register_achievement(def: AchievementDef) -> void:
		if def != null and def.id != &"":
			achievements[def.id] = def

	## 道具里带某个标签的有几件。批量导入时才有意义 —— 单独导一个敌人时上下文是空的，
	## 这类「对着别的东西查」的校验就跳过（见 _validate_enemy）
	func items_tagged(tag: StringName) -> int:
		var n := 0
		for id in items:
			if (items[id] as ItemDef).tags.has(tag):
				n += 1
		return n


#region 顶层入口
static func import_buff(data: Dictionary, ctx: Context, report: ImportReport) -> BuffDef:
	var def := BuffDef.new()
	_fill(def, data, "", ctx, report)
	if def.id == &"":
		report.error("id", "增益必须有 id")
	validate_buff_duration(def, "", report)
	ctx.register_buff(def)
	return def


## 作者定的规矩（085）：可叠层的 buff 永续，不许填时长；不可叠层的才可以过期
static func validate_buff_duration(def: BuffDef, path: String, report: ImportReport) -> void:
	if def != null and def.is_stackable() and def.duration_sec > 0.0:
		report.error(path + "duration_sec", "「%s」可叠层（max_stacks %d），可叠层的 buff 永续，不填时长" % [def.id, def.max_stacks])


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


static func import_set(data: Dictionary, ctx: Context, report: ImportReport) -> ItemSetDef:
	var def := ItemSetDef.new()
	_fill(def, data, "", ctx, report)
	if def.id == &"":
		report.error("id", "套装必须有 id")
	if def.tiers.is_empty():
		report.warn("tiers", "套装没有任何档位，永远不会生效")
	return def


static func import_item(data: Dictionary, ctx: Context, report: ImportReport) -> ItemDef:
	var def := ItemDef.new()
	_fill(def, data, "", ctx, report)
	_validate_item(def, report)
	_validate_item_faith(def, ctx, report)
	_validate_item_buffs(def, report)
	ctx.register_item(def)
	return def


## 信仰体系（8-4，报告 081）
## 合成配方（084）：恰好两件输入、一件产物，都得是道具库里有的（批量导入时道具在前，查得到）
static func import_recipe(data: Dictionary, ctx: Context, report: ImportReport) -> RecipeDef:
	var def := RecipeDef.new()
	_fill(def, data, "", ctx, report)
	if def.id == &"":
		report.error("id", "配方必须有 id")
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
	if def.id == &"":
		report.error("id", "信仰必须有 id")
	if String(def.id).begins_with(FaithDef.TAG_PREFIX) or String(def.id).contains(":"):
		report.error("id", "id 里别带前缀或冒号：道具上的标签会自动写成 %s<id>" % FaithDef.TAG_PREFIX)
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


## 信仰标签（作者定的机制）：信仰道具带 `faith` + 恰好一个 `faith:<id>`；对象标签得是登记过的信仰（批量导入时）
static func _validate_item_faith(def: ItemDef, ctx: Context, report: ImportReport) -> void:
	var objects: Array[StringName] = []
	for t in def.tags:
		if String(t).begins_with(FaithDef.TAG_PREFIX):
			objects.append(t)
	if def.has_faith() and objects.size() != 1:
		report.error("tags", "带 faith 的道具得恰好有一个信仰对象标签（%s<id>），现在有 %d 个" % [FaithDef.TAG_PREFIX, objects.size()])
	elif not def.has_faith() and not objects.is_empty():
		report.error("tags", "带了信仰对象标签 %s 却没有 faith 标签" % objects[0])
	if def.has_faith() and objects.size() == 1 and not ctx.faiths.is_empty():
		var fid := FaithDef.id_of_tag(objects[0])
		if not ctx.faiths.has(fid):
			report.error("tags", "没有登记过的信仰 '%s'（已知：%s）" % [fid, ", ".join(ctx.faiths.keys())])
	# 信力解锁的功能（082）只对信仰道具有意义；阶从 1 起
	if not def.faith_bonuses.is_empty() and not def.has_faith():
		report.error("faith_bonuses", "只有信仰道具才有按信力解锁的功能")
	for i in def.faith_bonuses.size():
		var b := def.faith_bonuses[i] as FaithBonus
		if b == null:
			report.error("faith_bonuses[%d]" % i, "空的加成")
		elif b.tier < 1:
			report.error("faith_bonuses[%d].tier" % i, "阶从 1 起")
		elif b.mods.is_empty() and b.rules.is_empty():
			report.error("faith_bonuses[%d]" % i, "加成得有修饰或规则")


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
static func import_character(data: Dictionary, ctx: Context, report: ImportReport) -> CharacterDef:
	var def := CharacterDef.new()
	_fill(def, data, "", ctx, report)
	if def.id == &"":
		report.error("id", "角色必须有 id")
	if def.vitality_max < 1:
		report.error("vitality_max", "体力上限至少 1")
	if def.board_size.x < 1 or def.board_size.y < 1:
		report.error("board_size", "棋盘至少 1×1")
	if def.carry_max_items < -1 or def.carry_rarity_cap < -1:
		report.error("carry_max_items", "上限只能是 -1（不限）或非负数")
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
	if def.id == &"":
		report.error("id", "难度必须有 id")
	if def.level < 0:
		report.error("level", "档位不能为负（0 = 普通）")
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
	if def.id == &"":
		report.error("id", "成就必须有 id")
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


## 猎手（069 / 071）：数全得合理；行动逻辑可空（= 不动）；战败后果不能是空的；指定的敌人池得存在（批量导入时）
static func import_hunter(data: Dictionary, ctx: Context, report: ImportReport) -> HunterDef:
	var def := HunterDef.new()
	_fill(def, data, "", ctx, report)
	if def.id == &"":
		report.error("id", "猎手必须有 id")
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
	for i in def.loss_outcomes.size():
		if def.loss_outcomes[i] == null:
			report.error("loss_outcomes[%d]" % i, "空的战败后果")
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
	if def.id == &"":
		report.error("id", "buff 必须有 id")
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
	if def.id == &"":
		report.error("id", "事件必须有 id")
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
			report.error("options[%d].outcomes" % i, "传送不能和给道具放在同一个选项里：离开发生过事的点暂存区会清空，给的东西立刻没了")
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
	if rules.id == &"":
		report.error("id", "局外规则必须有 id")
	if rules.warehouse_size.x < 1 or rules.warehouse_size.y < 1:
		report.error("warehouse_size", "仓库至少 1×1")
	if rules.first_kit != &"" and not ctx.loadouts.is_empty() and not ctx.loadouts.has(rules.first_kit):
		report.error("first_kit", "找不到开局装备 '%s'" % rules.first_kit)
	ctx.register_meta_rules(rules)
	return rules


## 清单不能空；每件得存在；至少一个包 —— 棋盘上只有包里的东西参战（3.2），没有包一格都用不了
static func _validate_loadout_def(def: LoadoutDef, ctx: Context, report: ImportReport) -> void:
	if def.id == &"":
		report.error("id", "开局装备必须有 id")
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
	if not has_bag:
		report.error("items", "开局至少带一个包：棋盘上只有包里的东西参战（3.2），没有包一格都用不了")


## 钱的数全得非负；商店至少一格、至少有一档稀有度能上架；刷新不能越刷越便宜
static func _validate_economy_rules(rules: EconomyRules, report: ImportReport) -> void:
	if rules.id == &"":
		report.error("id", "经济规则必须有 id")
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
	if rules.id == &"":
		report.error("id", "节点规则必须有 id")
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
	for key in rules.event_weights:
		if not NodeRules.EVENT_OUTCOMES.has(StringName(String(key))):
			report.error("event_weights", "认不得的事件结果 '%s'（只能是 %s）" % [key, ", ".join(NodeRules.EVENT_OUTCOMES)])
	if rules.rest_restore < 0 or rules.event_restore < 0:
		report.error("rest_restore", "回的体力不能为负")
	if rules.battle_time_limit <= 0.0:
		report.error("battle_time_limit", "战斗时限应为正")
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


## 作者定的形状写成校验：概率在 0～1，**稀有度越高基础掉落率越低**（非递增），珍宝的稀有度得是真的稀有度、权重为正。
static func _validate_drop_rule(rule: DropRule, report: ImportReport) -> void:
	if rule.id == &"":
		report.error("id", "掉落规则必须有 id")
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
	if def.id == &"":
		report.error("id", "敌人必须有 id")
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
	if pool.id == &"":
		report.error("id", "敌人池必须有 id")
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
	return def


## 比引擎严格：地图来源得真的能拿出图来。生成器没登记、预设文件不在，都是内容错误。
static func _validate_chapter(def: ChapterDef, ctx: Context, report: ImportReport) -> void:
	if def.id == &"":
		report.error("id", "章节必须有 id")
	if def.difficulty < 0:
		report.error("difficulty", "难度不能为负")
	if def.enemy_pool != &"" and not ctx.pools.is_empty() and not ctx.pools.has(def.enemy_pool):
		report.error("enemy_pool", "找不到敌人池 '%s'（已知：%s）" % [def.enemy_pool, ", ".join(ctx.pools.keys())])
	if def.drop_rule != &"" and not ctx.drop_rules.is_empty() and not ctx.drop_rules.has(def.drop_rule):
		report.error("drop_rule", "找不到掉落规则 '%s'（已知：%s）" % [def.drop_rule, ", ".join(ctx.drop_rules.keys())])
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
	if def.id == &"":
		report.error("id", "物品必须有 id")
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
		if not ap.grant_cells.is_empty() and ap.grant_mods.is_empty():
			report.warn("adjacency.grant", "标了增益格却没有加成，不会点亮任何东西")
		if not ap.receive_cells.is_empty() and ap.receive_mods.is_empty():
			report.warn("adjacency.receive", "标了受益格却没有加成")
		_warn_overlapping_markers(def, report)


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
		TYPE_STRING:
			return str(value)
		TYPE_STRING_NAME:
			return StringName(str(value))
		TYPE_VECTOR2I:
			return _to_vec2i(value, path, report)
		TYPE_VECTOR2:
			return _to_vec2(value, path, report)
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


static func _to_vec2i(value: Variant, path: String, report: ImportReport) -> Variant:
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	report.error(path, "应为 [x, y]")
	return null


static func _to_vec2(value: Variant, path: String, report: ImportReport) -> Variant:
	if value is Array and (value as Array).size() == 2:
		return Vector2(float(value[0]), float(value[1]))
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
	var i := -1
	for raw in value:
		i += 1
		var at := "%s[%d]" % [path, i]
		var item: Variant = null
		match current.get_typed_builtin():
			TYPE_OBJECT:
				item = _make_object(element_class, raw, at, ctx, report)
			TYPE_STRING_NAME:
				item = StringName(str(raw))
			TYPE_STRING:
				item = str(raw)
			TYPE_VECTOR2I:
				item = _to_vec2i(raw, at, report)
			TYPE_VECTOR2:
				item = _to_vec2(raw, at, report)
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
		var found: BuffDef = ctx.buffs.get(StringName(value), null)
		if found == null:
			report.error(path, "找不到增益 '%s'（已知：%s）" % [
				value, ", ".join(ctx.buffs.keys())
			])
		return found

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
		if EffectRegistry.has_type(table, type_name):
			var inst := EffectRegistry.instantiate(table, type_name)
			# 同名可能落在别的作用域里，确认它真的是要的那一支
			if not ContentSchema.instance_is(inst, class_id):
				report.error(path, "'%s' 不是 %s" % [type_name, class_id])
				return null
			return inst

	var known: Array[String] = []
	for table in tables:
		for n in EffectRegistry.type_names(table):
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
