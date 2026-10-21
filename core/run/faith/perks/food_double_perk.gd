## 自然 4 级（093）：食物给予的所有效果翻倍 —— 食物道具的战斗数值 ×2（属性基础值），献祭食物回体力也翻倍（AltarFoodVitalityPerk 读 flags）
class_name FoodDoublePerk
extends FaithPerk

@export var food_tag: StringName = &"food"
@export var factor: float = 2.0


func compile_into(input: CompileInput, _board: GridInventory, _run: RunState) -> void:
	# 101 第 5 刀：原来还往 spec.flags 写一份 factor，没人读 —— 献祭食物回体力翻倍是
	# [AltarFoodVitalityPerk] 自己查这条 perk 在不在（`altar.perk(&"food_double")`）
	var scope := ScopedMod.new()
	scope.tags = [food_tag] as Array[StringName]
	scope.base_scale = factor
	# 急速每件都是 1.0，翻倍就成了二倍速 —— 它不是「食物给的效果」
	scope.base_scale_except = [BattleStats.HASTE] as Array[StringName]
	input.scoped.append(scope)


func _summary() -> String:
	return UiText.t("perk.food_double") % factor
