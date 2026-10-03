## 118：每一级给一局一条局外 buff（[RunBuffDef]，`scope = META`）—— 第 k 级给 [member buffs] 的第 k 条，**替换**上一级那条。
## 记在 [member MetaState.tech_buffs]（和基地开发开关的 `active_buffs` 分开），开局和开关的一起传给 [RunState]，
## 效果、`RunContext`、各系统的读法、说明文字全走 buff 现成的那一套
class_name TechRunBuff
extends TechEffect

## 下标 k−1 = 第 k 级给的局外 buff id；条数等于科技的级数（导入器查）
@export var buffs: Array[StringName] = []


## 120：已到 [param level] 级时 tech_buffs 里只该有这项科技的第 level 条（level 0 = 一条都没有）
func derive(meta: MetaState, level: int) -> void:
	if meta == null:
		return
	_strip(meta)
	if level > 0 and not buffs.is_empty():
		meta.tech_buffs.append(buffs[mini(level, buffs.size()) - 1])


func describe() -> String:
	return "开局带一条局外 buff"


func describe_level(level: int, buff_defs: Dictionary = {}) -> String:
	if level < 1 or level > buffs.size():
		return ""
	var def: RunBuffDef = buff_defs.get(buffs[level - 1], null)
	return def.summary() if def != null else String(buffs[level - 1])


func _strip(meta: MetaState) -> void:
	for id in buffs:
		while meta.tech_buffs.has(id):
			meta.tech_buffs.erase(id)
