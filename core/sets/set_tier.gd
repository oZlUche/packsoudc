## 套装的一个档位：集齐几件时生效，生效什么。
class_name SetTier
extends Resource

## 达到几件时生效
@export var pieces: int = 2

## 编译期属性修饰，按物品施加
@export var mods: Array[StatModifier] = []

## 战斗规则。需要扳机，因此不能只是一条裸效果。
## 不属于任何物品，来源 uid 为 0，取属性时退回单位级。
@export var rules: Array[AbilityRule] = []

## 非战斗作用域的效果（战利品、地图…）。**激活即生效，不需要扳机。**
##
## 三个列表分开而不是并成一个，是因为它们生命周期确实不同：
## mods 在编译期一次性并入；rules 由扳机驱动；effects 在别的系统的别的阶段被查询。
## 并成一个列表后消费方还是得按类型分拣，只是把分拣挪到了运行时。
@export var effects: Array[Effect] = []


## 取本档中属于某作用域的效果
func effects_in(scope: StringName) -> Array[Effect]:
	var out: Array[Effect] = []
	for e in effects:
		if (e as Effect).scope() == scope:
			out.append(e)
	return out
