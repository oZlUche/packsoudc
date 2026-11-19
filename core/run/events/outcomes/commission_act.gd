## 336（阵营与委托 W1）：后果 —— 在这个撤离点上做 [member action]（`inspect` 查验 / `deliver` 交信），记进这一局的委托进度。
## 交信当场成立（之后败退也算）。结果页写一句：查验了 / 信已送达 / 委托办成
class_name CommissionAct
extends EventOutcome

@export var action: StringName = &"inspect"


func apply(ctx: EventContext) -> void:
	if ctx == null or ctx.hooks == null:
		return
	for row in ctx.hooks.commission_act(action, ctx.node):
		var name := Names.of(Commissions.def(StringName(String((row as Dictionary).get("id", "")))))
		if action == &"deliver":
			ctx.log.append(UiText.t("notice.delivered") % name)
		elif not bool(row.get("finished", false)):
			ctx.log.append(UiText.t("notice.inspected"))
		if bool(row.get("finished", false)):
			ctx.log.append(UiText.t("notice.commission_done") % name)


func describe() -> String:
	return "委托：%s" % action
