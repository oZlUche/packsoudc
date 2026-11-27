## 大地之神【密道】给的【穿行】：用了之后地图上 3 步之内的点都能直接去一次（点一下就传过去，计一步），
## 还没去就留着（存在 [member LevelModule.god_state]），一次只能攒一回。走法见 [method EarthHeavenPerk.walk_to]
class_name EarthWalk
extends BeltEffect


func blocked_reason(run: RunState) -> String:
	if run == null or run.phase != RunState.Phase.ON_MAP or run.map == null or run.travel == null:
		return UiText.t("log.not_on_map")
	if EarthHeavenPerk.walk_armed(run):
		return UiText.t("bonus.earth_walk_armed")
	if LevelModule.of(run) == null or EarthHeavenPerk.walk_targets(run, true).is_empty():
		return UiText.t("bonus.earth_walk_none")
	return ""


func apply(run: RunState) -> void:
	EarthHeavenPerk.arm_walk(run)


func describe() -> String:
	return UiText.t("bonus.earth_walk") % EarthHeavenPerk.WALK_RANGE
