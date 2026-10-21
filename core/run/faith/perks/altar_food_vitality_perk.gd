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
	var altar := AltarModule.of(run)
	var double := altar.perk(&"food_double") if altar != null else null
	if double != null:     # 104 第十节：倍数读那条 perk 的字段，不写死
		amount = roundi(float(amount) * float(double.get("factor")))
	node.content["altar_food_used"] = true
	var got := run.vitality.restore(amount, &"altar")
	return UiText.t("perk.offer_food_done") % got


func _summary() -> String:
	return UiText.t("perk.offer_food_summary") % [per_food, max_per_altar]
