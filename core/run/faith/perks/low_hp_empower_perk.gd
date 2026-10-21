## 蛮神 1 级（093；188 补充一作者改成门槛式）：生命低于 [member hp_percent]% 时造成的伤害 +X%，X 随信力
## （[member base_percent] + （信力 / [member step] 取整） × [member per]，不超过 [member max_percent]）。开战时的信力定一场 —— 给玩家挂一条「本方造成伤害前 · 一直 · 低血增伤」规则
class_name LowHpEmpowerPerk
extends FaithPerk

@export var hp_percent: int = 30
@export var base_percent: int = 10
@export var step: int = 50
@export var per: int = 5
@export var max_percent: int = 50


## 有 [param points] 信力时加几成
func percent_at(points: int) -> int:
	return int(FaithPerk.scaled(points, base_percent, step, per, max_percent))


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	var rule := AbilityRule.new()
	var trig := EffectRegistry.instantiate(&"trigger", &"on_before_damage")
	if trig != null:
		trig.set("direction", 1)     # DamageTrigger.Direction.DEALT
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	var eff := LowHpEmpower.new()
	eff.hp_percent = hp_percent
	eff.percent = percent_at(FaithPerk.points_now(run))
	rule.effects.append(eff)
	input.rules.append(rule)


func _summary() -> String:
	return summary_for(null, 0)


func summary_for(_def: FaithDef, points: int) -> String:
	return UiText.t("perk.low_hp") % [hp_percent, percent_at(points)]


## 103：作用于角色本身 → 进 buff 栏
func battle_note(run: RunState) -> String:
	return summary_for(null, FaithPerk.points_now(run))
