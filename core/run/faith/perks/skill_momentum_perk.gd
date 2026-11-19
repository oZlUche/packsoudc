## 信仰重构 C（交接方案 §6.5）：技巧之神的战斗机制 —— 奉神即有（tier 0），按开战时的阶决定开到哪一层。
## 信仰窗一阶一行：同一种效果按 [member part] 写四条（0 = 基础，奉神即有，**只有它编译**；1～3 = 那一阶多出来的那句）。
## 只往 [CompileInput] 放一条单位级规则（[SkillMomentum]），编译仍是纯函数；巧劲本身在模拟里攒、用
class_name SkillMomentumPerk
extends FaithPerk

@export var part: int = 0
@export var window_sec: float = 4.0
@export var cap: int = 2
@export var percent_per: int = 5
@export var opening: int = 1
@export var defense_gap_sec: float = 1.0
@export var combo_percent: int = 30


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	input.rules.append(rule_at(maxi(0, run.active_faith_tier()) if run != null else 0))


## [param at_tier] 阶的那条规则（测试与台架直接拿）
func rule_at(at_tier: int) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BATTLE_START, BattleEvent.BEFORE_DAMAGE, BattleEvent.DAMAGE, BattleEvent.ITEM_FIRED] as Array[StringName]
	var eff := SkillMomentum.new()
	eff.tier = at_tier
	eff.window_sec = window_sec
	eff.cap = cap
	eff.percent_per = percent_per
	eff.opening = opening
	eff.defense_gap_sec = defense_gap_sec
	eff.combo_percent = combo_percent
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	rule.effects.append(eff)
	return rule


func _summary() -> String:
	match part:
		1:
			return UiText.t("perk.skill_momentum_1") % percent_per
		2:
			return UiText.t("perk.skill_momentum_2")
		3:
			return UiText.t("perk.skill_momentum_3") % combo_percent
	return UiText.t("perk.skill_momentum") % [TextTemplate.num(window_sec), cap]


## 作用于角色本身 → 进 buff 栏（只基础那条进，免得一位神占四格）
func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
