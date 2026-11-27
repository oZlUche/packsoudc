## 大地之神【驻扎】给的【扎营】：脚下这个点变成【休息点】（当没踩过、当场休息）。核心、撤离点不行
class_name EarthCamp
extends BeltEffect


func blocked_reason(run: RunState) -> String:
	if run == null or run.phase != RunState.Phase.ON_MAP or run.events == null:
		return UiText.t("log.not_on_map")
	var node := run.current_node()
	if node == null:
		return UiText.t("log.not_on_map")
	var type := NodeEvents.effective_type(node)
	if type in [&"core", &"extract"]:
		return UiText.t("bonus.earth_camp_no")
	if type == &"rest" and not node.is_visited():
		return UiText.t("bonus.earth_camp_already")
	if run.events.pending_event() != null or not run.events.pending_battle.is_empty() or run.events.current_search != null or run.events.current_shop != null:
		return UiText.t("bonus.earth_camp_busy")
	return ""


func apply(run: RunState) -> void:
	var node := run.current_node()
	for k in ["used_rest", "used_altar", "used_forge", "revisit_event"]:
		node.content.erase(k)
	run.events.retype(node, &"rest")
	run.events.handle(node)


func describe() -> String:
	return UiText.t("bonus.earth_camp")
