## 游荡：随机走一个能走的相邻点，不管玩家在哪
class_name WanderBehavior
extends HunterBehavior


func next_node(h: Hunter, sys: HunterSystem, options: Array[int]) -> int:
	return sys.random_of(options) if not options.is_empty() else h.node_id


func describe() -> String:
	return "游荡"
