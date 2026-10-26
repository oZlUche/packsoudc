## 求饶（256，安德烈乌斯）：会扣体力的一场打输了，对方开价（打赢的钱 × [member mult]），拿金币和道具抵掉体力损失。
## 核心点与搜索遭遇不给。[NodeEvents] 读 RunContext.ransom_mult，几个来源取最大
class_name Ransom
extends RunEffect

@export var mult: float = 3.0


func modify(ctx: RunContext) -> void:
	ctx.ransom_mult = maxf(ctx.ransom_mult, mult)


func describe() -> String:
	return UiText.t("bonus.ransom")
