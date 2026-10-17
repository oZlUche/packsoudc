## 150：这一局的 buff 一句：局外的和一局里拿到的都列，有时限的写还剩几步。没有 buff 不显示
extends HudWidget


func title() -> String:
	return "buff"


func watch() -> Array[Signal]:
	var mod := BuffModule.of(run)
	return ([mod.buffs_changed] if mod != null else []) as Array[Signal]


func text_of() -> String:
	var parts: Array[String] = []
	for id in run.meta_buffs:
		var def: RunBuffDef = run.buff_defs.get(id, null)
		parts.append(def.display_name if def != null else String(id))
	for entry in BuffModule.entries_of(run):
		var def: RunBuffDef = run.buff_defs.get(StringName(String(entry["id"])), null)
		var name := def.display_name if def != null else String(entry["id"])
		parts.append(name + ("（剩 %d 步）" % int(entry["left"]) if int(entry["left"]) > 0 else ""))
	return "状态：" + "、".join(parts) if not parts.is_empty() else ""
