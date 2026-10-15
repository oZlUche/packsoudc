## 175 补充四：给目标身上的一种状态加保底层数（[member BuffInstance.guard]）—— 凝毒（中毒）/ 冻疮（流血）。
##
## 保底以下的层数移除不掉、反应吃不掉、衰减（流血的减半）也压不下去；反应选印、算 N 时照常数全部层数。
## 目标身上没有、或层数低于保底，就补到保底（待定 补 4.5 A：「凝毒 N 层」= 直接给 N 层锁死的毒）。
## 不经 [method ApplyStatus.give]：这一下不引发反应
class_name GuardStatus
extends CombatEffect

@export var target: Target = Target.OPPONENT
@export var buff: BuffDef
## 保底加几层（反应里写 `{"stacks": "n"}` = N）
@export var stacks: int = 1


func apply(ctx: RuleContext) -> void:
	if buff == null or stacks <= 0:
		return
	for who in resolve_targets(ctx, target):
		if not who.dead:
			who.guard_buff(ctx.battle, buff, stacks)


func describe() -> String:
	if buff == null:
		return "锁定 ?"
	return "%s %d 层%s不可解除" % ["使对手" if target == Target.OPPONENT else "使你", stacks, Names.of(buff)]
