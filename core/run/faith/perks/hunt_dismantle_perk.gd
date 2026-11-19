## 信仰重构 C（交接方案 §6.6）：狩猎之神的战斗机制 —— 奉神即有（tier 0），按开战时的阶决定开到哪一档。
## 信仰窗一阶一行：[member part] 0 = 基础（只有它编译），1、2 = 那一阶多的那句，3 = 战利品偏向（[method modify_loot]）。
## 标记目前按对手的本事自动挑（推荐的那个）；战前手动换标记等战前屏的样张（报告 331 §差异）
class_name HuntDismantlePerk
extends FaithPerk

@export var part: int = 0
@export var point_gap_sec: float = 1.0
@export var stage1: int = 3
@export var stage2: int = 6
@export var weaken1: int = 10
@export var weaken2: int = 20
@export var exposed1: int = 5
@export var exposed2: int = 10
## 三阶：拆完第二档并打赢，这一场的珍宝往兽材 / 素材偏（[member LootContext.category_bias]，换掉一份普通的，不多给一件）
@export var loot_bias: int = 20


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	input.rules.append(rule_at(maxi(0, run.active_faith_tier()) if run != null else 0))


func rule_at(at_tier: int) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BATTLE_START, BattleEvent.DAMAGE] as Array[StringName]
	var eff := HuntDismantle.new()
	eff.tier = at_tier
	eff.point_gap_sec = point_gap_sec
	eff.stage1 = stage1
	eff.stage2 = stage2
	eff.weaken1 = weaken1
	eff.weaken2 = weaken2
	eff.exposed1 = exposed1
	eff.exposed2 = exposed2
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	rule.effects.append(eff)
	return rule


func modify_loot(ctx: LootContext, _node_type: StringName) -> void:
	if part != 3 or int(ctx.battle_notes.get("hunt_stage2", 0)) <= 0:
		return
	for tag in [&"beast_part", &"material"]:
		ctx.category_bias[tag] = int(ctx.category_bias.get(tag, 0)) + loot_bias


func _summary() -> String:
	match part:
		1:
			return UiText.t("perk.hunt_1") % [stage1, weaken1, exposed1]
		2:
			return UiText.t("perk.hunt_2") % [stage2, weaken2, exposed2]
		3:
			return UiText.t("perk.hunt_3")
	return UiText.t("perk.hunt") % [TextTemplate.num(point_gap_sec), stage1]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
