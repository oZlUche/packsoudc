## 消耗与条件：满足才执行（架构文档 4.4）。
##
## 「耐力够不够」与「次数攒够没有」在**失败行为上完全一致** ——
## 都是跳过效果但不退还冷却，所以归在同一层。
## 把它们分开会让频率层既要调度又要设卡，调度器就会在同一时刻空转。
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

## 轮到本条规则时立刻调用，无论最终是否执行。计数类在这里累加。
##
## 需要它是因为 [method can_pay] 必须只读，而「攒够 3 次才放」得把
## 没放出去的那两次也数进去。
func on_attempt(_ctx: RuleContext) -> void:
	pass


@abstract func can_pay(ctx: RuleContext) -> bool

@abstract func pay(ctx: RuleContext) -> void

## 117：内部日志里这条消耗 / 条件的样子（跳过时写「什么不够、差多少」）。默认只写类名，资源消耗写需要与现有
func trace_info(_ctx: RuleContext) -> Dictionary:
	return {"cost": RegistryLookup.class_of(self)}


## 151：战斗力估算的折扣（零到一，只缩不翻号）：付得起几成、条件满足几成。[param rate] = 这条规则一秒触发几次
func estimated_factor(_ctx: PowerContext, _rate: float) -> float:
	return 1.0


## 151：是条件（几率、状态、资源、轴），不是消耗 —— 编辑器分开列 C 与 K
func is_condition() -> bool:
	return false


## 142：给人看的一句（「若对手有流血」「消耗你 2 层蓄力」），只由字段拼出来。空 = 不写进规则行
func describe() -> String:
	return ""
