## 突击（马库斯）：用了之后**下次进入战斗**先扣掉对方 [member hp_fraction] 的生命上限。旗子跟着存档，打完那一场才撤。
class_name AssaultSkill
extends RunSkill

## 扣对方几成生命（0.3 = 三成）
@export var hp_fraction: float = 0.3


func is_active() -> bool:
	return true


func arms_battle() -> bool:
	return true


func activate(_run: RunState) -> String:
	return ""


func prepare_battle(_me: CombatantSpec, enemy: CombatantSpec) -> void:
	if enemy == null:
		return
	enemy.max_hp = maxi(1, int(roundf(float(enemy.max_hp) * (1.0 - clampf(hp_fraction, 0.0, 1.0)))))


func describe() -> String:
	return UiText.t("skill.assault") % (hp_fraction * 100.0)
