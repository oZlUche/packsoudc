## 388 第 3 批：自然之神的战斗机制 —— 奉神即有【枯萎】/【新生】（核心的数在这里，作者表顶上那一行），
## 自然之神的牌拿了几张就把数填进 [NatureCycle]。牌的数在各自的 `run_buffs/god_nature_*.json`（[GodCard]）。
## 战后结算（生长、丰饶升级）由 [LevelModule] 读这一场最后的层数，攒进 [member LevelModule.god_state]，[method run_bonus] 给整局的生命上限
class_name NatureCyclePerk
extends FaithPerk

## 旧内容还写着 part：只有 0 编译
@export var part: int = 0
@export var heal_mark: int = 10

const DECAY := &"god_nature_decay"
const DECAY_UP := &"god_nature_decay_up"
const GROW := &"god_nature_grow"
const GROW_UP := &"god_nature_grow_up"
const GUARD := &"god_nature_guard"
const GUARD_UP := &"god_nature_guard_up"
const REAP := &"god_nature_reap"
const REAP_UP := &"god_nature_reap_up"
const BOUNTY := &"god_nature_bounty"
const BOUNTY_UP := &"god_nature_bounty_up"
const CYCLE := &"god_nature_cycle"
const CYCLE_UP := &"god_nature_cycle_up"
const REJUV := &"god_nature_rejuv"
const POISON := &"god_nature_poison"
const FOOD := &"god_nature_food"
const HERB := &"god_nature_herb"
const SURVIVE := &"god_nature_survive"
## 战后攒下的整局生命上限
const HP_KEY := "nature_hp"


func compile_into(input: CompileInput, board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	var lv := LevelModule.of(run)
	input.rules.append(rule_for(lv))
	if lv == null:
		return
	# 食补 / 药补：开战时按棋盘上的格子数加上限
	var food := lv.god_value(FOOD, "hp")
	var herb := lv.god_value(HERB, "stamina")
	if food > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_HP, StatModifier.Mode.ADD, food * cells_of(board, [&"food", &"ingredient"])))
	if herb > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_STAMINA, StatModifier.Mode.ADD, herb * cells_of(board, [&"remedy"])))


## 棋盘上带这些标签的道具一共几格（包、不参战、休眠的不算）
static func cells_of(board: GridInventory, tags: Array[StringName]) -> int:
	if board == null:
		return 0
	var n := 0
	var tag := FaithState.board_tag(board)
	for raw in board.items():
		var inst := raw as ItemInstance
		if inst.def != null and tags.any(func(t: StringName) -> bool: return inst.def.tags.has(t)) and EarthSupport.counts(board, inst, tag):
			n += inst.def.cell_count()
	return n


func rule_for(lv: LevelModule) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.DAMAGE, BattleEvent.RESOURCE_CHANGED] as Array[StringName]
	trig.pulse = true
	var cad := FaithPulseCadence.new()
	cad.every_sec = NatureCycle.STEP
	cad.first_sec = NatureCycle.STEP
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = cad
	rule.effects.append(effect_for(lv))
	return rule


func effect_for(lv: LevelModule) -> NatureCycle:
	var e := NatureCycle.new()
	e.heal_mark = heal_mark
	if lv == null:
		return e
	if lv.has_card(DECAY):
		e.decay_percent = lv.god_value(DECAY_UP if lv.has_card(DECAY_UP) else DECAY, "pct")
	if lv.has_card(CYCLE):
		var src := CYCLE_UP if lv.has_card(CYCLE_UP) else CYCLE
		e.cycle_every = roundi(lv.god_value(src, "every", 5.0))
		e.cycle_stacks = roundi(lv.god_value(src, "stacks"))
	if lv.has_card(GUARD):
		var g := GUARD_UP if lv.has_card(GUARD_UP) else GUARD
		e.guard_every = lv.god_value(g, "sec")
		e.guard_percent = lv.god_value(g, "pct")
	if lv.has_card(REAP):
		var r := REAP_UP if lv.has_card(REAP_UP) else REAP
		e.harvest_at = lv.god_value(r, "sec")
		e.harvest_percent = lv.god_value(r, "pct")
	e.bounty = lv.has_card(BOUNTY)
	e.rejuv = roundi(lv.god_value(REJUV, "stacks"))
	e.poison = roundi(lv.god_value(POISON, "stacks"))
	if lv.has_card(SURVIVE):
		e.survive_percent = lv.god_value(SURVIVE, "pct")
	return e


## 打完一场（[param result] 的最后一刻）：生长按新生、丰饶升级按丰饶，加进整局生命上限
static func settle(lv: LevelModule, result: BattleResult) -> float:
	if lv == null or result == null or result.final.is_empty():
		return 0.0
	var me: Dictionary = (result.final.get("sides", [{}, {}]) as Array)[0]
	var buffs: Dictionary = me.get("buffs", {})
	var add := 0.0
	if lv.has_card(GROW):
		add += float(buffs.get(String(NatureCycle.RENEWAL), 0)) * lv.god_value(GROW_UP if lv.has_card(GROW_UP) else GROW, "pct") / 100.0
	if lv.has_card(BOUNTY_UP):
		add += float(buffs.get(String(NatureCycle.BOUNTY), 0)) * lv.god_value(BOUNTY_UP, "keep") / 100.0
	if add > 0.0:
		lv.god_state[HP_KEY] = float(lv.god_state.get(HP_KEY, 0.0)) + add
	return add


## 整局的加成（[method RunState.effective_baseline] 读）
static func run_bonus(lv: LevelModule) -> Dictionary:
	if lv == null:
		return {}
	var hp := float(lv.god_state.get(HP_KEY, 0.0))
	return {&"max_hp": hp} if hp > 0.0 else {}


func _summary() -> String:
	return UiText.t("perk.nature_cycle")


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
