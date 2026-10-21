## 军功（136，马库斯）：打赢的钱乘 [member factor]（节点敌人、猎手、核心都算）。[NodeEvents] 发钱时读 RunContext.battle_reward_mult
class_name BattleRewardMult
extends RunEffect

@export var factor: float = 1.25


func modify(ctx: RunContext) -> void:
	ctx.battle_reward_mult *= maxf(0.0, factor)


func describe() -> String:
	return UiText.t("bonus.battle_reward") % String.num(factor, 2)
