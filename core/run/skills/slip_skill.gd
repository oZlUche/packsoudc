## 脱身（136，安德烈乌斯）：在战前准备屏上用 —— 这一场不打，点算用过、没有战利品、不扣体力；搜索遭遇按打输收会话但不弹「被赶跑」。
## 核心点溜不掉。对猎手：开打前的事件屏上多一项「脱身」，选了必定逃掉（[HunterSystem] 合成那一项，次数与冷却同一本账）
class_name SlipSkill
extends RunSkill


func is_active() -> bool:
	return true


func map_usable() -> bool:
	return false


## 战前准备屏上能不能用（不看次数与冷却，那是 [RunSkills] 的事）：空串 = 能
static func blocked_reason(run: RunState) -> String:
	if run == null or run.events == null or run.events.pending_battle.is_empty():
		return UiText.t("log.prebattle_only")
	if StringName(String(run.events.pending_battle.get("type", ""))) == &"core":
		return UiText.t("log.slip_core")
	return ""


func activate(run: RunState) -> String:
	var why := blocked_reason(run)
	if why != "":
		return why
	return "" if run.events.skip_pending_battle() else UiText.t("log.no_pending_battle")


func describe() -> String:
	return UiText.t("log.slip_describe")
