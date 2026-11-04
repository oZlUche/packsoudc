## 侦察：隐形的猎手在这么多步以内对你可见（069 第六节的角色技能接口；猎手系统读 RunContext.scout_range）
class_name ScoutRange
extends RunEffect

@warning_ignore("shadowed_global_identifier")     # 内容字段名，改不得
@export var range: float = 2.0


func modify(ctx: RunContext) -> void:
	ctx.scout_range = maxf(ctx.scout_range, range)


func describe() -> String:
	return UiText.t("bonus.scout") % range
