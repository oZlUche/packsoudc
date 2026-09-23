## 远离：玩家在感知范围内就往离玩家最远的相邻点走，不在就不动
class_name FleeBehavior
extends HunterBehavior


func next_node(h: Hunter, sys: HunterSystem, options: Array[int]) -> int:
	if options.is_empty() or not sys.senses_player(h):
		return h.node_id
	return sys.farthest_from_player(options, h.node_id)


func describe() -> String:
	return "远离"
