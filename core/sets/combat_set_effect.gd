## 战斗作用域的套装效果：属性加成与规则。
##
## 一次性增益写 [member mods]；周期性效果写 [member rules]
## （例如 `OnSchedule + Cooldown(5.0) + Heal`）。
class_name CombatSetEffect
extends SetEffect

enum Target {
	SET_PIECES,  ## 只加给该套装的部件
	ALL_ITEMS,   ## 加给棋盘上所有参战物品
}

@export var target: Target = Target.SET_PIECES
@export var mods: Array[StatModifier] = []

## 套装自带的规则。来源 uid 为 0，因此取属性时退回单位级。
##
## 想改单位级属性（生命上限之类），不要在 mods 里写 —— mods 是按物品施加的，
## 逐件放大再求和不等于整体放大。改用一条
## `OnBattleStart + Always + ApplyStatus(某 buff)` 的规则，让 buff 去改单位属性。
@export var rules: Array[AbilityRule] = []


func scope() -> StringName:
	return SetScope.COMBAT


func describe() -> String:
	var parts: Array[String] = []
	if not mods.is_empty():
		parts.append("%d 项属性加成" % mods.size())
	if not rules.is_empty():
		parts.append("%d 条规则" % rules.size())
	return "，".join(parts)
