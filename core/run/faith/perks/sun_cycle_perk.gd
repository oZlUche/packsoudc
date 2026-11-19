## 信仰重构 D（交接方案 §6.2）：日神的战斗机制 —— 奉神即有（tier 0），按开战时的阶决定开到哪一层。
## 信仰窗一阶一行：[member part] 0 = 基础（只有它编译），1、3 = 那一阶多出来的那句（二阶的「延迟首击」没做，见报告 332）
class_name SunCyclePerk
extends FaithPerk

@export var part: int = 0
@export var first_sec: float = 2.0
@export var every_sec: float = 4.0
@export var window_sec: float = 2.0
@export var fire_percent: int = 20
@export var charge_cap: int = 3
@export var charge_percent: int = 10
@export var strong_every: int = 3
@export var strong_mult: float = 1.5


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	input.rules.append(rule_at(maxi(0, run.active_faith_tier()) if run != null else 0))


func rule_at(at_tier: int) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.ITEM_FIRED, BattleEvent.DAMAGE] as Array[StringName]
	trig.pulse = true
	var cad := FaithPulseCadence.new()
	cad.first_sec = first_sec
	cad.every_sec = window_sec     # 开、关各一拍（窗口长度为一格）
	var eff := SunCycle.new()
	eff.tier = at_tier
	eff.first_sec = first_sec
	eff.every_sec = every_sec
	eff.window_sec = window_sec
	eff.fire_percent = fire_percent
	eff.charge_cap = charge_cap
	eff.charge_percent = charge_percent
	eff.strong_every = strong_every
	eff.strong_mult = strong_mult
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = cad
	rule.effects.append(eff)
	return rule


func _summary() -> String:
	match part:
		1:
			return UiText.t("perk.sun_cycle_1") % [charge_cap, charge_percent]
		3:
			return UiText.t("perk.sun_cycle_3") % [strong_every, TextTemplate.num(strong_mult)]
	return UiText.t("perk.sun_cycle") % [TextTemplate.num(every_sec), TextTemplate.num(window_sec), fire_percent]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
