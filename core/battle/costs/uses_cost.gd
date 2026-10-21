## 全场限用 N 次。默认 1 次，即「每场战斗一次」。
class_name UsesCost
extends Cost

const KEY := &"uses"

@export var max_uses: int = 1


func can_pay(ctx: RuleContext) -> bool:
	return int(ctx.state().get(KEY, 0)) < maxi(1, max_uses)


func pay(ctx: RuleContext) -> void:
	ctx.state()[KEY] = int(ctx.state().get(KEY, 0)) + 1


func describe() -> String:
	return UiText.t("cost.per_battle") % max_uses


## 151：一场里用得完几成 = min(1, 次数 ÷ (一秒几次 × H))
func estimated_factor(ctx: PowerContext, rate: float) -> float:
	var want := rate * ctx.weights.horizon_sec
	return minf(1.0, max_uses / want) if want > 0.0 else 1.0
