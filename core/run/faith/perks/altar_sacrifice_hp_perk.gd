## 蛮神 2 级（093；188 补充一作者改成二选一）：在神坛献祭生命上限（每次 −[member hp_cost]，至少留 [member min_hp_left]），换：
## - 「信力」：+[member faith_gain] 信力；
## - 「能力」：这局所有道具造成伤害 +[member damage_percent]%、急速 +[member haste_percent]%（按次数叠）。
## 旧存档里的 `sacrifice_hp` 次数当成「能力」次数（当时给过的耐力上限留在 `stat_bonus` 里不动）
class_name AltarSacrificeHpPerk
extends FaithPerk

@export var hp_cost: float = 5.0
@export var faith_gain: int = 20
@export var damage_percent: int = 5
@export var haste_percent: int = 5
## 生命上限至少留这么多（基线里的数）
@export var min_hp_left: float = 5.0
const FAITH := &"faith"
const BUFF := &"buff"
const KEY_BUFF := "sacrifice_hp_buff"
const KEY_FAITH := "sacrifice_hp_faith"
## 188 之前的次数（换的是耐力上限与急速）
const KEY_OLD := "sacrifice_hp"


func altar_label() -> String:
	return UiText.t("perk.sacrifice_label") % hp_cost


func altar_options() -> Array[StringName]:
	return [FAITH, BUFF] as Array[StringName]


func altar_option_label(option: StringName) -> String:
	if option == FAITH:
		return UiText.t("perk.sacrifice_opt_faith") % faith_gain
	return UiText.t("perk.sacrifice_opt_buff") % [damage_percent, haste_percent]


func altar_available(run: RunState, _node: MapNode) -> String:
	var base := run.effective_baseline() if run != null else null
	var hp := base.value_of(BattleStats.MAX_HP, 0.0) if base != null else 0.0
	return "" if hp - hp_cost >= min_hp_left else UiText.t("perk.sacrifice_floor")


func altar_apply(run: RunState, _node: MapNode, option: StringName = &"") -> String:
	var altar := AltarModule.of(run)
	if altar == null:
		return ""
	var def := run.active_faith()
	var pick := option if option == FAITH else BUFF
	altar.stat_bonus[String(BattleStats.MAX_HP)] = float(altar.stat_bonus.get(String(BattleStats.MAX_HP), 0.0)) - hp_cost
	if pick == FAITH:
		altar.rituals[KEY_FAITH] = int(altar.rituals.get(KEY_FAITH, 0)) + 1
		if def != null:
			run.faith_power.add_points(def.id, faith_gain)
		return UiText.t("perk.sacrifice_done_faith") % [hp_cost, faith_gain]
	altar.rituals[KEY_BUFF] = int(altar.rituals.get(KEY_BUFF, 0)) + 1
	var n := buff_times(run)
	return UiText.t("perk.sacrifice_done_buff") % [hp_cost, damage_percent, haste_percent, n]


## 选「能力」的次数（含 188 之前的老次数）
static func buff_times(run: RunState) -> int:
	var r := AltarModule.rituals_of(run)
	return int(r.get(KEY_BUFF, 0)) + int(r.get(KEY_OLD, 0))


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	var n := buff_times(run)
	if n <= 0:
		return
	# 不筛 = 每一件参战道具（和 input.mods 的语义一致）
	if damage_percent != 0:
		input.mods.append(StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, float(damage_percent * n)))
	if haste_percent != 0:
		input.mods.append(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, float(haste_percent * n)))


func _summary() -> String:
	return UiText.t("perk.sacrifice_summary")


## 103：所有道具一起加成 → 通用 buff，选过「能力」才有
func battle_note(run: RunState) -> String:
	var n := buff_times(run)
	return UiText.t("perk.sacrifice_note") % [damage_percent * n, haste_percent * n] if n > 0 else ""
