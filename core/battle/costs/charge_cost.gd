## 攒够 N 次机会才放一发。
##
## 「每 3 次攻击附带一次爆发」用它：前两次调度到点时条件不满足，
## 效果被跳过但**冷却照常推进** —— 与耐力不足时的行为完全一致。
##
## 它之所以在消耗层而不是频率层：频率层负责「什么时候轮到我」，
## 挡不挡得住是消耗层的事。混在一起会让调度器在同一时刻空转。
class_name ChargeCost
extends Cost

const KEY := &"charges"

@export var n: int = 3


## 每次轮到就攒一次，无论最终放没放出去
func on_attempt(ctx: RuleContext) -> void:
	ctx.state()[KEY] = int(ctx.state().get(KEY, 0)) + 1


func can_pay(ctx: RuleContext) -> bool:
	return int(ctx.state().get(KEY, 0)) >= maxi(1, n)


func pay(ctx: RuleContext) -> void:
	ctx.state()[KEY] = 0
