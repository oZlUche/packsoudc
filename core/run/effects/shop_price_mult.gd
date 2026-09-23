## 商店售价乘一个倍数（6.6）。几个一起生效就连乘
class_name ShopPriceMult
extends RunEffect

@export var factor: float = 0.9


func modify(ctx: RunContext) -> void:
	ctx.shop_price_mult *= maxf(0.0, factor)


func describe() -> String:
	return "商店售价 ×%.2f" % factor
