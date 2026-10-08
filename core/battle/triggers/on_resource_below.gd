## 生命／耐力／法力降到某个值（或某个比例）以下时。
##
## 状态条件型扳机，在资源变化的那一刻求值。
## 「濒死时开盾」「耐力见底时回复」用它。
##
## 132：[member direction] = ABOVE 时反过来 —— 涨到阈值**以上**（含）时；[member full] = 回满（等于上限）。
## 类名不动，旧内容不改
class_name OnResourceBelow
extends Trigger

enum Direction { BELOW, ABOVE }

@export var resource_key: StringName = &"hp"
## 按上限的比例判定（0..100）。为 0 时改用 absolute。
@export var percent: int = 30
## 绝对值阈值，percent 为 0 时生效
@export var absolute: float = 0.0
@export var on_self: bool = true
## 132：BELOW = 降到阈值以下（含）；ABOVE = 涨到阈值以上（含）
@export var direction: Direction = Direction.BELOW
## 132：回满 —— 当前值等于上限时（忽略 percent / absolute，只配 ABOVE 有意义）
@export var full: bool = false


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.RESOURCE_CHANGED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if event.get_name(&"key") != resource_key:
		return false
	if not ctx.event_on(event, on_self):
		return false
	var who := ctx.side_of(on_self)
	var cur := who.resources.current(resource_key)
	if full:
		return cur >= who.resources.maximum(resource_key)
	var threshold := StatMath.from_float(absolute)
	if percent > 0:
		threshold = StatMath.mul(
			who.resources.maximum(resource_key), StatMath.from_percent(percent)
		)
	return cur >= threshold if direction == Direction.ABOVE else cur <= threshold


func describe() -> String:
	var who := "你" if on_self else "对手"
	var res := Glossary.resource_name(resource_key)
	if full:
		return "%s的%s回满时" % [who, res]
	var at := ("%d%%" % percent) if percent > 0 else TextTemplate.num(absolute)
	return "%s的%s%s %s 时" % [who, res, "不低于" if direction == Direction.ABOVE else "低于", at]
