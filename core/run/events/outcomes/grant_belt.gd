## 160 补一：后果 —— 往腰带里放几个随身技能（经 `belt_grant` hook；没腰带 / 格子满了就没发成，日志说一句）
class_name GrantBelt
extends EventOutcome

## 随身技能 id（`data/belt_skills/`）
@export var skill: StringName = &""
@export var count: int = 1


func apply(ctx: EventContext) -> void:
	if skill == &"" or count <= 0:
		return
	var got := ctx.hooks.belt_grant(skill, count) if ctx.hooks != null else 0
	var def := BeltSkillDef.find(skill)
	var name := Names.of(def) if def != null else String(skill)
	if got > 0:
		ctx.belts_given.append("%s ×%d" % [name, got])
	else:
		ctx.log.append("腰带满了，%s没放进去" % name)


func describe() -> String:
	return "给随身技能 %s ×%d" % [skill, count]
