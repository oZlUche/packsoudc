## 蛮神 2 级（093）：在神坛献祭生命上限，换耐力上限与攻击速度。每做一次：基线生命 −hp_cost、耐力上限 +stamina_gain、所有道具急速 +haste_percent%
class_name AltarSacrificeHpPerk
extends FaithPerk

@export var hp_cost: float = 5.0
@export var stamina_gain: float = 10.0
@export var haste_percent: int = 5
## 生命上限至少留这么多（基线里的数）
@export var min_hp_left: float = 5.0
const KEY := "sacrifice_hp"


func altar_label() -> String:
	return "献祭生命上限（−%.0f 生命 → +%.0f 耐力上限、+%d%% 急速）" % [hp_cost, stamina_gain, haste_percent]


func altar_available(run: RunState, _node: MapNode) -> String:
	var base := run.effective_baseline() if run != null else null
	var hp := base.value_of(BattleStats.MAX_HP, 0.0) if base != null else 0.0
	return "" if hp - hp_cost >= min_hp_left else "生命上限不能再低了"


func altar_apply(run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	run.faith_stat_bonus[String(BattleStats.MAX_HP)] = float(run.faith_stat_bonus.get(String(BattleStats.MAX_HP), 0.0)) - hp_cost
	run.faith_stat_bonus[String(BattleStats.MAX_STAMINA)] = float(run.faith_stat_bonus.get(String(BattleStats.MAX_STAMINA), 0.0)) + stamina_gain
	run.faith_rituals[KEY] = int(run.faith_rituals.get(KEY, 0)) + 1
	return "向蛮神献祭了 %.0f 点生命上限：耐力上限 +%.0f，急速 +%d%%（第 %d 次）" % [hp_cost, stamina_gain, haste_percent, int(run.faith_rituals[KEY])]


func modify_spec(spec: CombatantSpec, _board: GridInventory, run: RunState) -> void:
	var n := int(run.faith_rituals.get(KEY, 0)) if run != null else 0
	if n <= 0 or haste_percent == 0:
		return
	var m := StatModifier.new()
	m.stat = BattleStats.HASTE
	m.mult_category = StatMath.Buff.HASTE
	m.mult_percent = haste_percent * n
	for it in spec.items:
		m.apply_to((it as CompiledItem).stats, 1)


func _summary() -> String:
	return "神坛：献祭 %.0f 生命上限换 +%.0f 耐力上限与 +%d%% 急速，可多次" % [hp_cost, stamina_gain, haste_percent]


## 103：所有道具一起加速 → 通用 buff，献祭过才有
func battle_note(run: RunState) -> String:
	var n := int(run.faith_rituals.get(KEY, 0)) if run != null else 0
	return describe() if n > 0 and haste_percent != 0 else ""
