## 消耗：付得起才执行（架构文档 4.4）。
##
## [b]与冷却刻意不原子。[/b] 冷却到点后才检查消耗，付不起则跳过效果，
## 但冷却照常清零 —— 否则武器会在耐力回满的那一瞬间立刻打出，
## 等于耐力不足毫无代价，耐力管理不构成决策。
##
## [b]这不是疏忽，不要「修」它。[/b]
##
## 但 [member AbilityRule.costs] 这一层[b]内部[/b]仍然原子：全部 [method can_pay]
## 通过才逐个 [method pay]，不允许出现「扣了耐力但层数不够」的半付款。
@abstract
class_name Cost
extends Resource

@abstract func can_pay(ctx: RuleContext) -> bool

@abstract func pay(ctx: RuleContext) -> void

## 给 UI 用的说明，例如「耐力 10」
func describe(_ctx: RuleContext) -> String:
	return ""
