## 在地图上走：一次移动 = 一次原子结算，[b]顺序不可调换[/b]（架构文档 5.6）。
##
## [codeblock]
## 校验合法 → ActionClock.spend → 侵蚀推进 → 结算目的地惩罚 →（134：进点闸门，可挂起）→ 触发节点事件
## [/codeblock]
##
## 侵蚀推进必须早于目的地惩罚：顺序反了，玩家走进一个刚好在这一步被侵蚀的点却毫发无伤，
## 预警倒计时的最后一步就没有意义。侵蚀现在还没有（第 7 阶段），但**钩子与顺序现在就定死**，
## 测试用一个假钩子记调用次序守着它。
##
## 侵蚀与节点事件都是鸭子类型的钩子，本类不认识它们的具体类：
## - [member erosion]：有 `on_action(clock, graph)` 与 `move_penalty(node) -> Dictionary`
##   （`{"hp_damage": int, "item_risk": float}`）就行。null = 没有侵蚀
## - [member on_node_event]：`Callable(node: MapNode)`。设了它，节点什么时候算「用过」由它说
##   （战斗打完才算）；没设，本类到点就标 VISITED —— M4 之前的占位
class_name MapTravel
extends RefCounted

## 一次移动结算完毕。[param first_visit] = 目的地这一次是不是头一回踩上
signal moved(intent: MoveIntent, first_visit: bool)
## 想走但走不了：不相邻、那条路不能从这头走、意图过期……
signal refused(intent: MoveIntent, why: String)
## 原地耗了几个行动点（8-3）
signal waited(actions: int)
## 134：挂起的进点取消了（输给驱逐档的猎手，退回上一步）：这个点视为没进
signal arrival_cancelled(intent: MoveIntent, first_visit: bool)

var graph: MapGraph = null
var clock: ActionClock = null
## 侵蚀的浅层惩罚扣它；null = 不扣（比如还没接上体力的沙盒）
var vitality: Vitality = null
var erosion = null
var on_node_event: Callable = Callable()
## 134：进点前的闸门 `Callable(intent: MoveIntent, first_visit: bool) -> bool`。人挪到点上、惩罚结算完、点的事发生**之前**问一声，
## 返回 true = 先挂起这次进点（[member held]），由持有方之后 [method finish_arrival] 接着进、或 [method cancel_arrival] 取消。没设 = 不挂
var arrival_gate: Callable = Callable()
## 134：挂起的进点 `{"intent": MoveIntent, "first": bool}`；空 = 没有。跟着存档
var held: Dictionary = {}

## 129：走一步（含传送）花的行动点乘几 —— 负重第三级是 2。原地等待不乘。[RunState] 按负重级数写
var action_cost_mult: int = 1
## 136（熟门熟路）：每走几步下一步不花行动点（0 = 没有）。[RunState] 按 RunContext.free_step_every 写
var free_step_every: int = 0
## 136：上一次免费之后付过行动点的步数（走一步 / 传送都算；原地等待不算）。跟着存档
var paid_steps: int = 0
## 136：最近一次移动真正花了几点（日志读；不存档）
var last_cost: int = 0

var current_id: int = -1
## 走过的路：每次移动的目的地，按顺序。存档与回放用
var history: Array[int] = []


func _init(p_graph: MapGraph, p_clock: ActionClock = null, p_start: int = -1) -> void:
	graph = p_graph
	clock = p_clock if p_clock != null else ActionClock.new()
	if p_start >= 0:
		current_id = p_start


## 从某个出生点开始。出生点本身算踩过了：开局就站在上面，它不该再触发一次事件。
func start_at(id: int) -> bool:
	if graph == null or not graph.has_node(id):
		return false
	current_id = id
	history = [id] as Array[int]
	var n := graph.get_node(id)
	if n.state == MapNode.State.UNVISITED:
		n.state = MapNode.State.VISITED
	return true


## 现在能走到哪儿。
func available_moves() -> Array[int]:
	return MapNavigator.available_moves(graph, current_id)


## 走到相邻的 [param to_id]。这是玩家点一下地图对应的那一个动作。
func step_to(to_id: int) -> bool:
	var intent := MapNavigator.resolve_step(graph, current_id, to_id)
	if intent == null:
		var stale := MoveIntent.step(current_id, to_id, 0)
		refused.emit(stale, "从 %d 走不到 %d：不相邻，或那条路不能从这头走" % [current_id, to_id])
		return false
	return apply(intent)


## 结算一个意图。[b]唯一会改地图状态的入口[/b]；step_to 只是造了个意图交给它。
## 将来的传送、定点移动造好自己的意图之后也走这里 —— 顺序、计数、惩罚、事件一处都不用改。
func apply(intent: MoveIntent) -> bool:
	# 1. 校验合法
	var why := _check(intent)
	if why != "":
		refused.emit(intent, why)
		return false
	var dest := graph.get_node(intent.to_id)
	var first_visit := dest.state == MapNode.State.UNVISITED

	# 2. 行动点（129：负重的倍数乘在这里，预览读同一个 cost_of；136：熟门熟路的免费步也在 cost_of 里）
	var free := next_step_free()
	last_cost = cost_of(intent)
	clock.spend(last_cost, intent.kind)
	paid_steps = 0 if free else paid_steps + 1

	# 3. 侵蚀推进 —— 必须在惩罚结算之前
	if erosion != null and erosion.has_method("on_action"):
		erosion.on_action(clock, graph)

	# 4. 目的地（与途经点）的惩罚
	current_id = intent.to_id
	history.append(intent.to_id)
	if erosion != null and erosion.has_method("move_penalty"):
		for id in intent.passes_through:
			_settle_penalty(graph.get_node(id))
		_settle_penalty(dest)

	# 134：进点之前的闸门（猎手战插在这个点的事前面）。挂起了就停在这儿：点不标走过、事不发生、moved 不发
	if arrival_gate.is_valid() and bool(arrival_gate.call(intent, first_visit)):
		held = {"intent": intent, "first": first_visit}
		return true

	_arrive(intent, dest, first_visit)
	return true


## 5. 节点事件：只在头一回踩上时；然后发 moved
func _arrive(intent: MoveIntent, dest: MapNode, first_visit: bool) -> void:
	if first_visit:
		if on_node_event.is_valid():
			on_node_event.call(dest)
		else:
			dest.state = MapNode.State.VISITED     # 占位：没人接事件，就当到了即用过
	moved.emit(intent, first_visit)


## 134：有没有挂起的进点
func is_holding() -> bool:
	return not held.is_empty()


## 134：接着进挂起的那个点（点的事发生、发 moved）。没有挂起的返回 false
func finish_arrival() -> bool:
	if held.is_empty():
		return false
	var intent: MoveIntent = held["intent"]
	var first := bool(held["first"])
	held = {}
	var dest := graph.get_node(intent.to_id) if graph != null and graph.has_node(intent.to_id) else null
	if dest == null:
		return false
	_arrive(intent, dest, first and dest.state == MapNode.State.UNVISITED)
	return true


## 134：取消挂起的进点（这个点视为没进：不标走过、事不发生）。人挪不挪由调用方定。没有挂起的返回 false
func cancel_arrival() -> bool:
	if held.is_empty():
		return false
	var intent: MoveIntent = held["intent"]
	var first := bool(held["first"])
	held = {}
	arrival_cancelled.emit(intent, first)
	return true


## 129：这一步真正花几点（边上写的 × 负重倍数）。地图屏的预览与日志读它
func cost_of(intent: MoveIntent) -> int:
	if next_step_free():
		return 0
	return (intent.action_cost if intent != null else 0) * maxi(1, action_cost_mult)


## 136：下一步是不是免费的（熟门熟路：付过 free_step_every 步之后的那一步）
func next_step_free() -> bool:
	return free_step_every > 0 and paid_steps >= free_step_every


## 节点事件结束后由事件系统调：这个点用过了，以后只能穿行。
func mark_visited(id: int) -> void:
	var n := graph.get_node(id) if graph != null else null
	if n != null:
		n.state = MapNode.State.VISITED


func _check(intent: MoveIntent) -> String:
	if graph == null or intent == null:
		return "没有地图"
	if intent.kind != MoveIntent.STEP and intent.kind != MoveIntent.TELEPORT:
		return "还不认识 %s 这种移动方式 —— 底层现在实现 step 与 teleport（8-1）" % intent.kind
	if intent.from_id != current_id:
		return "意图过期：它以为在 %d，人在 %d" % [intent.from_id, current_id]
	if not graph.has_node(intent.to_id) or intent.to_id == intent.from_id:
		return "没有点 %d 可去" % intent.to_id
	# 走一步得有那条路；传送信任解析方（传送点边、事件的后果）—— 它不需要边（8-3）
	if intent.kind == MoveIntent.STEP and MapNavigator.edge_for_step(graph, intent.from_id, intent.to_id) == null:
		return "从 %d 走不到 %d" % [intent.from_id, intent.to_id]
	if intent.action_cost < 0:
		return "行动点不能是负的"
	return ""


## 原地耗掉几个行动点（8-3：事件里扎营、等人）。不挪人，但时间照走：计数 → 侵蚀推进 → 站的这个点照结算。
## 顺序和 apply 一样，出于同一个理由：等到侵蚀推进的那一步，脚下的点得立刻结算
func wait(actions: int, reason: StringName = &"wait") -> void:
	if actions <= 0 or graph == null:
		return
	clock.spend(actions, reason)
	if erosion != null and erosion.has_method("on_action"):
		erosion.on_action(clock, graph)
	if erosion != null and erosion.has_method("move_penalty") and graph.has_node(current_id):
		_settle_penalty(graph.get_node(current_id))
	waited.emit(actions)


func _settle_penalty(node: MapNode) -> void:
	if node == null:
		return
	# 本体（075）：有 settle 的自己结算（效果构件过门）；老的鸭子接口只报浅层扣体力
	if erosion.has_method("settle"):
		erosion.settle(node)
		return
	var penalty: Dictionary = erosion.move_penalty(node)
	var hp := int(penalty.get("hp_damage", 0))
	if hp > 0 and vitality != null:
		vitality.spend(hp, &"erosion")
	# item_risk 是第 7 阶段的事：损坏背包里的物品要先有背包在 run 里


#region 存档
func to_dict() -> Dictionary:
	var out := {"current": current_id, "history": history.duplicate(), "clock": clock.to_dict()}
	if paid_steps > 0:
		out["paid_steps"] = paid_steps     # 136
	if not held.is_empty():
		out["held"] = {"intent": (held["intent"] as MoveIntent).to_dict(), "first": bool(held["first"])}     # 134
	return out


## 图另存（它自己有 to_dict），这里只还原「人在哪、走过哪、花了多少」。
static func from_dict(d: Dictionary, p_graph: MapGraph) -> MapTravel:
	var t := MapTravel.new(p_graph, ActionClock.from_dict(d.get("clock", {})), int(d.get("current", -1)))
	for v in d.get("history", []):
		t.history.append(int(v))
	t.paid_steps = int(d.get("paid_steps", 0))
	var h = d.get("held", {})
	if h is Dictionary and not (h as Dictionary).is_empty():
		t.held = {"intent": MoveIntent.from_dict(h.get("intent", {})), "first": bool(h.get("first", false))}
	return t
#endregion
