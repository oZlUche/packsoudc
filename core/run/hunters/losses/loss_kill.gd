## 输了直接战败（必杀）
class_name LossKill
extends HunterLossOutcome


func apply(_h: Hunter, sys: HunterSystem) -> void:
	sys.kill_player()


func describe() -> String:
	return UiText.t("hunter.loss_kill")
