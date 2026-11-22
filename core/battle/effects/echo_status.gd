## 372（作者 18:30 / 18:53）：元素回响 —— 刚给对手施加的那一种元素印，再多叠 [member stacks] 层。
##
## 只配「某状态被施加时」（[OnStatusApplied]）用：施加的是哪一种从触发它的那条事件里读，所以燃烧、冰冻、感电、中毒、流血都算；
## 不是元素印的状态（增益、减益）不跟。频率由规则的冷却管（「每 N 秒，下一次施加」），冷却先提交再放效果，
## 所以这一下补的层数再发一条「被施加」也不会再点着自己。规则由 [LevelModule] 按拿过几张牌现拼，不走内容管线
class_name EchoStatus
extends CombatEffect

@export var stacks: int = 1


func apply(ctx: RuleContext) -> void:
	if ctx.event == null or ctx.event.name != BattleEvent.STATUS_APPLIED:
		return
	var buff_id := ctx.event.get_name(&"buff")
	var who := ctx.opponent()
	if who == null or who.dead:
		return
	var inst := who.find_buff(buff_id)
	if inst == null or inst.def == null or inst.def.element == &"":
		return
	ApplyStatus.give(ctx, who, inst.def, maxi(1, stacks))


func describe() -> String:
	return UiText.t("fx.echo") % maxi(1, stacks)
