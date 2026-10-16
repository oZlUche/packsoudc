## 法杖轮读（175 第二批，作者定）：这一下读装载的第几颗晶石，就打它的伤害类型、加它的伤害；
## 补充五：打中了再给对手施加这颗晶石的元素（晶石的第二条供给规则，编译器记进轮读表）。
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
	var landed := deal(ctx, StringName(entry.get("type", damage_type)), int(entry.get("damage", 0)))
	# 175 补充五：这颗晶石的元素是**施加**的，不是伤害类型顺带的 —— 打中了才给对手叠它的那几层（[member CompiledItem.loaded] 的 applies）
	var app: Dictionary = entry.get("applies", {})
	var buff := ReactionResolver.mark_buff(StringName(String(app.get("buff", ""))))
	if landed and buff != null:
		var foe := ctx.opponent()
		if foe != null and not foe.dead:
			ApplyStatus.give(ctx, foe, buff, maxi(1, int(app.get("stacks", 1))))


## 这一下轮到的那颗（没装 = 空）
static func current(ctx: RuleContext) -> Dictionary:
	var loaded := ctx.owner.loaded_of(ctx.source_uid())
	if loaded.is_empty():
		return {}
	var i := int(ctx.state().get(CycleCadence.FIRED, 0))
	return loaded[clampi(i, 0, loaded.size() - 1)]


func describe() -> String:
	return "按顺时针轮流读装载的晶石，打出它的伤害类型、施加它的元素；没装晶石时造成%s伤害" % Glossary.damage_type_name(damage_type)
