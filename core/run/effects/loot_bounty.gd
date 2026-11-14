## 319（局外机制树「精英 / BOSS 额外奖励」）：打赢这类点额外掉一件（[method DropResolver.bounty_pick]，档位权重在 [member DropRule.bounty_weights]）
class_name LootBounty
extends RunEffect

## 点的类型：elite = 精英，core = BOSS（核心点）
@export var node_type: StringName = &"elite"


func modify(ctx: RunContext) -> void:
	if not ctx.bounty.has(node_type):
		ctx.bounty.append(node_type)


func describe() -> String:
	return UiText.t("bonus.bounty_" + String(node_type))
