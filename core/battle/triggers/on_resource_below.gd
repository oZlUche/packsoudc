## 生命／耐力／法力降到某个值（或某个比例）以下时。
##
## 状态条件型扳机，在资源变化的那一刻求值。
## 「濒死时开盾」「耐力见底时回复」用它，比手写 on_resource_changed 再判条件直观。
class_name OnResourceBelow
extends Trigger

@export var resource_key: StringName = &"hp"
## 按上限的比例判定（0..100）。为 0 时改用 absolute。
@export var percent: int = 30
## 绝对值阈值，percent 为 0 时生效
@export var absolute: float = 0.0
@export var on_self: bool = true


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.RESOURCE_CHANGED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if event.get_name(&"key") != resource_key:
		return false
	if (event.side == ctx.owner.side) != on_self:
		return false
	var who := ctx.owner if on_self else ctx.opponent()
	var threshold := StatMath.from_float(absolute)
	if percent > 0:
		threshold = StatMath.mul(
			who.resources.maximum(resource_key), StatMath.from_percent(percent)
		)
	return who.resources.current(resource_key) <= threshold
