## 生命、耐力、法力等资源的统一容器（架构文档 4.4）。
##
## 不为每种资源单开字段与事件 —— 一切变动都走 [constant BattleEvent.RESOURCE_CHANGED]，
## 靠 key 区分。新增一种资源不需要改这里，也不需要改 [BattleSim]。
##
## 全部为 [constant StatMath.ONE] 标度的定点整数。
class_name ResourcePool
extends RefCounted

## 资源变动时发出：key、实际变化量、原因。
## [b]实际变化量可能小于请求量[/b]（打到 0 封顶、超上限截断）——
## 「受到 50 伤害」和「实际掉了 12 点血」是两回事，监听者关心的通常是后者。
signal changed(key: StringName, delta: int, reason: StringName)

var _current: Dictionary = {}  # StringName -> int
var _max: Dictionary = {}      # StringName -> int

## 每种资源上一次结算回复的时刻（定点秒）。
##
## 回复不走定时器：推进器到达某个时刻时，才按「距这里过了多久」一次性补上。
## 事件驱动的模拟里没有「每秒」这回事，硬造一个每秒事件等于把帧又请回来了。
var _regen_at: Dictionary = {}  # StringName -> int


func define(key: StringName, max_value: int) -> void:
	_max[key] = maxi(0, max_value)
	_current[key] = _max[key]


func has(key: StringName) -> bool:
	return _max.has(key)


func current(key: StringName) -> int:
	return int(_current.get(key, 0))


func maximum(key: StringName) -> int:
	return int(_max.get(key, 0))


func can_afford(key: StringName, amount: int) -> bool:
	return current(key) >= amount


## 改变当前值，返回**实际**变化量。超出边界的部分被截断。
func change(key: StringName, delta: int, reason: StringName) -> int:
	if not _max.has(key) or delta == 0:
		return 0
	var before := int(_current[key])
	var after := clampi(before + delta, 0, int(_max[key]))
	var actual := after - before
	if actual == 0:
		return 0
	_current[key] = after
	changed.emit(key, actual, reason)
	return actual


## 调整上限。
##
## **上限增加时当前值同量增加**（吃到「强壮」立刻多一截血，反馈即时）；
## 上限降低时当前值按新上限截断。连带产生的当前值变化以
## [constant BattleEvent.REASON_MAX_CHANGED] 发出，与治疗区分开。
func set_max(key: StringName, new_max: int) -> void:
	new_max = maxi(0, new_max)
	if not _max.has(key):
		define(key, new_max)
		return
	var old_max := int(_max[key])
	if new_max == old_max:
		return
	_max[key] = new_max

	var before := int(_current[key])
	var after := before
	if new_max > old_max:
		after = before + (new_max - old_max)
	after = clampi(after, 0, new_max)
	if after != before:
		_current[key] = after
		changed.emit(key, after - before, BattleEvent.REASON_MAX_CHANGED)


## 把某种资源的回复补算到 [param now]，返回实际补了多少。
##
## [param rate] 是**每秒**回复量（定点），由调用方按当刻属性算好传进来 ——
## 资源池不认识属性表，也就不认识 buff。
##
## 线性累积，所以结算得勤一点不会算多：`settle(t1)` 之后再 `settle(t2)`
## 与直接 `settle(t2)` 等价。勤结算反而更准 —— 速率被 buff 改变的那一刻
## 正好是一个时刻点，在那里结算，前后两段就各按各的速率算。
func settle_regen(key: StringName, rate: int, now: int) -> int:
	if not has(key):
		return 0
	var since: int = _regen_at.get(key, 0)
	_regen_at[key] = now
	if rate <= 0 or now <= since:
		return 0
	var gain := StatMath.mul(now - since, rate)
	if gain <= 0:
		return 0
	return change(key, gain, BattleEvent.REASON_REGEN)


## 把所有资源的结算起点对齐到某一时刻，不补任何量。开战时调一次。
func reset_regen_clock(now: int) -> void:
	for key in _max:
		_regen_at[key] = now


func keys() -> Array:
	var k := _max.keys()
	k.sort()
	return k


func snapshot() -> Dictionary:
	var out := {}
	for key in keys():
		out[key] = [StatMath.to_int(current(key)), StatMath.to_int(maximum(key))]
	return out
