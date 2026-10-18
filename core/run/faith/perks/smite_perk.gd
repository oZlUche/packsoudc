## 蛮神 3 级（093；188 补充一作者改写）：消耗 [member vitality_cost] 体力或 [member faith_cost] 信力，立即击败非首领敌人 —— 战前准备屏两个按钮
class_name SmitePerk
extends FaithPerk

@export var vitality_cost: int = 1
@export var faith_cost: int = 30
## 哪些点能用（核心 = 首领，不在里面）
@export var types: Array[StringName] = [&"battle", &"elite"]
const VITALITY := &"vitality"
const FAITH := &"faith"


func prebattle_actions(run: RunState, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not types.has(type) or run == null or run.vitality == null:
		return out
	out.append({"option": VITALITY, "label": "立即击败（耗 %d 体力）" % vitality_cost,
		"why": "" if run.vitality.current > vitality_cost else "体力不够（要留 1 点）"})
	out.append({"option": FAITH, "label": "立即击败（耗 %d 信力）" % faith_cost,
		"why": "" if FaithPerk.points_now(run) >= faith_cost else "信力不够（要 %d）" % faith_cost})
	return out


func prebattle_apply(run: RunState, option: StringName = VITALITY) -> bool:
	if run == null or run.events.pending_battle.is_empty():
		return false
	var type := StringName(String(run.events.pending_battle.get("type", "battle")))
	for a in prebattle_actions(run, type):
		if a["option"] != option:
			continue
		if String(a["why"]) != "":
			return false
		if option == FAITH:
			run.faith_power.spend_points(run.active_faith_id(), faith_cost)
		else:
			run.vitality.spend(vitality_cost, &"smite")
		return run.events.smite_pending_battle()
	return false


func _summary() -> String:
	return "可消耗 %d 体力或 %d 信力立即击败非首领敌人" % [vitality_cost, faith_cost]
