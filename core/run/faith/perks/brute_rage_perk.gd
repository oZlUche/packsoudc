## 信仰重构 D（交接方案 §6.1）：蛮神的战斗机制 —— 奉神即有（tier 0），按开战时的阶决定开到哪一层。
## 信仰窗一阶一行：[member part] 0 = 基础（只有它编译），1～3 = 那一阶多出来的那句。三阶的不屈走 [method CompileInput.keep_undying]
class_name BruteRagePerk
extends FaithPerk

@export var part: int = 0
@export var percent_per_stack: int = 5
@export var cap: int = 5
@export var damage_per: int = 6
@export var pen_at: int = 3
@export var low_percent: int = 35
@export var low_bonus: int = 50
## 三阶：一场一次，生命归零后还能坚持几秒
@export var undying_sec: float = 3.0


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	compile_at(input, maxi(0, run.active_faith_tier()) if run != null else 0)


## 按 [param at_tier] 阶编进去（测试直接拿）：规则一条，三阶再加不屈
func compile_at(input: CompileInput, at_tier: int) -> void:
	input.rules.append(rule_at(at_tier))
	if at_tier >= 3 and undying_sec > 0.0:
		input.keep_undying(undying_sec)


## [param at_tier] 阶的那条规则（测试与台架直接拿）
func rule_at(at_tier: int) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BEFORE_DAMAGE, BattleEvent.DAMAGE] as Array[StringName]
	var eff := BruteRage.new()
	eff.tier = at_tier
	eff.percent_per_stack = percent_per_stack
	eff.cap = cap
	eff.damage_per = damage_per
	eff.pen_at = pen_at
	eff.low_percent = low_percent
	eff.low_bonus = low_bonus
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	rule.effects.append(eff)
	return rule


func _summary() -> String:
	match part:
		1:
			return UiText.t("perk.brute_rage_1") % pen_at
		2:
			return UiText.t("perk.brute_rage_2") % [low_percent, low_bonus]
		3:
			return UiText.t("perk.brute_rage_3") % TextTemplate.num(undying_sec)
	return UiText.t("perk.brute_rage") % [percent_per_stack, cap, damage_per]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 or part == 3 else ""
