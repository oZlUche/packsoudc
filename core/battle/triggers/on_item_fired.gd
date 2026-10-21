## 有物品出手时触发 —— **连带触发就是它**，不是什么特殊机制。
##
## [member same_side] 区分听自己人还是听对手。
## [member source] 决定听谁：全场，还是只听与本物品**连结**的那几件。
class_name OnItemFired
extends Trigger

enum Source {
	ANY,     ## 符合 same_side 的任何物品
	LINKED,  ## 只听通过增益／受益格与本物品连结的物品
}

@export var same_side: bool = true

## 听谁出手。
##
## 本作**没有「主武器」这种设定**，所以「跟着某件特定道具一起触发」只能靠
## 摆放上的连结来表达：把配件贴在武器的增益格旁边，它就听得见那把武器。
## 这与《背包乱斗》的菱形槽是同一个意思 —— 连结关系由玩家摆出来，不是配出来的。
##
## LINKED 只在规则来自物品时有意义；来自 buff 或套装的规则没有 uid，也就没有邻居。
@export var source: Source = Source.ANY

## 直接按 uid 限定来源。
##
## [b]制作内容时用不上[/b]：uid 是实例在运行时分配的，.tres 里根本不存在。
## 它留给测试与程序化构造，内容侧请改用 [member source] = LINKED。
@export var source_uids: Array[int] = []

## 是否把自己出手也算上。默认否，否则容易写出自循环
@export var include_self: bool = false

## 175：只听规则的主人自己出手（附魔「出手时」）。勾了它别的来源条件都不看
@export var self_only: bool = false

## 132：只听带这些标签之一的件出手（`ranged` / `melee` / `weapon`…）；空 = 不限。和 [member source] = LINKED 可叠加
@export var source_tags: Array[StringName] = []


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.ITEM_FIRED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	var from_own_side := event.side == ctx.owner.side
	if from_own_side != same_side:
		return false
	var uid := event.get_int(&"uid")
	if self_only:
		return uid == ctx.source_uid() and uid != 0
	if not include_self and uid == ctx.source_uid():
		return false
	if not source_uids.is_empty() and not source_uids.has(uid):
		return false
	if source == Source.LINKED:
		# 对手身上的连结关系本方看不到，也不该看到
		if not from_own_side:
			return false
		var mine := ctx.source_uid()
		if mine == 0:
			return false  # 规则来自 buff 或套装，没有邻居可言
		if not ctx.owner.links_of(mine).has(uid):
			return false
	if not source_tags.is_empty():
		var shooter := ctx.side_of(from_own_side)
		if shooter == null:
			return false
		var tags := shooter.tags_of(uid)
		var hit := false
		for tag in source_tags:
			if tags.has(tag):
				hit = true
				break
		if not hit:
			return false
	return true


func describe() -> String:
	if self_only:
		return UiText.t("trig.self_fired")
	if not same_side:
		return UiText.t("trig.opp_fired") if source_tags.is_empty() else UiText.t("trig.opp_tag_fired") % _tag_names()
	var what := UiText.t("trig.item") if source_tags.is_empty() else _tag_names()
	if source == Source.LINKED:
		return UiText.t("trig.linked_fired") % what
	return UiText.t("trig.own_fired" if include_self else "trig.other_fired") % what


func _tag_names() -> String:
	var names: Array[String] = []
	for t in source_tags:
		names.append(Glossary.tag_name(t))
	return UiText.t("trig.tag_or").join(names)


## 151：一秒命中几次 —— 听对手出手按假定受击频率；听连结的邻居按假定邻居频率；听全场再加上自己（勾了「算自己」）
func estimated_rate(ctx: PowerContext, _cadence_hz: float) -> float:
	if self_only:
		return ctx.hz()
	if not same_side:
		return ctx.hits_taken()
	var rate := ctx.weights.neighbor_hz
	if include_self and source == Source.ANY:
		rate += ctx.hz()
	return rate
