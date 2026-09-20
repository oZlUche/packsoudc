## 一项属性的累积器：收集各来源的加成，按 [StatMath] 的约定算出终值。
##
## 所有数值都是 [constant StatMath.ONE] 标度的定点整数。
## 加成来源（包体效果、插槽点亮、状态效果）只管往里加，不关心先后 ——
## 乘区内相加、乘区间相乘都是可交换的，唯一有序的是乘区之间的乘法，
## 而那个顺序由枚举声明顺序固定，与调用顺序无关。
class_name StatValue
extends RefCounted

## 物品定义上写的基础值
var base: int = 0

## 固定加值，任意来源相加。在所有乘法之后加上，不吃百分比放大。
var flat: int = 0

var _mult: PackedInt32Array


func _init(p_base: int = 0) -> void:
	base = p_base
	_mult = PackedInt32Array()
	_mult.resize(StatMath.category_count())
	_mult.fill(0)


## 往某个乘区加一份加成（定点）。同一乘区内多次调用相加。
func add_mult(category: int, amount: int) -> void:
	if category < 0 or category >= _mult.size():
		push_error("StatValue.add_mult: 乘区下标越界 %d" % category)
		return
	_mult[category] += amount


## 便捷写法：add_percent(Buff.SHARP, 25) 等价于该乘区 +25%
func add_percent(category: int, percent: int) -> void:
	add_mult(category, StatMath.from_percent(percent))


func add_flat(amount: int) -> void:
	flat += amount


func mult_of(category: int) -> int:
	if category < 0 or category >= _mult.size():
		return 0
	return _mult[category]


## 按约定结算：base × ∏(1 + 各乘区) + flat
func total() -> int:
	var v := base
	for category in StatMath.categories():
		# 单个乘区的减益总和低于 −100% 时钳到 0，不允许出现负数因子 ——
		# 否则叠够减益反而会把伤害翻成正的
		var factor := maxi(0, StatMath.ONE + _mult[category])
		v = StatMath.mul(v, factor)
	return v + flat


## 终值取整，用于应用伤害或显示。
func total_int() -> int:
	return StatMath.to_int(total())


func clone() -> StatValue:
	var copy := StatValue.new(base)
	copy.flat = flat
	copy._mult = _mult.duplicate()
	return copy


func _to_string() -> String:
	var parts: Array[String] = []
	for category in StatMath.categories():
		if _mult[category] != 0:
			parts.append(
				"%s %+.0f%%" % [StatMath.category_name(category),
				StatMath.to_float(_mult[category]) * 100.0]
			)
	var mods := "，".join(parts) if not parts.is_empty() else "无乘区"
	return "StatValue(base=%.2f, %s, flat=%+.2f) = %.2f" % [
		StatMath.to_float(base), mods, StatMath.to_float(flat), StatMath.to_float(total())
	]
