## 输了玩家退回上一步（134 驱逐档）：猎手在进点之前追上的，这个点视为没进（不标走过、事不发生、不记首访）；
## 已经在点上忙完才追上的，只退位置。猎手不驻守（要驻守用 [LossExpelAndGuard]）
class_name LossExpel
extends HunterLossOutcome


func apply(_h: Hunter, sys: HunterSystem) -> void:
	sys.expel_player()


func describe() -> String:
	return UiText.t("hunter.loss_expel")
