## 巡逻：每隔几步换一个相邻点，感知到玩家就靠近
class_name PatrolBehavior
extends HunterBehavior

## 每隔几个玩家步挪一次
@export var every_steps: int = 2


func next_node(h: Hunter, sys: HunterSystem, options: Array[int]) -> int:
	if options.is_empty():
		return h.node_id
	if sys.senses_player(h):
		return sys.closest_to_player(options, h.node_id)
	if every_steps > 0 and sys.step_count() % every_steps == 0:
		return sys.random_of(options)
	return h.node_id


func describe() -> String:
	return "巡逻（每 %d 步）" % every_steps
