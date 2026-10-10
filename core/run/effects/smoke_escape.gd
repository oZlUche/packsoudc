## 147：烟雾弹 —— 战前准备屏上用：这一场不打（点算用过、没有战利品、不扣体力），和「脱身」（136）同一条路。
## 搜索遭遇按打输收会话、收获照交，但不弹「被赶跑」；核心点用不了
class_name SmokeEscape
extends BeltEffect


func blocked_reason(run: RunState) -> String:
	if run == null or run.events == null or run.events.pending_battle.is_empty():
		return "只能在开战前用"
	if StringName(String(run.events.pending_battle.get("type", ""))) == &"core":
		return "核心的战斗躲不开"
	return ""


func apply(run: RunState) -> void:
	run.events.skip_pending_battle()


func describe() -> String:
	return "这一场不打：不扣体力、没有战利品（核心用不了）"
