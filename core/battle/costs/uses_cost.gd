## 全场限用 N 次。默认 1 次，即「每场战斗一次」。
class_name UsesCost
extends Cost

const KEY := &"uses"

@export var max_uses: int = 1


func can_pay(ctx: RuleContext) -> bool:
	return int(ctx.state().get(KEY, 0)) < maxi(1, max_uses)


func pay(ctx: RuleContext) -> void:
	ctx.state()[KEY] = int(ctx.state().get(KEY, 0)) + 1


func describe(_ctx: RuleContext) -> String:
	return "每场 %d 次" % max_uses
