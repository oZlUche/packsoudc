## 一组属性的累积器：键名 → [StatValue]。
##
## 编译期每件物品一份。各来源（基础值、包体效果、插槽点亮）往里加，
## 最后统一 [method total_of] 取终值。
class_name StatSet
extends RefCounted

var _values: Dictionary = {}  # StringName -> StatValue


## 取该键的累积器，不存在则按该属性的默认基础值创建。
##
## 默认值取自 [method BattleStats.default_base] —— 对 haste 这类乘法单位元属性是 1.0，
## 其余是 0。用死的 0 会让「给未声明该属性的物品加百分比速度」算出 0。
func ensure(key: StringName) -> StatValue:
	var v: StatValue = _values.get(key, null)
	if v == null:
		v = StatValue.new(BattleStats.default_base(key))
		_values[key] = v
	return v


## 设置基础值（定点）。同一键重复设置会覆盖，不累加 ——
## 基础值只应来自物品定义这一个来源。
func set_base(key: StringName, base: int) -> void:
	ensure(key).base = base


## 153：去掉一项（格挡不跨件相加，汇总后由格挡层另算）
func erase(key: StringName) -> void:
	_values.erase(key)


func has(key: StringName) -> bool:
	return _values.has(key)


## 该键的终值（定点）。
##
## 键不存在时：**单位元类属性（haste）返回它自己的单位元 1.0**，
## 其余返回 [param fallback]（默认 0，便于区分「没有这项属性」与「算出来是 0」）。
##
## 单位元不走 fallback，是因为那样就得靠每个调用方都记得传 `StatMath.ONE`，
## 漏一处就会把速度当成 0，冷却随之被放大上万倍。属性的单位元是属性自身的性质。
func total_of(key: StringName, fallback: int = 0) -> int:
	var v: StatValue = _values.get(key, null)
	if v != null:
		return v.total()
	var identity := BattleStats.default_base(key)
	return identity if identity != 0 else fallback


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

