## 一次侵蚀结算的上下文（5.7，报告 075）：玩家走进（或待在）被侵蚀的点时，各个侵蚀效果构件对着它做事、往账上记。
class_name ErosionContext
extends RefCounted

var run: RunState = null
var node: MapNode = null
## 这个点的侵蚀带（0 = 最外，最先被侵蚀）
var band: int = 0
## 侵蚀深度：这个点被侵蚀了几层（0 = 刚被侵蚀；越大越久）
var depth: int = 0
## 全图都被侵蚀了（终局）
var total: bool = false
var rng: RandomNumberGenerator = null

## 账
var vitality_spent: int = 0
var money_lost: int = 0
var items_lost: Array[String] = []
var log: Array[String] = []


func happened() -> bool:
	return vitality_spent > 0 or money_lost > 0 or not items_lost.is_empty() or not log.is_empty()


func detail() -> Dictionary:
	return {"vitality": vitality_spent, "money": money_lost, "items": items_lost.duplicate(), "log": log.duplicate(), "depth": depth, "total": total}
