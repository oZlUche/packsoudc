## 147：急救包 —— 回体力（满了不能用）。事件后果里也有回体力（[RestoreVitality]），那是事件那一层的，这个是随身道具的
class_name MendVitality
extends BeltEffect

@export var amount: int = 1


func blocked_reason(run: RunState) -> String:
	if run == null or run.vitality == null:
		return UiText.t("bonus.no_vitality")
	if run.vitality.is_full():
		return UiText.t("bonus.vitality_full")
	return ""


func apply(run: RunState) -> void:
	run.vitality.restore(amount, &"belt")


func describe() -> String:
	return UiText.t("bonus.mend") % amount
