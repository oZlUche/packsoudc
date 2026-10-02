## 自然 4 级（093）：食物给予的所有效果翻倍 —— 食物道具的战斗数值 ×2（属性基础值），献祭食物回体力也翻倍（AltarFoodVitalityPerk 读 flags）
class_name FoodDoublePerk
extends FaithPerk

@export var food_tag: StringName = &"food"
@export var factor: float = 2.0


func modify_spec(spec: CombatantSpec, board: GridInventory, _run: RunState) -> void:
	# 101 第 5 刀：原来还往 spec.flags 写一份 factor，没人读 —— 献祭食物回体力翻倍是
	# [AltarFoodVitalityPerk] 自己查这条 perk 在不在（`altar.perk(&"food_double")`）
	if board == null:
		return
	for it in spec.items:
		var item := it as CompiledItem
		var inst := board.get_item(item.source_uid)
		if inst == null or inst.def == null or not inst.def.tags.has(food_tag):
			continue
		for key in item.stats.keys():
			var v := item.stats.ensure(StringName(String(key)))
			if String(key) != String(BattleStats.HASTE):
				v.base = roundi(float(v.base) * factor)


func _summary() -> String:
	return "食物给的所有效果 ×%.0f（含献祭食物回体力）" % factor
