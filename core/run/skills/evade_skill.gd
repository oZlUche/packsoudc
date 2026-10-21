## 躲避（安德烈乌斯）：用了之后接下来 [member steps] 步猎手够不着你（感知照旧、它照样动，只是不开打）。
## [HunterSystem.check_engagement] 读 [RunSkills.evading]。
class_name EvadeSkill
extends RunSkill

## 躲几步
@export var steps: int = 3


func is_active() -> bool:
	return true


func activate(run: RunState) -> String:
	if run == null or run.skills == null:
		return UiText.t("skill.no_state")
	run.skills.evade_left = maxi(run.skills.evade_left, steps)
	return ""


func describe() -> String:
	return UiText.t("skill.evade") % steps
