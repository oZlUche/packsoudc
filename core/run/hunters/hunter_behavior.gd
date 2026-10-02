## 猎手的行动逻辑（构件，登记在 [RunRegistry.HUNTER_BEHAVIORS]）：每一小步回答「往哪个相邻点走」。
##
## 只看得见 [HunterSystem] 给的信息（玩家在哪、距离、能走的相邻点 —— 已经排除了别人的领地）；不动状态。
## 加一种 = 一个子类、登记一行；作者在猎手文件里写 behavior 的 type 与参数。
@abstract
class_name HunterBehavior
extends Resource

## 这一小步走到哪：返回相邻点 id，或 [param h].node_id 表示不动。[param options] 是能走的相邻点
@abstract func next_node(h: Hunter, sys: HunterSystem, options: Array[int]) -> int

func describe() -> String:
	return ""
