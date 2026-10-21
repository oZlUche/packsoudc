## 提高「敌人掉落其自身携带道具」的概率。
##
## 与按掉落表随机生成不同，这条让玩家能定向抢夺看得见的东西 ——
## 搜刮环节因此从「开箱」变成「挑目标」。
class_name DropOwnedChance
extends LootEffect

## 百分比增量，0..100
@export var percent: int = 10

func modify(ctx: LootContext) -> void:
	ctx.add_drop_owned_chance(StatMath.from_percent(percent))

func describe() -> String:
	return UiText.t("loot.drop_owned") % percent
