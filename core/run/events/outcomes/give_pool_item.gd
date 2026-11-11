## 后果：从主题奖励池（[RewardPool]）里给东西（事件方案 2026-11-11 §8.4）。
##
## 抽几件、抽到哪件不在这里掷：事件挂起时就按 [member key] 抽好、冻结在节点内容里（[EventRewards]），
## 这里只把冻结的那几件发出去 —— 重进、读档、换着看选项都不会重抽。同一个 [member key] 的几个选项（钱买 / 材料换）发的是同一份。
## 池里没有合格候选时冻结的是空的：这个选项灰掉（[method blocked_reason]），不先扣代价再给空
class_name GivePoolItem
extends EventOutcome

@export var pool: StringName = &""
## 这一份奖励的名字（同一事件里不同选项共用一份就写同一个）；空 = 用池的 id
@export var key: StringName = &""
## 抽几次（每次一件，有放回）
@export var count: int = 1


func reward_key() -> StringName:
	return key if key != &"" else pool


func apply(ctx: EventContext) -> void:
	for id in EventRewards.ensure(ctx, self):
		ctx.items_given.append(id)
		ctx.reward_names[reward_key()] = id


func blocked_reason(ctx: EventContext) -> String:
	return UiText.t("cond.reward_empty") if EventRewards.ensure(ctx, self).is_empty() else ""


func describe() -> String:
	return "从 %s 给 %d 件" % [pool, count]
