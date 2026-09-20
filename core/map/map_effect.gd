## 地图作用域的效果。**占位，尚未实现。**
##
## 它现在就存在，是为了证明作用域这层抽象容纳得下战斗与掉落之外的第三类 ——
## 而不是等到做地图时才发现装不进去。具体能改什么（节点类型权重、移动消耗、
## 视野范围…）等 M3 定下来再加子类。
@abstract
class_name MapEffect
extends Effect

func scope() -> StringName:
	return EffectScope.MAP
