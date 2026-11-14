## 一次侵蚀结算的上下文（5.7，报告 075）：玩家走进（或待在）被侵蚀的点时，各个侵蚀效果构件对着它做事、往账上记。
class_name ErosionContext
extends RefCounted

var run: RunState = null
var node: MapNode = null
## 侵蚀深度：这个点被侵蚀了几层（0 = 刚被侵蚀；越大越久）
var depth: int = 0
## 全图都被侵蚀了（终局）
var total: bool = false
var rng: RandomNumberGenerator = null
## 320 A9：真正走进来的（[method MapTravel.apply]，途经点也算）；原地耗时结算脚下的点是 false
var entered: bool = true

## 账
var vitality_spent: int = 0
var money_lost: int = 0
var items_lost: Array[String] = []
## 320 A9：这次侵蚀了哪件 —— `{name, count, limit, destroyed}`
var items_eroded: Array[Dictionary] = []
@warning_ignore("shadowed_global_identifier")
var log: Array[String] = []


func happened() -> bool:
	return vitality_spent > 0 or money_lost > 0 or not items_lost.is_empty() or not log.is_empty() or not items_eroded.is_empty()


func detail() -> Dictionary:
	return {"vitality": vitality_spent, "money": money_lost, "items": items_lost.duplicate(), "log": log.duplicate(), "eroded": items_eroded.duplicate(true), "depth": depth, "total": total}
