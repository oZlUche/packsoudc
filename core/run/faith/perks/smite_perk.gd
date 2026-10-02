## 蛮神 3 级（093）：消耗体力秒杀精英敌人 —— 战前准备屏多一个按钮
class_name SmitePerk
extends FaithPerk

@export var vitality_cost: int = 1
@export var types: Array[StringName] = [&"elite"]


func prebattle_label(run: RunState, type: StringName) -> String:
	if not types.has(type) or run == null or run.vitality == null:
		return ""
	return "秒杀（耗 %d 体力）" % vitality_cost


func prebattle_apply(run: RunState) -> bool:
	if run == null or run.events.pending_battle.is_empty():
		return false
	var type := StringName(String(run.events.pending_battle.get("type", "battle")))
	if not types.has(type) or run.vitality.current <= vitality_cost:
		return false
	run.vitality.spend(vitality_cost, &"smite")
	return run.events.smite_pending_battle()


func _summary() -> String:
	var names: Array[String] = []
	for t in types:
		names.append(NodeText.label_of(t))
	return "战前准备：耗 %d 体力秒杀%s敌人" % [vitality_cost, "、".join(names)]
