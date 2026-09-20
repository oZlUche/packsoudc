## 战斗中广播的一条事件。
##
## 战斗中每一个可观测的步骤都是事件（架构文档 4.4），监听者靠订阅事件名来接收。
## 事件同时也是回放日志的条目 —— [BattleView] 按它重演整场战斗。
class_name BattleEvent
extends RefCounted

#region 事件名
const BATTLE_START := &"battle_start"
const BATTLE_END := &"battle_end"
const TICK := &"tick"
const ITEM_FIRED := &"item_fired"
const EFFECT_RESOLVED := &"effect_resolved"
const STATUS_STACKED := &"status_stacked"
const STATUS_UNSTACKED := &"status_unstacked"
## 生命、耐力、法力全部走这一条，靠 payload 里的 key 区分。
## 新增一种资源不新增事件类型。
const RESOURCE_CHANGED := &"resource_changed"
## 伤害。携带类型与原始／实际两个数值 —— resource_changed 只记「实际掉了多少血」，
## 既不带类型也分不清是谁打的，「受到 N 点火焰伤害时」这类扳机需要这一条。
const DAMAGE := &"damage"
const DIED := &"died"
## 派发深度超限时记一条，便于内容配错时定位而不是直接崩
const DISPATCH_OVERFLOW := &"dispatch_overflow"
#endregion

#region resource_changed 的 reason
const REASON_DAMAGE := &"damage"
const REASON_HEAL := &"heal"
const REASON_COST := &"cost"
const REASON_REGEN := &"regen"
## 上限变动连带引起的当前值变化。与治疗区分开 ——
## 否则监听「生命恢复」的效果会把「强壮」生效误当成治疗。
const REASON_MAX_CHANGED := &"max_changed"
#endregion

## 回放视图需要的事件。日志只收这些，因此**日志内容与事件掩码无关** ——
## 掩码只管要不要派发给规则，不管要不要记账。
## 否则「掩码开／关两条路径日志逐条相同」这个不变式根本不可能成立。
const VIEW_EVENTS: Array[StringName] = [
	BATTLE_START, BATTLE_END, ITEM_FIRED, EFFECT_RESOLVED,
	STATUS_STACKED, STATUS_UNSTACKED, RESOURCE_CHANGED, DAMAGE, DIED, DISPATCH_OVERFLOW,
]


static func is_view_event(n: StringName) -> bool:
	return VIEW_EVENTS.has(n)


var name: StringName = &""
## 事件发生的时刻，定点秒。**不是帧号** —— 模拟里没有帧。
var time: int = 0
## 事件归属的一方（0 / 1），-1 表示全局
var side: int = -1
var payload: Dictionary = {}


static func make(p_name: StringName, p_time: int, p_side: int, p_payload: Dictionary = {}) -> BattleEvent:
	var e := BattleEvent.new()
	e.name = p_name
	e.time = p_time
	e.side = p_side
	e.payload = p_payload
	return e


func get_int(key: StringName, fallback: int = 0) -> int:
	return int(payload.get(key, fallback))


func get_name(key: StringName, fallback: StringName = &"") -> StringName:
	return StringName(payload.get(key, fallback))


func _to_string() -> String:
	return "[%.3fs side%d] %s %s" % [StatMath.to_float(time), side, name, payload]
