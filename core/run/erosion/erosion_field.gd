## 侵蚀场（5.7，第 7 阶段本体，报告 075）：地图从最外一档侵蚀带开始逐层向内被侵蚀；被侵蚀的点仍可通行，走进去有代价。
##
## **只认 `MapNode.erosion_band`，不知道「环」**。时间表（第几个行动点开始、每隔几个推进一层、提前几步预警）与效果清单在 [ErosionMechanic] 里，
## 本类是一局里的状态 + 结算：[method on_action] 由 [MapTravel] 每次移动先调（顺序定死：花行动点 → 侵蚀推进 → 目的地惩罚 → 节点事件），
## [method settle] 在目的地结算：这个点被侵蚀了就把清单里的效果构件挨个过一遍门（开关 / 起始层 / 仅终局 / 概率）。
## 三条硬约束：必须预警（[signal warned]）、绝不封路（这里没有任何「不能走」）、惩罚随深度递增（效果的 `per_depth`）。
## 终局：最内一档也被侵蚀（[method is_total]），`only_total` 的效果从此生效。跟着存档；随机数走 `RunRNG` 的 `erosion` 流。
class_name ErosionField
extends RefCounted

const STREAM := &"erosion"

## 快推进到下一层了（提前 warn_lead_actions 步，每层一次）
signal warned(next_band: int, actions_left: int)
## 又侵蚀了一层：现在最外 eroded_bands + 1 档都被侵蚀了
signal advanced(eroded_bands: int)
## 在被侵蚀的点结算了、有东西发生
signal applied(node: MapNode, detail: Dictionary)
## 全图都被侵蚀了
signal total_reached()

var run: RunState = null
var mechanic: ErosionMechanic = null
## -1 = 还没开始；0 = 最外一档已被侵蚀
var eroded_bands: int = -1
## 下一次推进在第几个行动点
var next_at_action: int = 0
## 图上最内一档是几
var max_band: int = 0
var _warned_for: int = -1


func setup(p_run: RunState, p_mechanic: ErosionMechanic) -> void:
	run = p_run
	mechanic = p_mechanic
	next_at_action = mechanic.first_at_action
	max_band = 0
	if run.map != null:
		for id in run.map.node_ids():
			max_band = maxi(max_band, run.map.get_node(id).erosion_band)


#region 状态
func started() -> bool:
	return eroded_bands >= 0


func is_total() -> bool:
	return eroded_bands >= max_band


func is_eroded(node: MapNode) -> bool:
	return node != null and started() and node.erosion_band <= eroded_bands


## 这个点被侵蚀了几层（没被侵蚀 = -1）
func depth_of(node: MapNode) -> int:
	return eroded_bands - node.erosion_band if is_eroded(node) else -1


## 距下一次推进还有几个行动点；终局了返回 -1
func actions_left() -> int:
	if is_total() or run == null or run.travel == null or run.travel.clock == null:
		return -1
	return maxi(0, next_at_action - run.travel.clock.total)


## 下一档要被侵蚀的带（终局了 -1）
func next_band() -> int:
	return eroded_bands + 1 if not is_total() else -1
#endregion


#region 钩子（MapTravel）
## 每次移动、花完行动点之后：该推进就推进（一次可能推进好几层，比如一步花了很多行动点），然后预警
func on_action(clock: ActionClock, _graph: MapGraph) -> void:
	if mechanic == null:
		return
	var total := clock.total
	while not is_total() and total >= next_at_action:
		eroded_bands += 1
		next_at_action += maxi(1, mechanic.interval_actions)
		advanced.emit(eroded_bands)
		if is_total():
			total_reached.emit()
	if not is_total():
		var left := next_at_action - total
		var coming := eroded_bands + 1
		if left <= mechanic.warn_lead_actions and _warned_for != coming:
			_warned_for = coming
			warned.emit(coming, left)


## 目的地结算：被侵蚀的点才有事；效果构件挨个过门
func settle(node: MapNode) -> void:
	if mechanic == null or run == null or not is_eroded(node):
		return
	var ctx := ErosionContext.new()
	ctx.run = run
	ctx.node = node
	ctx.depth = depth_of(node)
	ctx.total = is_total()
	ctx.rng = run.rng.next(STREAM) if run.rng != null else RandomNumberGenerator.new()
	for e in mechanic.effects:
		var effect := e as ErosionEffect
		if effect != null and effect.applies(ctx):
			effect.apply(ctx)
	if ctx.happened():
		applied.emit(node, ctx.detail())
	if run.vitality != null and run.vitality.is_depleted() and run.events != null:
		run.events.defeated.emit(&"erosion")
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {"eroded_bands": eroded_bands, "next_at_action": next_at_action, "warned_for": _warned_for}


func restore(d: Dictionary) -> void:
	eroded_bands = int(d.get("eroded_bands", -1))
	next_at_action = int(d.get("next_at_action", next_at_action))
	_warned_for = int(d.get("warned_for", -1))
#endregion
