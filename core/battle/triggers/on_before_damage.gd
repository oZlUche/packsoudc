## 受到／造成某类伤害【结算之前】。
##
## 这是减伤、免疫、伤害反转唯一的接入点：此刻伤害包还在手里，
## 用 [ModifyDamage] 改它，改完管线才继续往下算。
##
## [b]与 [OnDamage] 的区别是能不能改。[/b] 受伤后扳机看到的是既成事实，
## 适合反击、吸血、记账；受伤前扳机能改写这一下本身。
##
## [b]min_amount 在这里按这一下原本多重判定[/b]（305：护甲挪到最后，这时还没吸收），不是最终值 ——
## 最终值此刻还不存在，那正是本扳机要参与决定的东西。
class_name OnBeforeDamage
extends DamageTrigger


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.BEFORE_DAMAGE] as Array[StringName]


func _phase() -> int:
	return PHASE_BEFORE


## 作者 11-26 14:14：真实伤害不被来源以外的效果影响，只有【免疫伤害】类效果能免疫它 ——
## 真实伤害这一下只放行带 [member ModifyDamage.cancel] 的规则（别的减伤、反转、改类型都不碰，也不扣它们的消耗）
func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if event.get_bool(&"pure") and not _immunity(ctx):
		return false
	return super.matches(ctx, event)


static func _immunity(ctx: RuleContext) -> bool:
	var rule := ctx.runtime.rule if ctx.runtime != null else null
	if rule == null:
		return false
	for fx in rule.effects:
		if fx is ModifyDamage and (fx as ModifyDamage).cancel:
			return true
	return false
