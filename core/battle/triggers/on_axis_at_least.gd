## 某条标准轴到了 N 层时（4.3「标准轴」，103 4e），与 [OnStacksAtLeast] 同构：条件在层数变化的那一刻求值。
## [member layer] 选数哪一层：合计 / 内容层 / 系统层（自然 5 级「加时开始后」数的是受到伤害轴的系统层）
class_name OnAxisAtLeast
extends Trigger

enum Layer { TOTAL, CONTENT, SYSTEM }

@export var axis: StringName = &""
## 至少几层（可为负：-3 = 「减速到 3 层及以上」时，按绝对值比、要求同号）
@export var stacks: int = 1
## 自己身上的还是对手身上的
@export var on_self: bool = true
@export var layer: Layer = Layer.TOTAL


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.AXIS_SHIFTED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if event.get_name(&"axis") != axis:
		return false
	if (event.side == ctx.owner.side) != on_self:
		return false
	var who := ctx.owner if on_self else ctx.opponent()
	var have := who.axis_total(axis)
	if layer == Layer.CONTENT:
		have = who.axis_stacks(axis)
	elif layer == Layer.SYSTEM:
		have = who.axis_system(axis)
	if stacks < 0:
		return have <= stacks
	return have >= maxi(1, stacks)
