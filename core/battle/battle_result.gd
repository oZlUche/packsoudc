## 一场战斗的完整结果。整场战斗在开战瞬间一次算完，这是它的全部产出。
class_name BattleResult
extends RefCounted

## 0 / 1 为获胜方，-1 为平局
var winner: int = -1
## 战斗时长，定点秒
var duration: int = 0
## 回放日志。[BattleView] 照它重演，「跳过」就是把游标推到末尾。
var log: Array[BattleEvent] = []

## 开战瞬间的状态快照。**回放的起点** ——
## 没有它，表现层就得自己去编译棋盘才知道血条从哪儿开始，
## 那等于让表现层认识战斗逻辑，1.1 的分离就破了。
var initial: Dictionary = {}

var final: Dictionary = {}


func duration_sec() -> float:
	return StatMath.to_float(duration)


func is_draw() -> bool:
	return winner < 0


func _to_string() -> String:
	var who := "平局" if is_draw() else "side %d 获胜" % winner
	return "BattleResult(%s, %.2f 秒, %d 条事件)" % [who, duration_sec(), log.size()]
