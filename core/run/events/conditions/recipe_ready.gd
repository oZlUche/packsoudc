## 条件：身上凑得齐某条局内配方（[RecipeDef]）的原料 —— 每种原料都有一件玩家没锁的（报告 309 / v5.85 体验 E01）。
## [member missing] 反过来：凑不齐才过。序章守卫的退路用它：手里只有赐福的匕首、或者缺毒药，都算「当前没有可用的合成组合」，
## 不再说「没有匕首」。精确匹配原料 id，和 [method RecipeDef.matches] 一样 —— 赐福版不顶普通版
class_name RecipeReady
extends EventCondition

@export var recipe: StringName = &""
@export var missing: bool = false


func check(ctx: EventContext) -> bool:
	return ready(ctx) != missing


func ready(ctx: EventContext) -> bool:
	var def := RecipeReady.find(recipe)
	if def == null or ctx == null:
		return false
	var need := {}
	for id in def.inputs:
		need[id] = int(need.get(id, 0)) + 1
	for id in need:
		var n := 0
		for c in ctx.containers(2):
			for inst in (c as ItemContainer).items():
				var ii := inst as ItemInstance
				if ii.def.id == id and not ii.is_locked_by_player():
					n += 1
		if n < int(need[id]):
			return false
	return true


static func find(p_id: StringName) -> RecipeDef:
	for r in RecipeDef.load_all():
		if (r as RecipeDef).id == p_id:
			return r
	return null


func describe() -> String:
	return UiText.t("cond.recipe_missing") if not missing else UiText.t("cond.recipe_ready")
