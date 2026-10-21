## 147：腰带多几格（科技 / 角色 / 局外 buff 给）。[BeltModule] 开局与每次用东西时按它扩列
class_name BeltSlotsBonus
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.belt_slots_bonus += amount


func describe() -> String:
	return UiText.t("bonus.belt_slots") % amount
