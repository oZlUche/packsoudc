## 改伤害类型（132）：把正在结算的这一包换成另一种类型。**只在受伤前阶段有效**，和 [ModifyDamage] 同族。
##
## 换完之后的「招不招致反应」按新类型算（受伤后事件里的 provokes）；护甲那一步在受伤前之前，已经按原类型吸收过了。
## 直接 / 非直接（106）不变 —— 那是按来源定的，不是按类型。导入器不许转成 poison / bleed（作者定它们只在 buff 里）
class_name ConvertDamageType
extends CombatEffect

## 换成哪种伤害类型（id）
@export var to: StringName = &""


func apply(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or to == &"":
		return
	p.type = to


func describe() -> String:
	return "这一下改为%s伤害" % Glossary.damage_type_name(to)


## 151：估值 —— 零（元素抗性落地后再按目标抗性表算）；记零但不算「未估」
func estimated_value(_ctx: PowerContext) -> float:
	return 0.0
