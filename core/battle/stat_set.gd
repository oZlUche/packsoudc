## 一组属性的累积器：键名 → [StatValue]。
##
## 编译期每件物品一份。各来源（基础值、包体效果、插槽点亮）往里加，
## 最后统一 [method total_of] 取终值。
class_name StatSet
extends RefCounted

var _values: Dictionary = {}  # StringName -> StatValue


## 取该键的累积器，不存在则以 0 为基础值创建。
func ensure(key: StringName) -> StatValue:
	var v: StatValue = _values.get(key, null)
	if v == null:
		v = StatValue.new(0)
		_values[key] = v
	return v


## 设置基础值（定点）。同一键重复设置会覆盖，不累加 ——
## 基础值只应来自物品定义这一个来源。
func set_base(key: StringName, base: int) -> void:
	ensure(key).base = base


func has(key: StringName) -> bool:
	return _values.has(key)


## 该键的终值（定点）。键不存在时返回 [param fallback]，
## 便于区分「没有这项属性」与「这项属性算出来是 0」。
func total_of(key: StringName, fallback: int = 0) -> int:
	var v: StatValue = _values.get(key, null)
	return v.total() if v != null else fallback


func total_int_of(key: StringName, fallback: int = 0) -> int:
	return StatMath.to_int(total_of(key, fallback))


## 键名列表，按字典序 —— 顺序稳定，便于快照比对与测试。
func keys() -> Array:
	var k := _values.keys()
	k.sort()
	return k


func clone() -> StatSet:
	var copy := StatSet.new()
	for key in _values:
		copy._values[key] = (_values[key] as StatValue).clone()
	return copy


## 调试用快照：键 → 取整后的终值。
func snapshot() -> Dictionary:
	var out := {}
	for key in keys():
		out[key] = total_int_of(key)
	return out
