## 150：距最近撤离点 / 休息区 / 核心几步（一起看才有意义，一个组件；待定 1 按推荐）。挑出生点时不显示
extends HudWidget


func title() -> String:
	return "距离"


func watch() -> Array[Signal]:
	return [run.travel.moved, run.phase_changed] as Array[Signal]


func text_of() -> String:
	if run.phase == RunState.Phase.PICK_SPAWN:
		return ""
	var at := run.travel.current_id
	var parts: Array[String] = []
	for pair in [[&"extract", "hud.dist_extract"], [&"rest", "hud.dist_rest"], [&"core", "hud.dist_core"]]:
		var near := MapNavigator.nearest_of_type(run.map, at, pair[0])
		parts.append(UiText.t("hud.dist_steps") % [UiText.t(pair[1]), str(near["steps"]) if int(near["id"]) >= 0 else "—"])
	return UiText.t("hud.dist_sep").join(parts)
