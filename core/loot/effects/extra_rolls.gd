## 增加掉落次数。
class_name ExtraRolls
extends LootEffect

@export var rolls: int = 1

func modify(ctx: LootContext) -> void:
	ctx.add_rolls(rolls)

func describe() -> String:
	return "掉落次数 %+d" % rolls
