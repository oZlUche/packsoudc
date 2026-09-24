## 在地图上走：一次移动 = 一次原子结算，[b]顺序不可调换[/b]（架构文档 5.6）。
##
## [codeblock]
## 校验合法 → ActionClock.spend → 侵蚀推进 → 结算目的地惩罚 → 触发节点事件
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

var graph: MapGraph = null
var clock: ActionClock = null
## 侵蚀的浅层惩罚扣它；null = 不扣（比如还没接上体力的沙盒）
var vitality: Vitality = null
var erosion = null
var on_node_event: Callable = Callable()

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

	# 2. 行动点
	clock.spend(intent.action_cost, intent.kind)

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

	# 5. 节点事件：只在头一回踩上时
	if first_visit:
		if on_node_event.is_valid():
			on_node_event.call(dest)
		else:
			dest.state = MapNode.State.VISITED     # 占位：没人接事件，就当到了即用过
	moved.emit(intent, first_visit)
	return true


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
	if MapNavigator.edge_for_step(graph, intent.from_id, intent.to_id) == null:
		return "从 %d 走不到 %d" % [intent.from_id, intent.to_id]
	if intent.action_cost < 0:
		return "行动点不能是负的"
	return ""


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
	return {"current": current_id, "history": history.duplicate(), "clock": clock.to_dict()}


## 图另存（它自己有 to_dict），这里只还原「人在哪、走过哪、花了多少」。
static func from_dict(d: Dictionary, p_graph: MapGraph) -> MapTravel:
	var t := MapTravel.new(p_graph, ActionClock.from_dict(d.get("clock", {})), int(d.get("current", -1)))
	for v in d.get("history", []):
		t.history.append(int(v))
	return t
#endregion
