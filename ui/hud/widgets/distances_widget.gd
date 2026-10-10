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
	for pair in [[&"extract", "距最近撤离点"], [&"rest", "距最近休息区"], [&"core", "距核心"]]:
		var near := MapNavigator.nearest_of_type(run.map, at, pair[0])
		parts.append("%s %s 步" % [pair[1], str(near["steps"]) if int(near["id"]) >= 0 else "—"])
	return "　　".join(parts)
