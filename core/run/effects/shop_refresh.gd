## 319（局外机制树「局内商店刷新」）：每家局内商店能付钱换一次货（价钱在 [member EconomyRules.shop_refresh_price]，[method ShopSession.refresh]）
class_name ShopRefresh
extends RunEffect

@export var times: int = 1


func modify(ctx: RunContext) -> void:
	ctx.shop_refreshes += maxi(0, times)


func describe() -> String:
	return UiText.t("bonus.shop_refresh") % times
