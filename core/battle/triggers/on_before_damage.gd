## 受到／造成某类伤害【结算之前】。
##
## 这是减伤、免疫、伤害反转唯一的接入点：此刻伤害包还在手里，
## 用 [ModifyDamage] 改它，改完管线才继续往下算。
##
## [b]与 [OnDamage] 的区别是能不能改。[/b] 受伤后扳机看到的是既成事实，
## 适合反击、吸血、记账；受伤前扳机能改写这一下本身。
##
## [b]min_amount 在这里按护盾吸收后的待结算量判定[/b]，不是最终值 ——
## 最终值此刻还不存在，那正是本扳机要参与决定的东西。
class_name OnBeforeDamage
extends DamageTrigger


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.BEFORE_DAMAGE] as Array[StringName]


func _when() -> String:
	return "前"
