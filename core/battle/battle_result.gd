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

## 103 第 6 条：这场上过身的所有 buff（id → [BuffDef]）。回放的 buff 栏直接拿它画图标、写悬浮窗
var buffs: Dictionary = {}

## 103 第 6 条：双方的常驻加成（[[PassiveNote…], [PassiveNote…]]），编译期并进属性、不是 buff，但影响战斗，所以进栏
var passives: Array = [[], []]


## 117：回放存档。buff 只存 id（定义按 id 回查，[method from_dict] 的 [param buff_defs]），
## 常驻加成（[member passives]）不存 —— 回放的 buff 栏少那几格，不影响重演
func to_dict() -> Dictionary:
	var events: Array = []
	for e in log:
		events.append(e.to_dict())
	var buff_ids: Array = []
	for id in buffs:
		buff_ids.append(String(id))
	buff_ids.sort()
	return {"winner": winner, "duration": duration, "initial": initial, "final": final, "buffs": buff_ids, "log": events}


## [param buff_defs]：buff id → [BuffDef]；查不到的 id 跳过
static func from_dict(d: Dictionary, buff_defs: Dictionary = {}) -> BattleResult:
	var r := BattleResult.new()
	r.winner = int(d.get("winner", -1))
	r.duration = int(d.get("duration", 0))
	r.initial = d.get("initial", {})
	r.final = d.get("final", {})
	for e in d.get("log", []):
		if e is Dictionary:
			r.log.append(BattleEvent.from_dict(e))
	for id in d.get("buffs", []):
		var key := StringName(String(id))
		if buff_defs.has(key):
			r.buffs[key] = buff_defs[key]
	return r


func duration_sec() -> float:
	return StatMath.to_float(duration)


func is_draw() -> bool:
	return winner < 0


func _to_string() -> String:
	var who := "平局" if is_draw() else "side %d 获胜" % winner
	return "BattleResult(%s, %.2f 秒, %d 条事件)" % [who, duration_sec(), log.size()]
