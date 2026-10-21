## 条件（136）：角色的局内技能 [member skill] 现在能用（有、次数没用完、没在冷却）。猎手的事件屏上「脱身」那一项用它锁
class_name SkillReady
extends EventCondition

@export var skill: StringName = &""


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.hooks != null and ctx.hooks.skill_ready(skill) == ""


func describe() -> String:
	return UiText.t("cond.skill_not_ready")
