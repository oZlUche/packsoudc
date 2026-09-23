## 靠近：玩家在感知范围内就朝玩家走（挑离玩家最近的相邻点），不在就游荡
class_name ApproachBehavior
extends HunterBehavior

## 没感知到玩家时游荡的概率（0 = 站着不动）
@export var wander_chance: float = 0.5


func next_node(h: Hunter, sys: HunterSystem, options: Array[int]) -> int:
	if options.is_empty():
		return h.node_id
	if sys.senses_player(h):
		return sys.closest_to_player(options, h.node_id)
	return sys.random_of(options) if sys.rng().randf() < wander_chance else h.node_id


func describe() -> String:
	return "靠近"
