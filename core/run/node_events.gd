## 踩到一个点，发生什么（架构文档 5.6 / 6.2 / 7.1，M4-4）。[MapTravel.on_node_event] 的真正接收方。
##
## 只接「节点类型 → 发生什么」的逻辑，界面与转场（M6）不在这里：每种结果发一个信号，谁画谁接。
## 数值一个都不写死 —— 输了扣多少、休息回多少、随机点变什么，全从 [NodeRules] 来（7.1）。
##
## - 战斗 / 精英 / 核心：拿玩家的战斗单位与节点里的敌人打一场 [BattleSim]（战斗中没有任何玩家操作，4.1）。
##   赢了掉落（[DropResolver]）装进尸体容器；输了扣体力（core 输了直接战败，不扣）；**不论输赢节点都消耗掉**（7.1）。
##   平局按输算：打不死也没打过。
## - 搜索：开一个 [SearchSession]，搜几次玩家自己拧；遭遇了就地打一场，打完这个点就用过了。
## - 随机：先按权重变成一种类型（[NodeRules.random_pick]），是战斗就现造敌人，再当那种类型处理。
## - 休息回体力、商店与撤离只发信号、常规事件按权重出一种结果（占位）。
##
## 随机数只用节点的 `content_seed` 派生：同一局同一个点，结果一样。
class_name NodeEvents
extends RefCounted

signal revealed(node: MapNode, type: StringName)
signal battle_finished(node: MapNode, result: BattleResult, won: bool)
signal loot_ready(node: MapNode, corpse: GridInventory)
signal search_opened(node: MapNode, session: SearchSession)
signal search_closed(node: MapNode, haul: GridInventory, reason: StringName)
signal rested(node: MapNode, restored: int)
## 打赢了进账多少（6.6）
signal rewarded(node: MapNode, amount: int)
## 商店开门。session 为 null = 这一章没有经济规则，店是空的
signal shop_opened(node: MapNode, session: ShopSession)
signal shop_closed(node: MapNode)
signal event_resolved(node: MapNode, outcome: StringName, detail: Dictionary)
## 到了撤离点。fee > 0 = 付费的（PaidExtracts），撤离动作（M6）先 pay_extract_fee
signal extract_reached(node: MapNode, fee: int)
## 战败：&"boss_lost"（核心输了）/ &"vitality_depleted"（体力归零）。结局由上层判（GameDirector，7.1）
signal defeated(reason: StringName)

var graph: MapGraph = null
var travel: MapTravel = null
var vitality: Vitality = null
var rules: NodeRules = null
var pool: EnemyPool = null
var enemies: EnemyDatabase = null
var items: ItemDatabase = null
var drop_rule: DropRule = null
## 钱（6.6）。null = 这一局不算钱
var wallet: Wallet = null
var economy: EconomyRules = null
var difficulty: int = 0
var scale_id: StringName = &""
## 玩家的战斗单位：`Callable() -> CombatantSpec`。开战那一刻编译（4.2 是纯函数）
var player_spec: Callable = Callable()
## 掉落上下文：`Callable() -> LootContext`。没设就造一个只带难度的
var loot_context: Callable = Callable()

var current_search: SearchSession = null
var current_shop: ShopSession = null
var _depths: Dictionary = {}
## 已结束的搜索会话里一共搜了几次（正在搜的那个另算，见 searches_total）
var _searches_closed: int = 0


func _init(p_graph: MapGraph = null) -> void:
	graph = p_graph
	if graph != null:
		_depths = EnemyPlacer.depths_of(graph)


## 挂到一次旅程上
func bind(p_travel: MapTravel) -> void:
	travel = p_travel
	if travel != null:
		travel.on_node_event = handle
		if graph == null:
			graph = travel.graph
			_depths = EnemyPlacer.depths_of(graph)


## 踩上一个还没用过的点
func handle(node: MapNode) -> void:
	if node == null:
		return
	var type := node.type
	if type == &"random":
		type = reveal(node)
	match type:
		&"battle", &"elite", &"core":
			_fight(node, type, node.content)
			_visited(node)
		&"search":
			_open_search(node)
		&"rest":
			var got := vitality.restore(rules.rest_restore, &"rest") if vitality != null and rules != null else 0
			rested.emit(node, got)
			_visited(node)
		&"shop":
			_open_shop(node)
		&"event":
			_event(node)
			_visited(node)
		&"extract":
			extract_reached.emit(node, PaidExtracts.fee_of(node))
			_visited(node)
		_:
			_visited(node)


## 随机点变成什么。记进内容里（`resolved_type`），是战斗就现造敌人
func reveal(node: MapNode) -> StringName:
	var already := String(node.content.get("resolved_type", ""))
	if already != "":
		return StringName(already)
	var type := rules.random_pick(_rng_for(node, "reveal")) if rules != null else &"battle"
	node.content["resolved_type"] = String(type)
	if type == &"battle" and not EnemyKit.has_enemy(node.content):
		var built := _enemy_for(node, &"battle", _rng_for(node, "enemy"))
		for key in built:
			node.content[key] = built[key]
	revealed.emit(node, type)
	return type


## 本局累计搜索次数（含正在搜的这个点已经搜过的）
func searches_total() -> int:
	return _searches_closed + (current_search.searches_done if current_search != null else 0)


## 探索度：总步数与累计搜索次数。踩上去才造的敌人（随机点、搜索遭遇）按它抬档（StrengthRule 的探索度那一组）
func exploration() -> Dictionary:
	return {
		"steps": travel.clock.total if travel != null and travel.clock != null else 0,
		"searches": searches_total(),
	}


## 这个点现在算什么类型（随机点揭开之后）
static func effective_type(node: MapNode) -> StringName:
	var resolved := String(node.content.get("resolved_type", ""))
	return StringName(resolved) if resolved != "" else node.type


## 打一场。返回赢没赢
func _fight(node: MapNode, type: StringName, content: Dictionary) -> bool:
	var enemy := EnemyKit.spec_of(content, enemies, pool, items) if not content.is_empty() else null
	if enemy == null or not player_spec.is_valid():
		return false     # 没有敌人（这一章没有敌人池）或没有玩家：点空着，当走过
	var me: CombatantSpec = player_spec.call()
	var limit := rules.battle_time_limit if rules != null else 60.0
	var result := BattleSim.run(me, enemy, _rng_for(node, "battle"), limit)
	var won := result.winner == 0
	battle_finished.emit(node, result, won)
	if won:
		var ctx := _loot_ctx()
		var rolled := DropResolver.roll(content, drop_rule, ctx, items, _rng_for(node, "loot")) \
			if drop_rule != null else {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
		loot_ready.emit(node, DropResolver.corpse_of(content, rolled, items))
		if wallet != null and economy != null:
			var amount := economy.battle_reward(int(content.get("strength", 0)), float(_depths.get(node.id, 0.0)), difficulty)
			wallet.earn(amount, &"battle")
			rewarded.emit(node, amount)
	elif type == &"core":
		defeated.emit(&"boss_lost")     # 规则不是数值：BOSS 输了直接战败，连 spend 都不调（7.1）
	elif vitality != null and rules != null:
		vitality.spend(rules.loss_cost_of(type), &"battle_lost")
		if vitality.is_depleted():
			defeated.emit(&"vitality_depleted")
	return won


func _open_search(node: MapNode) -> void:
	if rules == null or rules.search == null:
		_visited(node)
		return
	var session := SearchSession.new(node, rules.search, items, _rng_for(node, "search"), float(_depths.get(node.id, 0.0)))
	session.encounter_builder = func() -> Dictionary:
		return _enemy_for(node, &"search", _rng_for(node, "ambush:%d" % session.searches_done))
	session.ended.connect(func(reason: StringName): _close_search(node, session, reason))
	current_search = session
	search_opened.emit(node, session)


## 商店：开一个会话，玩家买、刷新、走；走了才算用过
func _open_shop(node: MapNode) -> void:
	if economy == null or wallet == null or items == null:
		shop_opened.emit(node, null)
		_visited(node)
		return
	var session := ShopSession.new(node, economy, items, wallet, float(_depths.get(node.id, 0.0)))
	session.closed.connect(func():
		current_shop = null
		shop_closed.emit(node)
		_visited(node))
	current_shop = session
	shop_opened.emit(node, session)


## 这个撤离点收多少
func extract_fee(node: MapNode) -> int:
	return PaidExtracts.fee_of(node)


## 付撤离费。免费的直接 true；付不起 false、一分不动。撤离动作本身是 M6 的事，它先调这个
func pay_extract_fee(node: MapNode) -> bool:
	var fee := extract_fee(node)
	if fee <= 0:
		return true
	return wallet != null and wallet.spend(fee, &"extract")


func _close_search(node: MapNode, session: SearchSession, reason: StringName) -> void:
	if reason == &"encounter":
		_fight(node, &"search", session.encounter)
	_searches_closed += session.searches_done
	current_search = null
	search_closed.emit(node, session.haul(), reason)
	_visited(node)


func _event(node: MapNode) -> void:
	var outcome := rules.event_pick(_rng_for(node, "event")) if rules != null else &"story"
	var detail := {}
	match outcome:
		&"restore":
			detail["restored"] = vitality.restore(rules.event_restore, &"event") if vitality != null else 0
		&"item":
			var got := SearchSession.draw_items(rules.search, items, float(_depths.get(node.id, 0.0)), node.danger,
				_rng_for(node, "event_item"), rules.event_item_rarity_cap) if rules.search != null else [] as Array[StringName]
			detail["items"] = got.slice(0, 1)
	node.content["outcome"] = String(outcome)
	event_resolved.emit(node, outcome, detail)


## 现造一个敌人：把这个点当 [param as_type] 看（随机点揭成战斗、搜索点遭遇）
func _enemy_for(node: MapNode, as_type: StringName, rng: RandomNumberGenerator) -> Dictionary:
	if pool == null or enemies == null or items == null:
		return {}
	var view := MapNode.from_dict(node.to_dict())
	view.type = as_type
	# 踩上去才造的敌人跟探索度挂钩：走得越远、搜得越多，遇到的越强
	var built := EnemyPlacer.place_one(view, pool, enemies, items, float(_depths.get(node.id, 0.0)), difficulty, scale_id, rng, exploration())
	return built.get("content", {})


func _loot_ctx() -> LootContext:
	if loot_context.is_valid():
		return loot_context.call()
	var ctx := LootContext.new()
	ctx.difficulty = difficulty
	return ctx


func _visited(node: MapNode) -> void:
	if travel != null:
		travel.mark_visited(node.id)
	else:
		node.state = MapNode.State.VISITED


func _rng_for(node: MapNode, tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [node.content_seed, tag])
	return rng
