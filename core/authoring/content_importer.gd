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
	ctx.register_buff(def)
	return def


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
	ctx.register_item(def)
	return def


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
	_validate_node_rules(rules, report)
	ctx.register_node_rules(rules)
	return rules


## 随机点只能变成 A/S/R/V/Q（5.4：不会变成精英或 BOSS）；遭遇曲线非递减、在 0～1；件数范围合法；扣的体力非负。
static func _validate_node_rules(rules: NodeRules, report: ImportReport) -> void:
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
	for sid in def.signature:
		if not ctx.items.has(sid):
			report.error("signature", "找不到招牌道具 '%s'" % sid)
		elif (ctx.items[sid] as ItemDef).is_bag:
			report.error("signature", "招牌道具 '%s' 是个包 —— 敌人的棋盘不放包" % sid)


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
