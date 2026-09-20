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


func define(key: StringName, max_value: int, fill: bool = true) -> void:
	_max[key] = maxi(0, max_value)
	_current[key] = _max[key] if fill else 0


func has(key: StringName) -> bool:
	return _max.has(key)


func current(key: StringName) -> int:
	return int(_current.get(key, 0))


func maximum(key: StringName) -> int:
	return int(_max.get(key, 0))


func is_empty_of(key: StringName) -> bool:
	return current(key) <= 0


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


func keys() -> Array:
	var k := _max.keys()
	k.sort()
	return k


func snapshot() -> Dictionary:
	var out := {}
	for key in keys():
		out[key] = [StatMath.to_int(current(key)), StatMath.to_int(maximum(key))]
	return out
