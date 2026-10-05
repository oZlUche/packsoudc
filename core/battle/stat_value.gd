## 一项属性的累积器：收集各来源的加成，按 [StatMath] 的约定算出终值。
##
## 所有数值都是 [constant StatMath.ONE] 标度的定点整数。
## 加成来源（包体效果、插槽点亮、状态效果）只管往里加，不关心先后 ——
## 133：只剩一个乘区，乘算相加、加算相加，都可交换，结果与调用顺序无关。
class_name StatValue
extends RefCounted

## 物品定义上写的基础值
var base: int = 0:
	set(v):
		base = v
		_valid = false

## 加算之和，任意来源相加。在乘法之后加上，不吃百分比放大。
var flat: int = 0:
	set(v):
		flat = v
		_valid = false

## 乘算之和（定点：0.25 = +25%）。所有乘算先相加，再乘一次
var percent: int = 0:
	set(v):
		percent = v
		_valid = false

## total() 的结果缓存。属性在战斗中被反复读取（每次冷却查询要读速率与周期），不缓存的话这是最热的一条路径。
var _cached: int = 0
var _valid: bool = false


func _init(p_base: int = 0) -> void:
	base = p_base


## 加一份乘算（百分数：25 = +25%，−10 = −10%）
func add_percent(p: float) -> void:
	percent += StatMath.from_float(p / 100.0)


## 加一份乘算（定点：2500 = +25%）
func add_percent_fixed(amount: int) -> void:
	percent += amount


func add_flat(amount: int) -> void:
	flat += amount  # setter 会置脏


## 按约定结算：base × max(0, 1 + 乘算之和) + 加算之和
func total() -> int:
	if _valid:
		return _cached
	# 乘算之和低于 −100% 时钳到 0，不允许出现负数因子 —— 否则叠够减益反而会把伤害翻成正的
	_cached = StatMath.mul(base, maxi(0, StatMath.ONE + percent)) + flat
	_valid = true
	return _cached


## 终值取整，用于应用伤害或显示。
func total_int() -> int:
	return StatMath.to_int(total())


func clone() -> StatValue:
	var copy := StatValue.new(base)
	copy.flat = flat
	copy.percent = percent
	copy._valid = false
	return copy


func _to_string() -> String:
	return "StatValue(base=%.2f, 乘算 %+.0f%%, 加算 %+.2f) = %.2f" % [
		StatMath.to_float(base), StatMath.to_float(percent) * 100.0, StatMath.to_float(flat), StatMath.to_float(total())
	]
