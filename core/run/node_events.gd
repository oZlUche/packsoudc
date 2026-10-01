## 踩到一个点，发生什么（架构文档 5.6 / 6.2 / 7.1，M4-4）。[MapTravel.on_node_event] 的真正接收方。
##
## 只接「节点类型 → 发生什么」的逻辑，界面与转场（M6）不在这里：每种结果发一个信号，谁画谁接。
## 数值一个都不写死 —— 输了扣多少、休息回多少、随机点变什么，全从 [NodeRules] 来（7.1）。
##
## - 战斗 / 精英 / 核心：拿玩家的战斗单位与节点里的敌人打一场 [BattleSim]（战斗中没有任何玩家操作，4.1）。
##   赢了掉落（[DropResolver]）装进尸体容器；输了扣体力（core 输了直接战败，不扣）；**不论输赢节点都消耗掉**（7.1）。
##   平局按输算：打不死也没打过。
##   **开打前先停一下**（084，[member pause_before_battle] 开着时）：把这一场记进 [member pending_battle]、发 [signal battle_pending]，
##   等玩家在战前准备屏整理完背包按「开战」（[method start_pending_battle]）才真打；关着（测试、批量工具、猎手）就同步打。
## - 搜索（084 作者定的循环）：事件屏上选「搜索」= 开会话（第一次）并**搜一次**，搜索屏把这一次的收获亮出来；玩家关闭搜索屏
##   （[method pause_search]）回到事件屏（规则 / 节点内容里定的 again / done 事件：再搜一次、或走）。掷中遭遇的那一次什么都翻不到，
##   直接过「遇敌」事件（迎战 = start_battle 打会话里的遭遇），打完过「搜索点被余波摧毁」事件，敌人的战利品照掉；这个点就用过了。
##   没配这些事件（老路 / 没有事件层）：关闭 = 离开、遭遇 = 直接开打。
## - 随机：先按权重变成一种类型（[NodeRules.random_pick]），是战斗就现造敌人，再当那种类型处理。
## - 休息回体力、商店与撤离只发信号、常规事件按权重出一种结果（占位）。
##
## 随机数只用节点的 `content_seed` 派生：同一局同一个点，结果一样。
class_name NodeEvents
extends RefCounted

signal revealed(node: MapNode, type: StringName)
signal battle_finished(node: MapNode, result: BattleResult, won: bool)
signal loot_ready(node: MapNode, corpse: GridInventory)
## 087：核心点的 BOSS 倒下了（战利品已经交出去）：持有方据此直接撤离结算
signal boss_defeated(node: MapNode)
signal search_opened(node: MapNode, session: SearchSession)
## 084：该给玩家看搜索屏了（每搜一次一回，第一次紧跟在 search_opened 后面）
signal search_shown(node: MapNode, session: SearchSession)
signal search_closed(node: MapNode, haul: GridInventory, reason: StringName)
signal rested(node: MapNode, restored: int)
## 打赢了进账多少（6.6）
signal rewarded(node: MapNode, amount: int)
## 商店开门。session 为 null = 这一章没有经济规则，店是空的
signal shop_opened(node: MapNode, session: ShopSession)
signal shop_closed(node: MapNode)
## 092：踩上保险箱点（没锁就发；锁上了这个点算用过）
signal safe_opened(node: MapNode)
## 093：神坛（休息处的「神坛」选项）：开了
signal altar_opened(node: MapNode)
signal event_resolved(node: MapNode, outcome: StringName, detail: Dictionary)
## 到了撤离点。fee > 0 = 付费的（PaidExtracts），撤离动作（M6）先 pay_extract_fee
signal extract_reached(node: MapNode, fee: int)
## 战败：&"boss_lost"（核心输了）/ &"fatal_loss"（这一场写了必死）/ &"vitality_depleted"（体力归零）。结局由上层判（GameDirector，7.1）
signal defeated(reason: StringName)

## 088（作者定）：**战败代价跟战斗绑定**。进入战斗的函数带一个 `loss_cost`：没写（LOSS_DEFAULT = -1）按节点内容的 `loss_cost`、
## 再按节点规则的 `loss_cost[type]`（核心点默认必死）；写了就用写的 —— 0 = 无代价，LOSS_DEATH = 必死（直接战败），大于 1 = 扣那么多体力
const LOSS_DEFAULT := -1
const LOSS_DEATH := -2

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
## 091：局外状态（旗标）；沙盒里 null
var meta: MetaState = null
var economy: EconomyRules = null
var difficulty: int = 0
var scale_id: StringName = &""
## 101 第 3 刀：一局的能力都走这张带类型的表（编译玩家、掉落上下文、地图 buff、撤离、传送、保险箱、赐福、猎手……）。
## 默认那一份全是「没人接」的默认值，所以沙盒与测试不接也能跑；正式一局由 [RunState] 换成它自己的那份
var hooks: RunHooks = RunHooks.new()

## 事件层（063）：定义表由持有方给（id → EventDef）。**空表 = 没有事件层**，每个点踩上去直接发生（老路）
var event_defs: Dictionary = {}
## 正在等玩家选的事件：{"node": id, "event": id, "type": 这个点算什么类型}。跟着存档走，读档回来还在这一屏
var pending: Dictionary = {}
## 运行时合成的事件（猎手开打前的那一屏，071）：id → EventDef，和 event_defs 一起查。持有方装机制时登记
var extra_defs: Dictionary = {}
## 8-3：事件的条件与后果看得见的容器（有某道具 / 失去道具）。持有方给；null = 没有
var board: ItemContainer = null
var storage: ItemContainer = null
## 这一局已经在这里判了战败：之后不再挪人、不再开打
var over: bool = false
## 8-3：事件把这个点改成了别的类型（地图重画）
signal type_changed(node: MapNode, type: StringName)
## 8-3：事件里原地耗了几个行动点
signal waited(node: MapNode, actions: int)
## 踩上一个配了事件的点：先给玩家看，选了才往下走
signal event_pending(node: MapNode, def: EventDef)
## 082：玩家选了一个选项（条件过了、后果执行之后）；信力的「事件中选特定选项」看它的标签
signal option_chosen(node: MapNode, option: EventOption)
## 082：已经免罚了几次败仗（RunContext.free_losses 是配额）。跟着存档走
var losses_forgiven: int = 0
## 084：开打前要不要停下来等玩家（战前准备屏）。正式游戏（GameFlow）开；直接驱动 RunState 的测试与批量工具关，照旧同步打
var pause_before_battle: bool = false
## 084：等着开打的那一场：{"node": id, "type": 按什么类型打, "content": 敌人内容, "kind": "node" / "search"}。
## kind 决定打完接着做什么（点用过 / 收搜索会话）。跟着存档走；读档回来还停在战前准备屏
var pending_battle: Dictionary = {}
## 084：开打前先停下来了：战前准备屏画它（敌人的棋盘从 content 重建，[method EnemyKit.board_of]）
signal battle_pending(node: MapNode, type: StringName, content: Dictionary)

var current_search: SearchSession = null
var current_shop: ShopSession = null
## 最近一场的双方战斗单位：{"player": CombatantSpec, "enemy": CombatantSpec, "node": id}。
## 回放要把日志里的 uid 写成名字（4.8：名字是表现层的事，不进日志），从这里查
var last_battle: Dictionary = {}
## 最近一次「发生过事」的点（打了、搜了、开了店、休息了、出了事件）：走出它时暂存区清空（3.4 / 058）。
## 只是路过的点、出生点、岔路、撤离点不算。跟着存档走；离开后由 RunState 清回 -1
var last_handled_id: int = -1
var _depths: Dictionary = {}
## 已结束的搜索会话里一共搜了几次（正在搜的那个另算，见 searches_total）。跟着存档走
var searches_closed: int = 0


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


## 踩上一个还没用过的点。配了事件的先停下等玩家选（[method choose]），没配的直接发生
func handle(node: MapNode) -> void:
	if node == null:
		return
	var type := node.type
	if type == &"random":
		type = reveal(node)
	var def := _event_for(node, type)
	if def != null:
		last_handled_id = node.id
		pending = {"node": node.id, "event": String(def.id), "type": String(type)}
		event_pending.emit(node, def)
		return
	_proceed(node, type)


## 事件之后（或者根本没有事件）这个点按类型发生的事
func _proceed(node: MapNode, type: StringName) -> void:
	match type:
		&"battle", &"elite", &"core":
			last_handled_id = node.id
			_battle_at(node, type, node.content, "node")
		&"search":
			last_handled_id = node.id
			_open_search(node)
		&"rest":
			last_handled_id = node.id
			var got := vitality.restore(rules.rest_restore, &"rest") if vitality != null and rules != null else 0
			rested.emit(node, got)
			_visited(node)
		&"shop":
			last_handled_id = node.id
			_open_shop(node)
		&"event":
			last_handled_id = node.id
			_event(node)
			_visited(node)
		&"extract":
			extract_reached.emit(node, PaidExtracts.fee_of(node))
			_visited(node)
		&"safe":
			# 092：没锁的保险箱不算用过 —— 空着走开再回来还能开；关上（里面有东西）就锁了、点灰了
			if not hooks.safe_open():
				_visited(node)
				return
			last_handled_id = node.id
			safe_opened.emit(node)
		_:
			_visited(node)


## 093（大地之神：神坛上改造此点）：这个点从此算 [param type]，当没踩过 —— 清掉旧事件与选择，是战斗 / 精英就现造敌人；
## 站在上面的人关掉神坛就触发它（GameFlow.close_altar）
func retype(node: MapNode, type: StringName) -> void:
	if node == null or not MapNodeTypes.has(type):
		return
	node.content["resolved_type"] = String(type)
	node.content.erase("event")
	node.content.erase("choice")
	node.content.erase("outcome")
	for key in ["enemy", "items", "strength", "bags", "bag", "board"]:
		node.content.erase(key)
	if type in [&"battle", &"elite"]:
		var built := _enemy_for(node, type, _rng_for(node, "retype"))
		for key in built:
			node.content[key] = built[key]
	node.state = MapNode.State.UNVISITED
	if rules != null:
		var def := _event_for(node, type)
		if def != null:
			node.content["event"] = String(def.id)
	type_changed.emit(node, type)


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
	# 揭成什么就按什么类型配事件（生成时随机点没法配）
	if rules != null and String(node.content.get("event", "")) == "":
		var eid := EventPlacer.pick_for(node, type, rules)
		if eid != &"":
			node.content["event"] = String(eid)
	revealed.emit(node, type)
	return type


#region 事件层
## 这个点配了哪个事件：先看内容里的（生成时定的、或被替换过的），没有再按规则表抽；表里没有、定义表里找不到都算没有
func _event_for(node: MapNode, type: StringName) -> EventDef:
	if event_defs.is_empty() or rules == null:
		return null
	var id := String(node.content.get("event", ""))
	if id == "":
		var picked := EventPlacer.pick_for(node, type, rules)
		if picked == &"":
			return null
		id = String(picked)
		node.content["event"] = id
	return event_defs.get(StringName(id), null)


func pending_event() -> EventDef:
	return def_by_id(StringName(String(pending.get("event", "")))) if not pending.is_empty() else null


## 内容里的或运行时合成的
func def_by_id(id: StringName) -> EventDef:
	var def: EventDef = event_defs.get(id, null)
	return def if def != null else extra_defs.get(id, null)


func pending_node() -> MapNode:
	return graph.get_node(int(pending["node"])) if not pending.is_empty() and graph != null and graph.has_node(int(pending["node"])) else null


## 第 i 个选项现在能不能选：{"ok": bool, "why": 不能选的原因}
func option_state(i: int) -> Dictionary:
	var def := pending_event()
	var node := pending_node()
	if def == null or node == null or i < 0 or i >= def.options.size():
		return {"ok": false, "why": "没有这个选项"}
	var why := (def.options[i] as EventOption).locked_reason(_event_ctx(node))
	return {"ok": why == "", "why": why}


## 玩家选了第 i 个选项：条件过了就依次执行后果，然后按旗子往下走（接下一个事件 / 开搜索 / 开店 / 开战 / 点用过）。
## 返回 false = 没有待选的事件、选项不存在、条件没过
func choose(i: int) -> bool:
	var def := pending_event()
	var node := pending_node()
	if def == null or node == null or i < 0 or i >= def.options.size():
		return false
	var option := def.options[i] as EventOption
	var ctx := _event_ctx(node)
	if option.locked_reason(ctx) != "":
		return false
	var type := StringName(String(pending.get("type", String(node.type))))
	var hunter_uid := int(pending.get("hunter", -1))
	var search_stage := bool(pending.get("search_stage", false))
	pending = {}
	for o in option.outcomes:
		if o != null:
			(o as EventOutcome).apply(ctx)
	option_chosen.emit(node, option)
	# 猎手（071）：这不是节点的事，点不标用过；逃跑先掷，没逃掉照打
	if hunter_uid >= 0:
		if ctx.hunter_flee:
			ctx.hunter_fight = not hooks.flee_hunter(node, hunter_uid, ctx)
		event_resolved.emit(node, StringName(option.label), ctx.detail())
		if vitality != null and vitality.is_depleted():
			_defeat(&"vitality_depleted")
			return true
		if ctx.hunter_fight:
			hooks.fight_hunter(node, hunter_uid, ctx)
		return true
	node.content["choice"] = i
	# 8-3：改类型先落账，后面的「照常发生」「开战」都按新类型走（和随机点揭开是同一个记号）
	if ctx.new_type != &"" and ctx.new_type != type:
		node.content["resolved_type"] = String(ctx.new_type)
		type = ctx.new_type
		type_changed.emit(node, type)
	event_resolved.emit(node, StringName(option.label), ctx.detail())
	# 8-3：原地耗时：计数、侵蚀推进、站的这个点照结算 —— 可能把体力耗光，所以在判战败之前
	if ctx.wait_actions > 0 and travel != null:
		travel.wait(ctx.wait_actions, &"event")
		waited.emit(node, ctx.wait_actions)
	if vitality != null and vitality.is_depleted():
		_defeat(&"vitality_depleted")
		_visited(node)
		return true
	# 084：搜索循环里的「离开 / 搜完了」：没选再搜就是走，会话结束、收获交出去（_close_search 标用过）
	if search_stage and not ctx.open_search and current_search != null and current_search.active:
		current_search.leave()
		return true
	# 085：对话里选了「撤离」：交给持有方撤（付费点付不起就说一声、留在原地）
	if ctx.extract:
		_visited(node)
		if hooks.request_extract():
			return true
		event_resolved.emit(node, &"撤离", {"log": ["付不起这个撤离点的费用（%d 币），先去挣点钱，或者找别的出口。" % PaidExtracts.fee_of(node)]})
		return true
	if ctx.next_event != &"":
		var next: EventDef = def_by_id(ctx.next_event)
		if next != null:
			pending = {"node": node.id, "event": String(next.id), "type": String(type)}
			event_pending.emit(node, next)
			return true
	if ctx.open_search:
		_open_search(node, true)
	elif ctx.open_shop:
		_open_shop(node)
	elif ctx.start_battle:
		if current_search != null and not current_search.encounter.is_empty():
			# 084：搜索里遭遇的那一场（「遇敌」事件的「迎战」）：打会话里的遭遇。091：无代价（输了不扣体力），打赢接着搜
			_battle_at(node, &"search", current_search.encounter, "search", 0)
		else:
			var fight_type := type if type in [&"battle", &"elite", &"core"] else &"battle"
			var content := node.content if EnemyKit.has_enemy(node.content) else _enemy_for(node, &"battle", _rng_for(node, "event_enemy"))
			_battle_at(node, fight_type, content, "node")
	elif ctx.proceed:
		_proceed(node, type)
	else:
		_visited(node)
	if ctx.open_altar and not over:
		last_handled_id = node.id
		altar_opened.emit(node)     # 093：休息完开神坛（选项里写 proceed + open_altar）
	# 8-3 传送：这个点的事都完了才挪人（打输了、开着会话就不挪）。造一个 teleport 意图交给持有方 / 旅程，
	# 和走一条传送点边是同一条路：计数、侵蚀、落地那个点头一回踩上就触发它的事
	if ctx.teleport_to >= 0 and not over and travel != null and current_search == null and current_shop == null and pending_battle.is_empty():
		_visited(node)
		var intent := MoveIntent.teleport(node.id, ctx.teleport_to, ctx.teleport_cost)
		if hooks.has(&"relocate"):
			hooks.relocate(intent)
		else:
			travel.apply(intent)     # 没人接就自己走（沙盒 / 测试）
	return true


func _event_ctx(node: MapNode) -> EventContext:
	var ctx := EventContext.new()
	ctx.node = node
	ctx.rng = _rng_for(node, "event")
	ctx.vitality = vitality
	ctx.wallet = wallet
	ctx.items = items
	ctx.rules = rules
	ctx.depth = float(_depths.get(node.id, 0.0))
	ctx.graph = graph
	ctx.steps = travel.clock.total if travel != null and travel.clock != null else 0
	ctx.board = board
	ctx.storage = storage
	ctx.meta = meta
	ctx.hooks = hooks
	if travel != null and travel.erosion != null and travel.erosion.has_method("depth_of"):
		var field: Variant = travel.erosion
		ctx.erosion_depth = func(n: MapNode) -> int: return int(field.depth_of(n))
	return ctx
#endregion


## 本局累计搜索次数（含正在搜的这个点已经搜过的）
func searches_total() -> int:
	return searches_closed + (current_search.searches_done if current_search != null else 0)


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


#region 战前准备（084）
## 节点上的一场：开着 [member pause_before_battle] 就先停下等玩家，否则立刻打。打完（或根本没有敌人）按 [param kind] 收尾
func _battle_at(node: MapNode, type: StringName, content: Dictionary, kind: String, loss_cost: int = LOSS_DEFAULT) -> void:
	if pause_before_battle and _can_fight(content):
		pending_battle = {"node": node.id, "type": String(type), "content": content.duplicate(true), "kind": kind, "loss_cost": loss_cost}
		battle_pending.emit(node, type, content)
		return
	var won := _fight(node, type, content, null, loss_cost)
	_after_battle(node, kind, won)


## 这一场打得起来吗：有敌人、有玩家（没有就当走过，_fight 也是这么判的）
func _can_fight(content: Dictionary) -> bool:
	if content.is_empty() or not hooks.has(&"player_spec"):
		return false
	return EnemyKit.spec_of(content, enemies, pool, items) != null


## 打完这一场接着做的事：节点的战斗把点标用过。搜索遭遇（091，作者定）：**打赢了会话接着开、还能再搜** ——
## 回到「再搜 / 走」那一屏（搜满了是「搜完了」）；**打输了不扣体力**（这一场写了无代价），但会话收掉、收获交出去、
## 这个点用过、「余波」事件说一声不能再搜。整场战斗都包在事件里：遇敌事件 → 迎战 → 回放 → 战利品 → 回到搜索的事件屏
func _after_battle(node: MapNode, kind: String, won: bool = false) -> void:
	if kind == "search" and current_search != null:
		var session := current_search
		if won and not over:
			session.resume()
			var again := _search_event(node, session, "done" if session.is_exhausted() else "again")
			if again != null:
				pending = {"node": node.id, "event": String(again.id), "type": "search", "search_stage": true}
				event_pending.emit(node, again)
			else:
				search_shown.emit(node, session)
			return
		searches_closed += session.searches_done
		current_search = null
		search_closed.emit(node, session.haul(), &"encounter")
	_visited(node)
	if kind == "search" and not over:
		# 084：搜索点被余波摧毁，不能再搜 —— 配了就说一声
		var def := _search_event(node, null, "destroyed")
		if def != null:
			pending = {"node": node.id, "event": String(def.id), "type": "search"}
			event_pending.emit(node, def)


## 等着开打的那个点
func pending_battle_node() -> MapNode:
	return graph.get_node(int(pending_battle["node"])) if not pending_battle.is_empty() and graph != null and graph.has_node(int(pending_battle["node"])) else null


## 等着开打的对手的战斗单位（战前准备屏的读数；和真打出来的是同一份编译）
func pending_battle_spec() -> CombatantSpec:
	return EnemyKit.spec_of(pending_battle.get("content", {}), enemies, pool, items) if not pending_battle.is_empty() else null


## 等着开打的对手的棋盘（战前准备屏画它）
func pending_battle_board() -> GridInventory:
	return EnemyKit.board_of(pending_battle.get("content", {}), items) if not pending_battle.is_empty() and items != null else null


## 玩家在战前准备屏按了「开战」：真打，然后按 kind 收尾。没有等着的一场返回 false
func start_pending_battle() -> bool:
	var node := pending_battle_node()
	if node == null:
		pending_battle = {}
		return false
	var type := StringName(String(pending_battle.get("type", "battle")))
	var content: Dictionary = pending_battle.get("content", {})
	var kind := String(pending_battle.get("kind", "node"))
	var loss_cost := int(pending_battle.get("loss_cost", LOSS_DEFAULT))
	pending_battle = {}
	var won := _fight(node, type, content, null, loss_cost)
	_after_battle(node, kind, won)
	return true
#endregion


## 093（蛮神 3 级）：秒杀等着开打的这一场 —— 不模拟，直接按赢了收尾（掉落、进账、回放屏是一份空回放）。没有等着的返回 false
func smite_pending_battle() -> bool:
	var node := pending_battle_node()
	if node == null:
		return false
	var type := StringName(String(pending_battle.get("type", "battle")))
	var content: Dictionary = pending_battle.get("content", {})
	var kind := String(pending_battle.get("kind", "node"))
	pending_battle = {}
	var enemy := EnemyKit.spec_of(content, enemies, pool, items) if not content.is_empty() else null
	var me: CombatantSpec = hooks.player_spec()
	var result := BattleResult.new()
	result.winner = 0
	last_battle = {"player": me, "enemy": enemy, "node": node.id, "content": content}
	battle_finished.emit(node, result, true)
	var ctx := _loot_ctx()
	var rolled := DropResolver.roll(content, drop_rule, ctx, items, _rng_for(node, "loot"), type == &"core") \
		if drop_rule != null else {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
	_bless_rolled(node, rolled)
	loot_ready.emit(node, DropResolver.corpse_of(content, rolled, items))
	if wallet != null and economy != null:
		var amount := economy.battle_reward(int(content.get("strength", 0)), float(_depths.get(node.id, 0.0)), difficulty)
		wallet.earn(amount, &"battle")
		rewarded.emit(node, amount)
	if type == &"core":
		boss_defeated.emit(node)
	_after_battle(node, kind, true)
	return true


## 095：掉落定了之后按掉落规则的概率把普通道具换成赐福版（激活了信仰只换那位神的）
func _bless_rolled(node: MapNode, rolled: Dictionary) -> void:
	if not hooks.has(&"bless_substitute") or drop_rule == null:
		return
	var dropped: Array[StringName] = rolled.get("dropped", [] as Array[StringName])
	if dropped.is_empty():
		return
	rolled["dropped"] = hooks.bless_substitute(dropped, drop_rule.bless_chance, drop_rule.bless_chance_active, _rng_for(node, "bless"))


## 打一场（猎手系统也走这条路：给它自己的掉落上下文与自己的战败代价）。返回赢没赢
func fight_content(node: MapNode, type: StringName, content: Dictionary, loot_ctx: LootContext = null, loss_cost: int = LOSS_DEFAULT) -> bool:
	return _fight(node, type, content, loot_ctx, loss_cost)


## 这一场输了扣多少：参数写了就用参数；没写看节点内容的 `loss_cost`；再没有：核心点必死，其余按节点规则的表
func loss_cost_for(type: StringName, content: Dictionary, loss_cost: int = LOSS_DEFAULT) -> int:
	if loss_cost != LOSS_DEFAULT:
		return loss_cost
	if content.has("loss_cost"):
		return int(content["loss_cost"])
	if type == &"core":
		return LOSS_DEATH     # 规则不是数值：BOSS 输了直接战败（7.1）
	return rules.loss_cost_of(type) if rules != null else 1


func _fight(node: MapNode, type: StringName, content: Dictionary, loot_ctx: LootContext = null, loss_cost: int = LOSS_DEFAULT) -> bool:
	var enemy := EnemyKit.spec_of(content, enemies, pool, items) if not content.is_empty() else null
	if enemy == null or not hooks.has(&"player_spec"):
		return false     # 没有敌人（这一章没有敌人池）或没有玩家：点空着，当走过
	var me: CombatantSpec = hooks.player_spec()
	hooks.before_battle(me, enemy, type)
	var limit := rules.battle_time_limit if rules != null else 60.0
	var result := BattleSim.run(me, enemy, _rng_for(node, "battle"), limit)
	var won := result.winner == 0
	last_battle = {"player": me, "enemy": enemy, "node": node.id, "content": content}
	battle_finished.emit(node, result, won)
	if won:
		var ctx := loot_ctx if loot_ctx != null else _loot_ctx()
		# 087：核心点的 BOSS 保底一件金色（DropRule.boss_rarity）
		var rolled := DropResolver.roll(content, drop_rule, ctx, items, _rng_for(node, "loot"), type == &"core") \
			if drop_rule != null else {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
		_bless_rolled(node, rolled)
		loot_ready.emit(node, DropResolver.corpse_of(content, rolled, items))
		if wallet != null and economy != null:
			var amount := economy.battle_reward(int(content.get("strength", 0)), float(_depths.get(node.id, 0.0)), difficulty)
			wallet.earn(amount, &"battle")
			rewarded.emit(node, amount)
		if type == &"core":
			boss_defeated.emit(node)
	else:
		var cost := loss_cost_for(type, content, loss_cost)
		if cost == LOSS_DEATH:
			_defeat(&"boss_lost" if type == &"core" else &"fatal_loss")     # 必死：直接战败，连 spend 都不调（7.1）
		elif cost > 0 and vitality != null:
			# 082：角色技能的免罚败仗 —— 只对节点敌人，配额在上下文里、已免几次在这里记。
			# 088（作者定）：输给猎手也扣体力（默认按 loss_cost 里的 hunter，猎手定义可以自己写），猎手定义里的战败后果另算
			if type != HunterSystem.TYPE and losses_forgiven < _run_ctx().free_losses:
				losses_forgiven += 1
			else:
				vitality.spend(cost, &"battle_lost")
			if vitality.is_depleted():
				_defeat(&"vitality_depleted")
		# cost == 0：这一场写了无代价
	return won


## 开搜索。[param auto] = 事件屏上选了「搜索」（084）：第一次开会话，然后**搜一次**；没遭遇就给看搜索屏，遭遇了会话自己结束、走 _close_search。
## 没有事件层的老路（踩上去直接开）不自动搜，只开会话、给看屏
func _open_search(node: MapNode, auto: bool = false) -> void:
	if rules == null or rules.search == null:
		_visited(node)
		return
	var session := current_search
	if session == null or session.node != node:
		session = SearchSession.new(node, rules.search, items, _rng_for(node, "search"), float(_depths.get(node.id, 0.0)))
		session.extra_searches = _run_ctx().extra_searches
		var s := session
		var sr := rules.search
		var bless_rng := _rng_for(node, "bless_search")
		session.substitute = func(ids: Array[StringName]) -> Array[StringName]:
			return hooks.bless_substitute(ids, sr.bless_chance, sr.bless_chance_active, bless_rng)     # 095
		session.encounter_builder = func() -> Dictionary:
			# 083：节点内容里写死的遭遇（教程点）优先；没有才按池现造
			var fixed = node.content.get("encounter", null)
			if fixed is Dictionary and EnemyKit.has_enemy(fixed):
				return (fixed as Dictionary).duplicate(true)
			return _enemy_for(node, &"search", _rng_for(node, "ambush:%d" % s.searches_done))
		session.ended.connect(func(reason: StringName): _close_search(node, s, reason))
		current_search = session
		search_opened.emit(node, session)
	if not auto:
		search_shown.emit(node, session)
		return
	if not session.can_search():
		return
	session.search()
	if session.active:
		search_shown.emit(node, session)


## 玩家关闭了搜索屏（084）：回到事件屏 —— 搜满了是 done 事件，没搜满是 again 事件（再搜 / 走）。
## 没配事件就直接离开（收获交出去）。没有开着的会话返回 false
func pause_search() -> bool:
	var session := current_search
	if session == null or not session.active:
		return false
	var def := _search_event(session.node, session, "done" if session.is_exhausted() else "again")
	if def == null:
		session.leave()
		return true
	pending = {"node": session.node.id, "event": String(def.id), "type": "search", "search_stage": true}
	event_pending.emit(session.node, def)
	return true


## 搜索循环里的某一屏配的是哪个事件：节点内容覆盖（`search_again_events[k]` / `search_done_event` / `search_encounter_event` /
## `search_destroyed_event`），没有按 [SearchRules]；都没有 = null
func _search_event(node: MapNode, session: SearchSession, which: String) -> EventDef:
	var id := ""
	var sr: SearchRules = rules.search if rules != null else null
	match which:
		"again":
			var list: Array = node.content.get("search_again_events", [])
			var k := (session.searches_done - 1) if session != null else -1
			if k >= 0 and k < list.size():
				id = String(list[k])
			elif not list.is_empty() and k >= list.size():
				id = String(list[-1])
			if id == "" and sr != null:
				id = String(sr.again_event)
		"done":
			id = String(node.content.get("search_done_event", ""))
			if id == "" and sr != null:
				id = String(sr.done_event)
		"encounter":
			id = String(node.content.get("search_encounter_event", ""))
			if id == "" and sr != null:
				id = String(sr.encounter_event)
		"destroyed":
			id = String(node.content.get("search_destroyed_event", ""))
			if id == "" and sr != null:
				id = String(sr.destroyed_event)
	return def_by_id(StringName(id)) if id != "" else null


## 商店：开一个会话，玩家买、刷新、走；走了才算用过
func _open_shop(node: MapNode) -> void:
	if economy == null or wallet == null or items == null:
		shop_opened.emit(node, null)
		_visited(node)
		return
	var session := ShopSession.new(node, economy, items, wallet, float(_depths.get(node.id, 0.0)), _run_ctx().shop_price_mult)
	session.closed.connect(func():
		current_shop = null
		shop_closed.emit(node)
		_visited(node))
	current_shop = session
	shop_opened.emit(node, session)


## 091（作者定）：回到走过的商店点，店再开起来（[ShopSession] 从节点内容里接着上次的刷新次数与卖掉的记录）
func reopen_shop(node: MapNode) -> void:
	if node == null or current_shop != null or over:
		return
	last_handled_id = node.id
	_open_shop(node)


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
		var notice := _search_event(node, session, "encounter")
		if notice != null:
			# 084：先过「遇敌」事件，选「迎战」（start_battle）才打；会话留在 current_search，遭遇与收获都在里面
			pending = {"node": node.id, "event": String(notice.id), "type": "search", "search_encounter": true}
			event_pending.emit(node, notice)
			return
		if pause_before_battle and _can_fight(session.encounter):
			# 先停在战前准备屏；打完由 _after_battle("search") 决定：赢了接着搜、输了收会话（091：无代价）
			pending_battle = {"node": node.id, "type": "search", "content": session.encounter.duplicate(true), "kind": "search", "loss_cost": 0}
			battle_pending.emit(node, &"search", session.encounter)
			return
		var won := _fight(node, &"search", session.encounter, null, 0)
		_after_battle(node, "search", won)
		return
	searches_closed += session.searches_done
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


func _run_ctx() -> RunContext:
	var from_hook := hooks.run_context()
	if from_hook != null:
		return from_hook
	return RunContext.new()


func _loot_ctx() -> LootContext:
	var from_hook := hooks.loot_context()
	if from_hook != null:
		return from_hook
	var ctx := LootContext.new()
	ctx.difficulty = difficulty
	return ctx


func _defeat(reason: StringName) -> void:
	over = true
	defeated.emit(reason)


func _visited(node: MapNode) -> void:
	if travel != null:
		travel.mark_visited(node.id)
	else:
		node.state = MapNode.State.VISITED


func _rng_for(node: MapNode, tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [node.content_seed, tag])
	return rng
