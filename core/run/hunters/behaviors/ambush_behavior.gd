## 埋伏：不动，等玩家走进开打距离
class_name AmbushBehavior
extends HunterBehavior


func next_node(h: Hunter, _sys: HunterSystem, _options: Array[int]) -> int:
	return h.node_id


func describe() -> String:
	return "埋伏"
