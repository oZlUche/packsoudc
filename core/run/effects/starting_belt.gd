## 160 补一：开局往腰带里发几个随身技能（角色能力、局外 buff 给）。[BeltModule] 第一次装上时按 [member RunContext.belt_start] 发
class_name StartingBelt
extends RunEffect

## 随身技能 id（`data/belt_skills/`）
@export var skill: StringName = &""
@export var count: int = 1


func modify(ctx: RunContext) -> void:
	if skill != &"" and count > 0:
		ctx.belt_start[skill] = int(ctx.belt_start.get(skill, 0)) + count


func describe() -> String:
	var def := BeltSkillDef.find(skill)
	return UiText.t("bonus.starting_belt") % [count, Names.of(def) if def != null else String(skill)]
