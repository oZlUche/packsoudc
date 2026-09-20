## 一件主动物品编译后的出手能力。全部数值为定点，且是编译期快照 ——
## 战斗过程中不再回头读背包。
class_name Ability
extends RefCounted

var source_uid: int = 0
var def_id: StringName = &""

## 结算后的属性快照
var stats: StatSet = null


func damage() -> int:
	return stats.total_of(BattleStats.DAMAGE)


## 基础冷却（定点秒）
func cooldown() -> int:
	return stats.total_of(BattleStats.COOLDOWN)


## 触发速度倍率（定点，1.0 为基准）
func haste() -> int:
	return stats.total_of(BattleStats.HASTE, StatMath.ONE)


func _to_string() -> String:
	return "Ability(%s uid=%d 伤害=%.1f 冷却=%.2fs 速度=%.2fx)" % [
		def_id, source_uid,
		StatMath.to_float(damage()),
		StatMath.to_float(cooldown()),
		StatMath.to_float(haste()),
	]
