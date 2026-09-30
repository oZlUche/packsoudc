## 蛮神 1 级（093）：所有伤害独立乘区，当前生命百分比越低加得越高 —— 给玩家挂一条「本方造成伤害前 · 一直 · 低血增伤」规则
class_name LowHpEmpowerPerk
extends FaithPerk

@export var min_percent: int = 10
@export var max_percent: int = 50


func modify_spec(spec: CombatantSpec, _board: GridInventory, _run: RunState) -> void:
	var rule := AbilityRule.new()
	var trig := EffectRegistry.instantiate(&"trigger", &"on_before_damage")
	if trig != null:
		trig.set("direction", 1)     # DamageTrigger.Direction.DEALT
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	var eff := LowHpEmpower.new()
	eff.min_percent = min_percent
	eff.max_percent = max_percent
	rule.effects.append(eff)
	spec.set_rules.append(rule)


func describe() -> String:
	return note if note != "" else "所有伤害 +%d%%～+%d%%，血越少越高" % [min_percent, max_percent]
