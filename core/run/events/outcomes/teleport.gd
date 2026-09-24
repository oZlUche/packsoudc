## 后果：把玩家传送到另一个点（8-3）。只挑目的地、立旗；真正挪人是 [NodeEvents] 造一个 teleport 意图交给旅程结算，
## 和走一条传送点边（8-1）是同一条路：花这里说的行动点、侵蚀推进、落地那个点头一回踩上就触发它的事。
##
## 目的地怎么挑（都从当前点按步数量）：
## - NEAREST / FARTHEST：最近 / 最远的候选点（并列的按种子随机）
## - RANDOM：候选里随机一个
## - FIXED：节点内容里 `teleport_target` 写的 id（编辑器 / 生成器定进去），没有就不传
## 候选 = 步数在 [min_steps, max_steps] 里（max -1 不封顶）、类型在 [member node_types] 里（空 = 任何类型）、
## [member unvisited_only] 时还得是没用过的点。挑不出来就不传，什么也不发生
class_name Teleport
extends EventOutcome

enum Target { NEAREST, FARTHEST, RANDOM, FIXED }

@export var target: Target = Target.RANDOM
@export var node_types: Array[StringName] = []
@export var min_steps: int = 1
@export var max_steps: int = -1
@export var unvisited_only: bool = true
## 花几个行动点（0 = 白送）
@export var action_cost: int = 1
## 生成器 / 编辑器往节点内容里写目的地用的键（FIXED）
const CONTENT_KEY := "teleport_target"


func apply(ctx: EventContext) -> void:
	if ctx.graph == null or ctx.node == null:
		return
	var to := pick(ctx)
	if to < 0:
		return
	ctx.teleport_to = to
	ctx.teleport_cost = maxi(0, action_cost)


func pick(ctx: EventContext) -> int:
	if target == Target.FIXED:
		var id := int(ctx.node.content.get(CONTENT_KEY, -1))
		return id if id != ctx.node.id and ctx.graph.has_node(id) else -1
	var dist := MapNavigator.distance_map(ctx.graph, ctx.node.id)
	var cands: Array[int] = []
	for id in ctx.graph.node_ids():
		if id == ctx.node.id or not dist.has(id):
			continue
		var d := int(dist[id])
		if d < min_steps or (max_steps >= 0 and d > max_steps):
			continue
		var n := ctx.graph.get_node(id)
		if unvisited_only and n.state != MapNode.State.UNVISITED:
			continue
		if not node_types.is_empty() and not node_types.has(NodeEvents.effective_type(n)):
			continue
		cands.append(id)
	if cands.is_empty():
		return -1
	cands.sort()
	match target:
		Target.NEAREST, Target.FARTHEST:
			var best: Array[int] = []
			var best_d := -1
			for id in cands:
				var d := int(dist[id])
				var better := d < best_d if target == Target.NEAREST else d > best_d
				if best_d < 0 or better:
					best_d = d
					best = [id]
				elif d == best_d:
					best.append(id)
			return best[ctx.rng.randi_range(0, best.size() - 1)] if ctx.rng != null else best[0]
		_:
			return cands[ctx.rng.randi_range(0, cands.size() - 1)] if ctx.rng != null else cands[0]


func describe() -> String:
	var where: String = ["最近的", "最远的", "随机一个", "指定的"][target]
	var types := ""
	if not node_types.is_empty():
		var names: Array[String] = []
		for t in node_types:
			names.append(String(t))
		types = " / ".join(names)
	var range_text := ""
	if target != Target.FIXED:
		range_text = "（%d～%s 步）" % [min_steps, str(max_steps) if max_steps >= 0 else "∞"]
	return "传送到%s%s点%s，花 %d 点" % [where, types, range_text, maxi(0, action_cost)]
