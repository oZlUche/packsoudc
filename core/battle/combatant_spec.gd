## 一个战斗单位的完整编译结果。[BattleSim] 只吃它，不碰背包。
class_name CombatantSpec
extends RefCounted

var max_hp: int = 0                ## 定点
var abilities: Array[Ability] = [] ## 按 source_uid 升序，顺序稳定

## uid -> StatSet，供 UI 显示每件物品的终值。战斗本身不需要它。
var item_stats: Dictionary = {}


func max_hp_int() -> int:
	return StatMath.to_int(max_hp)


## 粗略 DPS，用于玩家拖动物品时的实时预估。
## 不考虑触发顺序与状态效果，只做手感参考。
func rough_dps() -> float:
	var total := 0.0
	for ability in abilities:
		var cd := StatMath.to_float(ability.cooldown())
		var haste := StatMath.to_float(ability.haste())
		if cd <= 0.0 or haste <= 0.0:
			continue
		total += StatMath.to_float(ability.damage()) * haste / cd
	return total


func _to_string() -> String:
	return "CombatantSpec(HP=%d, %d 个能力, 约 %.1f DPS)" % [
		max_hp_int(), abilities.size(), rough_dps()
	]
