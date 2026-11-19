## 150：侵蚀一句（075）：几步后开始 / 第几档、下一档还有几步 / 全图。没有侵蚀场不显示
extends HudWidget


func title() -> String:
	return "侵蚀"


func watch() -> Array[Signal]:
	var f: ErosionField = run.travel.erosion
	return ([f.advanced, f.warned] if f != null else []) as Array[Signal]


func text_of() -> String:
	var f: ErosionField = run.travel.erosion if run.travel != null else null
	if f == null:
		return ""
	if f.is_total():
		return UiText.t("hud.erosion_total")
	if not f.started():
		return UiText.t("hud.erosion_soon") % f.actions_left()
	return UiText.t("hud.erosion_band") % [f.eroded_bands + 1, f.actions_left()]
