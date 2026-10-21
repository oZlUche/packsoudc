## 后果（095）：赐福一件 —— 棋盘（其次地上）里能被赐福的最值钱的一件换成赐福版。[member faith] 空 = 激活的信仰（没激活就不做）
class_name BlessItem
extends EventOutcome

@export var faith: StringName = &""


func apply(ctx: EventContext) -> void:
	var fid := faith
	if fid == &"":
		fid = ctx.active_faith_id()
	if fid == &"" or ctx.items == null:
		return
	for c in [ctx.board, ctx.storage]:
		var inst := Blessings.best_candidate(c, ctx.items, fid)
		if inst != null:
			var was := Names.of(inst.def)
			var v := Blessings.bless_instance(inst, ctx.items, fid)
			if v != null:
				ctx.log.append(UiText.t("outcome.blessed") % [was, Names.of(v)])
				if c != null and c.has_signal("changed"):
					c.changed.emit()
			return


func describe() -> String:
	return "赐福一件（%s）" % ("激活的信仰" if faith == &"" else String(faith))
