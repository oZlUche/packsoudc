## 信仰重构 D（交接方案 §6.3）：自然之神的战斗机制 —— 奉神即有（tier 0），按开战时的阶决定开到哪一层。
## 信仰窗一阶一行：[member part] 0 = 基础（只有它编译），1～3 = 那一阶多出来的那句。二阶的食物件数编译时按棋盘数
class_name NatureRegrowthPerk
extends FaithPerk

@export var part: int = 0
@export var pulse_sec: float = 6.0
@export var pulse_percent: int = 2
@export var store_percent: int = 20
@export var cap_percent: int = 15
@export var low_percent: int = 50
@export var release_gap_sec: float = 6.0
@export var food_percent: int = 2
@export var food_cap: int = 3
@export var heal_mark: int = 10
## 三阶：进加时的短时减伤（buff `nature_guard` 自己定时长与轴），这里只写说明用
@export var guard_sec: float = 3.0


func compile_into(input: CompileInput, board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	input.rules.append(rule_at(maxi(0, run.active_faith_tier()) if run != null else 0, food_on(board)))


## 棋盘上有效的食物几件（包、不参战、整件休眠的不算）
static func food_on(board: GridInventory) -> int:
	if board == null:
		return 0
	var n := 0
	var tag := FaithState.board_tag(board)
	for raw in board.items():
		var inst := raw as ItemInstance
		if inst.def != null and inst.def.tags.has(&"food") and EarthSupport.counts(board, inst, tag):
			n += 1
	return n


func rule_at(at_tier: int, food: int = 0) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.RESOURCE_CHANGED, BattleEvent.DAMAGE, BattleEvent.OVERTIME_STACKED] as Array[StringName]
	trig.pulse = true
	var cad := FaithPulseCadence.new()
	cad.first_sec = pulse_sec
	cad.every_sec = pulse_sec
	var eff := NatureRegrowth.new()
	eff.tier = at_tier
	eff.pulse_percent = pulse_percent
	eff.store_percent = store_percent
	eff.cap_percent = cap_percent
	eff.low_percent = low_percent
	eff.release_gap_sec = release_gap_sec
	eff.food_percent = food_percent
	eff.food_cap = food_cap
	eff.food = food
	eff.heal_mark = heal_mark
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = cad
	rule.effects.append(eff)
	return rule


func _summary() -> String:
	match part:
		1:
			return UiText.t("perk.nature_regrowth_1") % [low_percent, TextTemplate.num(release_gap_sec)]
		2:
			return UiText.t("perk.nature_regrowth_2") % [food_percent, food_cap]
		3:
			return UiText.t("perk.nature_regrowth_3") % TextTemplate.num(guard_sec)
	return UiText.t("perk.nature_regrowth") % [TextTemplate.num(pulse_sec), pulse_percent, store_percent, cap_percent]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
