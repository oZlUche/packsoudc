## 掉落作用域的套装效果。
##
## [b]接口先留着，掉落系统（M4）尚未实现。[/b] 它存在的意义是证明作用域这层抽象
## 确实容纳得下战斗之外的效果 —— 而不是等到做掉落时才发现套装塞不进去。
class_name LootSetEffect
extends SetEffect

## 额外掉落次数
@export var extra_rolls: int = 0
## 稀有度权重偏移，正数偏向高稀有度
@export var rarity_bonus: int = 0


func scope() -> StringName:
	return SetScope.LOOT


func describe() -> String:
	var parts: Array[String] = []
	if extra_rolls != 0:
		parts.append("掉落次数 %+d" % extra_rolls)
	if rarity_bonus != 0:
		parts.append("稀有度权重 %+d" % rarity_bonus)
	return "，".join(parts)
