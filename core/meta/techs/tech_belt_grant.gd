## 160 补一：每升一级，每一局开局腰带里多 [member count] 个 [member skill]（[member MetaState.belt_grants]，开局经 [BeltModule] 的模块输入发）
class_name TechBeltGrant
extends TechEffect

## 随身技能 id（`data/belt_skills/`）
@export var skill: StringName = &""
## 每级几个
@export_range(1, 10) var count: int = 1


## 到 [param level] 级 = 每级的个数 × 级数（level 0 = 不发）
func derive(meta: MetaState, level: int) -> void:
	if meta == null or skill == &"":
		return
	if level > 0:
		meta.belt_grants[skill] = count * level
	else:
		meta.belt_grants.erase(skill)


func describe() -> String:
	return "开局腰带里多 %d 个%s" % [count, _name()]


func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	return "开局腰带里多 %d 个%s" % [count * level, _name()]


func _name() -> String:
	var def := BeltSkillDef.find(skill)
	return def.display_name if def != null else String(skill)
