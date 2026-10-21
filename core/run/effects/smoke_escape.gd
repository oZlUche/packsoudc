## 147：烟雾弹 —— 战前准备屏上用：这一场不打（点算用过、没有战利品、不扣体力），和「脱身」（136）同一条路。
## 搜索遭遇按打输收会话、收获照交，但不弹「被赶跑」；核心点用不了
class_name SmokeEscape
extends BeltEffect


func blocked_reason(run: RunState) -> String:
	if run == null or run.events == null or run.events.pending_battle.is_empty():
		return UiText.t("log.prebattle_only")
	if StringName(String(run.events.pending_battle.get("type", ""))) == &"core":
		return UiText.t("bonus.smoke_core")
	return ""


func apply(run: RunState) -> void:
	run.events.skip_pending_battle()


func describe() -> String:
	return UiText.t("bonus.smoke")
