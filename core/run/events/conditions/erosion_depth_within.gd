## 条件：这个点被侵蚀了几层（075：没被侵蚀 -1、刚被侵蚀 0、越往里越深）在某个区间里（8-3）。
## min 为 0 = 只要被侵蚀就行；这一局没有侵蚀 = 永远 -1
class_name ErosionDepthWithin
extends EventCondition

@export var min_depth: int = 0
@export var max_depth: int = -1


func check(ctx: EventContext) -> bool:
	var d := ctx.depth_at(ctx.node)
	return d >= min_depth and (max_depth < 0 or d <= max_depth)


func describe() -> String:
	if min_depth <= 0 and max_depth < 0:
		return "需要这里已被侵蚀"
	if max_depth < 0:
		return "需要侵蚀深度 ≥ %d" % min_depth
	return "需要侵蚀深度 %d～%d" % [min_depth, max_depth]
