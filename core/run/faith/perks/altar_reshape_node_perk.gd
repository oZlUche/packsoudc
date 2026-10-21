## 大地 4 级（093，作者定：只在神坛上用、不限次数）：把当前所处的点改成别的类型（核心 / 撤离以外），关掉神坛立刻发生
class_name AltarReshapeNodePerk
extends FaithPerk

@export var types: Array[StringName] = [&"battle", &"elite", &"search", &"event", &"shop"]


func altar_label() -> String:
	return UiText.t("perk.reshape_label")


func altar_options() -> Array[StringName]:
	return types


func altar_apply(run: RunState, node: MapNode, option: StringName = &"") -> String:
	if node == null or option == &"" or not types.has(option) or option in [&"core", &"extract", &"spawn", &"junction"]:
		return ""
	run.events.retype(node, option)
	return UiText.t("perk.reshape_done") % NodeText.label_of(option)


func _summary() -> String:
	return UiText.t("perk.reshape_summary")
