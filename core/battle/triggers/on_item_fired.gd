## 有物品出手时命中 —— **连带触发就是它**，不是什么特殊机制。
##
## [member same_side] 决定听自己人还是听对手。
## [member source_uids] 非空时只听指定来源，编译期可由邻接标记填入，
## 从而表达「我的增益格上的物品出手时，我也跟着出手」。
class_name OnItemFired
extends Trigger

@export var same_side: bool = true
## 为空表示不限来源
@export var source_uids: Array[int] = []
## 是否把自己出手也算上。默认否，否则极易写出自我循环
@export var include_self: bool = false


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.ITEM_FIRED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	var from_own_side := event.side == ctx.owner.side
	if from_own_side != same_side:
		return false
	var uid := event.get_int(&"uid")
	if not include_self and uid == ctx.source_uid():
		return false
	if not source_uids.is_empty() and not source_uids.has(uid):
		return false
	return true
