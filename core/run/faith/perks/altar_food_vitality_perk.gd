## 自然 2 级（093）：在神坛献祭食物道具时恢复体力（每个休息处触发一次）；自然 4 级把它翻倍
class_name AltarFoodVitalityPerk
extends FaithPerk

@export var food_tag: StringName = &"food"
@export var per_food: int = 1
@export var max_per_altar: int = 3


func on_offered(run: RunState, defs: Array, node: MapNode) -> String:
	if run == null or run.vitality == null or node == null or node.content.has("altar_food_used"):
		return ""
	var n := 0
	for d in defs:
		if (d as ItemDef).tags.has(food_tag):
			n += 1
	if n == 0:
		return ""
	var amount := mini(per_food * n, max_per_altar)
	if run.faith_perk(&"food_double") != null:
		amount *= 2
	node.content["altar_food_used"] = true
	var got := run.vitality.restore(amount, &"altar")
	return "献祭食物：体力 +%d" % got


func _summary() -> String:
	return "神坛献祭食物回体力（每件 +%d，每个休息处最多 %d，一次）" % [per_food, max_per_altar]
