## 150：行动点（挑出生点时写「挑出生点」）
extends HudWidget


func title() -> String:
	return "行动点"


func watch() -> Array[Signal]:
	return [run.travel.moved, run.travel.waited, run.phase_changed] as Array[Signal]


func text_of() -> String:
	if run.phase == RunState.Phase.PICK_SPAWN:
		return "行动点 —　　挑出生点"
	return "行动点 %d" % run.travel.clock.total
