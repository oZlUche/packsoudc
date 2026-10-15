## 法杖轮读（175 第二批，作者定）：这一下读装载的第几颗晶石，就打它的元素、加它的伤害。
##
## 读哪颗由 [CycleCadence] 在出手那刻记下（[constant CycleCadence.FIRED]），晶石表由编译器按顺时针排好
## （[member CompiledItem.loaded]）。**没装晶石 = 木棍**：照 [DealDamage] 原样打（属性的伤害、自己的类型）。
## 晶石的供给次数仍按场扣（148），战斗中不会碎，所以轮读的序列一场内不变
class_name FireLoaded
extends DealDamage


func apply(ctx: RuleContext) -> void:
	var entry := current(ctx)
	if entry.is_empty():
		deal(ctx, damage_type, 0)
		return
	deal(ctx, StringName(entry.get("type", damage_type)), int(entry.get("damage", 0)))


## 这一下轮到的那颗（没装 = 空）
static func current(ctx: RuleContext) -> Dictionary:
	var loaded := ctx.owner.loaded_of(ctx.source_uid())
	if loaded.is_empty():
		return {}
	var i := int(ctx.state().get(CycleCadence.FIRED, 0))
	return loaded[clampi(i, 0, loaded.size() - 1)]


func describe() -> String:
	return "按顺时针轮流读装载的晶石，打出它的元素伤害；没装晶石时造成%s伤害" % Glossary.damage_type_name(damage_type)
