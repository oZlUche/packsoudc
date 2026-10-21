## 按概率放行。
##
## 随机必须走 battle 随机流（架构文档 1.4）—— 用全局 randf 会让回放与批量模拟失效。
##
## 掷骰在 can_pay 里发生，因此即便同一条规则的其他条件没过，随机流也已经推进了一格。
## 结果仍然确定，但 costs 列表里各条的顺序会影响随机序列，不要随意重排。
class_name ChanceCondition
extends Cost

## 0..100
@export var percent: int = 50


func can_pay(ctx: RuleContext) -> bool:
	var need := clampi(percent, 0, 100)
	return ctx.roll("chance", 1, 100, need) <= need


func pay(_ctx: RuleContext) -> void:
	pass


func describe() -> String:
	return UiText.t("cost.chance") % percent


## 151：几率本身
func estimated_factor(_ctx: PowerContext, _rate: float) -> float:
	return clampf(percent / 100.0, 0.0, 1.0)


func is_condition() -> bool:
	return true
