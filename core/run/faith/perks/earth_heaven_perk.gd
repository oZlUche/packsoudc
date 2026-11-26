## 大地之神（作者牌表 11-26「大地之神」）：奉神即有核心【天地】（[EarthHeaven] 按摆放分出大地 / 穹顶 / 支柱），
## 大地之神的牌拿了几张就把数填进 [EarthHeaven]（战斗里的那一半）、编译的入参（轴、属性、按件修饰），
## 地图上的那一半在 [method on_node_entered]（进一个点：苦劳、锻炼、修行、万象、西西弗斯）。
## 牌的数在各自的 `run_buffs/god_earth_*.json`（[GodCard]），这里按牌 id 读；一局里攒下的数记在 [member LevelModule.god_state]
class_name EarthHeavenPerk
extends FaithPerk

const ROCK := &"god_earth_rock"
const ROCK_UP := &"god_earth_rock_up"
const SKY := &"god_earth_sky"
const SKY_UP := &"god_earth_sky_up"
const PILLAR := &"god_earth_pillar"
const PILLAR_UP := &"god_earth_pillar_up"
const LIGHT := &"god_earth_light"
const LIGHT_UP := &"god_earth_light_up"
const TOIL := &"god_earth_toil"
const TOIL_UP := &"god_earth_toil_up"
const TRAIN := &"god_earth_train"
const TRAIN_UP := &"god_earth_train_up"
const PRACTICE := &"god_earth_practice"
const PRACTICE_UP := &"god_earth_practice_up"
const MYRIAD := &"god_earth_myriad"
const MYRIAD_UP := &"god_earth_myriad_up"
## 基础牌
const GROUNDED := &"god_earth_grounded"
const VITAL := &"god_earth_vital"
const STRIVE := &"god_earth_strive"
## 专属牌
const RAM := &"god_earth_ram"
const HEAVY := &"god_earth_heavy"
const THICK := &"god_earth_thick"
const QUAKE := &"god_earth_quake"
const JADE := &"god_earth_jade"
const PILLAR_SKY := &"god_earth_pillar_sky"
const RANGES := &"god_earth_ranges"
const SISYPHUS := &"god_earth_sisyphus"
## 一局里攒的数（[member LevelModule.god_state]）
const TRAIN_HP := "earth_train_hp"
const TRAIN_STAMINA := "earth_train_stamina"
const TYPES_KEY := "earth_types"
const OLD_KEY := "earth_old"
const PRACTICE_DONE := "earth_practice_done"

## 旧内容还写着 part：只有 0 编译
@export var part: int = 0


func compile_into(input: CompileInput, board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	var lv := LevelModule.of(run)
	var rule := rule_for(lv, board, run)
	input.rules.append(rule)
	if lv == null or board == null:
		return
	var got := EarthHeaven.roles(board, true)
	var grounds := EarthHeaven.count_of(got, EarthHeaven.GROUND)
	var domes := EarthHeaven.count_of(got, EarthHeaven.DOME)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([input.seed, "earth_boons"])
	# 支柱：每件支柱开战给几层随机增益（一件抽一种）
	if lv.has_card(PILLAR):
		var per := roundi(_pick(lv, PILLAR, PILLAR_UP, "stacks", 5.0))
		for _uid in EarthHeaven.uids_of(got, EarthHeaven.PILLAR):
			_boon(input, rng, per)
	# 脚踏实地：每件大地开战给 1 层随机增益（拿几张乘几）
	var per_ground := roundi(lv.god_value(GROUNDED, "stacks"))
	if per_ground > 0:
		for _i in grounds * per_ground:
			_boon(input, rng, 1)
	# 生机：大地件数几成的每秒生命恢复
	var vital := lv.god_value(VITAL, "pct")
	if vital > 0.0 and grounds > 0:
		input.baseline_mods.append(StatModifier.make(BattleStats.REGEN_HP, StatModifier.Mode.ADD, grounds * vital / 100.0))
	# 自强不息：每件穹顶增伤
	var strive := lv.god_value(STRIVE, "pct")
	if strive > 0.0 and domes > 0:
		input.mods.append(StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, strive * domes))
	# 锻炼：一局攒下的耐力 / 生命上限
	var hp := floorf(float(lv.god_state.get(TRAIN_HP, 0.0)))
	var st := floorf(float(lv.god_state.get(TRAIN_STAMINA, 0.0)))
	if hp > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_HP, StatModifier.Mode.ADD, hp))
	if st > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_STAMINA, StatModifier.Mode.ADD, st))
	# 西西弗斯：进旧节点攒下的所有属性
	var old := int(lv.god_state.get(OLD_KEY, 0))
	if lv.has_card(SISYPHUS) and old > 0:
		_all_stats(input, lv.god_value(SISYPHUS, "pct", 1.0) * old)
	# 举重若轻：武器越重耐力消耗越低（升级另加急速）
	if lv.has_card(LIGHT):
		var up := lv.has_card(LIGHT_UP)
		var cost := _pick(lv, LIGHT, LIGHT_UP, "cost", 2.0)
		var haste := lv.god_value(LIGHT_UP, "haste") if up else 0.0
		for raw in board.items():
			var inst := raw as ItemInstance
			if inst.def == null or not inst.def.has_tag(&"weapon") or inst.is_benched():
				continue
			var w := ItemWeight.of_in(inst, board)
			if w <= 0:
				continue
			var mods: Array = input.item_mods.get(inst.uid, [])
			mods.append(StatModifier.make(BattleStats.STAMINA_COST, StatModifier.Mode.MULT, -minf(100.0, cost * w)))
			if haste > 0.0:
				mods.append(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, haste * w))
			input.item_mods[inst.uid] = mods


## 有升级拿升级版的数，没有拿原牌的
static func _pick(lv: LevelModule, base: StringName, up: StringName, key: String, fallback: float = 0.0) -> float:
	return lv.god_value(up if lv.has_card(up) else base, key, fallback)


## 一种随机增益（标准轴的有利方向，和自然之神【枯荣】同一张表）加 [param stacks] 层
static func _boon(input: CompileInput, rng: RandomNumberGenerator, stacks: int) -> void:
	if stacks <= 0:
		return
	var keys: Array = NatureCyclePerk.BENEFIT.keys()
	var k: StringName = keys[rng.randi_range(0, keys.size() - 1)]
	input.shift_axis(k, int(NatureCyclePerk.BENEFIT[k]) * stacks)


## 所有属性 +[param pct]%（伤害、急速、暴击给每件道具；生命、耐力上限与回复给基线）
static func _all_stats(input: CompileInput, pct: float) -> void:
	for m in BattleStats.all_stats_mods(pct):
		if m.stat in [BattleStats.DAMAGE, BattleStats.HASTE, BattleStats.CRIT_CHANCE, BattleStats.CRIT_DAMAGE]:
			input.mods.append(m)
		else:
			input.baseline_mods.append(m)


## 拿着 [param lv] 里这些牌、棋盘这样摆的那条规则（[param lv] 空 = 只有核心；测试与台架直接拿）
func rule_for(lv: LevelModule, board: GridInventory, run: RunState = null) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BATTLE_START, BattleEvent.BEFORE_DAMAGE, BattleEvent.DAMAGE] as Array[StringName]
	trig.sees_pure = lv != null and lv.has_card(RANGES)
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	rule.effects.append(effect_for(lv, board, run))
	return rule


## 核心的数 + 牌的数
static func effect_for(lv: LevelModule, board: GridInventory, run: RunState = null) -> EarthHeaven:
	var e := EarthHeaven.new()
	var got := EarthHeaven.roles(board, true)
	e.ground = EarthHeaven.count_of(got, EarthHeaven.GROUND)
	e.dome = EarthHeaven.count_of(got, EarthHeaven.DOME)
	e.pillar = EarthHeaven.count_of(got, EarthHeaven.PILLAR)
	if lv == null or board == null:
		return e
	if lv.has_card(ROCK):
		var per := _pick(lv, ROCK, ROCK_UP, "armor", 8.0)
		for uid in EarthHeaven.uids_of(got, EarthHeaven.GROUND):
			e.armor_gain += roundi(per * board.get_item(uid).def.cell_count())
	if lv.has_card(SKY):
		var dmg := _pick(lv, SKY, SKY_UP, "damage", 5.0)
		for uid in EarthHeaven.uids_of(got, EarthHeaven.DOME):
			e.sky_true += roundi(dmg * board.get_item(uid).def.cell_count())
	if lv.has_card(RAM):
		e.ram = got.size()
	if lv.has_card(HEAVY):
		e.heavy = run.carry_weight() if run != null else ItemWeight.total(board)
	if lv.has_card(THICK):
		for uid in got:
			e.thick = maxi(e.thick, board.get_item(int(uid)).def.cell_count())
	if lv.has_card(QUAKE):
		e.quake = e.ground
		e.quake_cd = lv.card_value(QUAKE, "cd", 6.0)
	if lv.has_card(JADE):
		for uid in got:
			e.jade = maxi(e.jade, ItemValue.of_in(board.get_item(int(uid)), board))
	if lv.has_card(PILLAR_SKY):
		e.elements = e.pillar
	if lv.has_card(RANGES):
		e.ranges = mini(e.dome, e.ground)
	return e


#region 负重（磐石）
## 磐石：大地的重量多算几成（[method RunState.carry_weight] 加上它）。没奉大地、没拿 = 0
static func extra_weight(run: RunState) -> int:
	if run == null or run.active_faith_id() != &"earth" or run.board == null:
		return 0
	var lv := LevelModule.of(run)
	if lv == null or not lv.has_card(ROCK):
		return 0
	var pct := _pick(lv, ROCK, ROCK_UP, "weight", 50.0)
	var got := EarthHeaven.roles(run.board)
	var sum := 0.0
	for uid in EarthHeaven.uids_of(got, EarthHeaven.GROUND):
		sum += ItemWeight.of_in(run.board.get_item(uid), run.board) * pct / 100.0
	return roundi(sum)
#endregion


#region 经验与金钱（万象）
## 万象：经验值多给百分之几（满级时升级版的经验加成有一半挪去金钱）
static func xp_pct(lv: LevelModule) -> float:
	if lv == null or lv.god() != &"earth" or not lv.has_card(MYRIAD):
		return 0.0
	var pct := _pick(lv, MYRIAD, MYRIAD_UP, "pct", 10.0) * _types_seen(lv)
	if lv.has_card(MYRIAD_UP) and lv.level() >= lv.rules().level_cap:
		pct *= 0.5
	return pct


## 万象：打赢、事件、苦劳的进账多给百分之几（满级时加上挪过来的那一半经验加成）
static func gold_pct(lv: LevelModule) -> float:
	if lv == null or lv.god() != &"earth" or not lv.has_card(MYRIAD):
		return 0.0
	var pct := _pick(lv, MYRIAD, MYRIAD_UP, "pct", 10.0) * _types_seen(lv)
	if lv.has_card(MYRIAD_UP) and lv.level() >= lv.rules().level_cap:
		pct *= 1.5
	return pct


static func _types_seen(lv: LevelModule) -> int:
	var t: Variant = lv.god_state.get(TYPES_KEY, [])
	return (t as Array).size() if t is Array else 0


## 进账的原因里哪几样吃万象（卖东西不算：不然就是倒买倒卖）
const GOLD_REASONS: Array[StringName] = [&"battle", &"event", &"earth"]
#endregion


## 进一个点：记万象的类型；第一次进的点给苦劳、锻炼、修行；进过的点给西西弗斯
func on_node_entered(run: RunState, node: MapNode, first_visit: bool) -> String:
	var lv := LevelModule.of(run)
	if lv == null or node == null or lv.god() != &"earth":
		return ""
	var lines: PackedStringArray = []
	var kind := String(NodeEvents.effective_type(node))
	var seen: Array = (lv.god_state.get(TYPES_KEY, []) as Array).duplicate() if lv.god_state.get(TYPES_KEY, []) is Array else []
	if kind != "" and not seen.has(kind):
		seen.append(kind)
		lv.god_state[TYPES_KEY] = seen
	if not first_visit:
		if lv.has_card(SISYPHUS):
			lv.god_state[OLD_KEY] = int(lv.god_state.get(OLD_KEY, 0)) + 1
			lines.append(UiText.t("perk.earth_sisyphus") % TextTemplate.num(lv.god_value(SISYPHUS, "pct", 1.0) * int(lv.god_state[OLD_KEY])))
		return "\n".join(lines)
	if lv.has_card(TOIL) and run.wallet != null:
		var gold := roundi(run.carry_weight() * _pick(lv, TOIL, TOIL_UP, "pct", 100.0) / 100.0)
		var got := run.wallet.earn(gold, &"earth") if gold > 0 else 0
		if got > 0:
			lines.append(UiText.t("perk.earth_toil") % got)
	if lv.has_card(TRAIN) and run.board != null:
		var grounds := EarthHeaven.count_of(EarthHeaven.roles(run.board), EarthHeaven.GROUND)
		var add := grounds * _pick(lv, TRAIN, TRAIN_UP, "pct", 50.0) / 100.0
		if add > 0.0:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([run.run_seed, node.id, "earth_train"])
			var key := TRAIN_HP if rng.randi_range(0, 1) == 0 else TRAIN_STAMINA
			lv.god_state[key] = float(lv.god_state.get(key, 0.0)) + add
			lines.append(UiText.t("perk.earth_train_hp" if key == TRAIN_HP else "perk.earth_train_stamina") % TextTemplate.num(add))
	if lv.has_card(PRACTICE):
		lines.append_array(_practice(lv, run))
	return "\n".join(lines)


## 修行：负重盈余（上限 − 负重，不到 0 算 0）几成的经验值；升级版满级时这张牌变成一次质变选牌
static func _practice(lv: LevelModule, run: RunState) -> PackedStringArray:
	var out: PackedStringArray = []
	if lv.has_card(PRACTICE_UP) and lv.level() >= lv.rules().level_cap:
		if not bool(lv.god_state.get(PRACTICE_DONE, false)):
			lv.god_state[PRACTICE_DONE] = true
			lv.god_state[LevelModule.SACRIFICE_DUE] = lv.sacrifice_due() + 1
			lv.level_changed.emit()
			out.append(UiText.t("perk.earth_practice_qual"))
		return out
	var spare := maxi(0, run.carry_capacity() - run.carry_weight())
	var xp := spare * _pick(lv, PRACTICE, PRACTICE_UP, "pct", 100.0) / 100.0
	if xp > 0.0:
		var got := lv.gain(xp, LevelModule.SRC_FAITH, "earth_practice")
		if got > 0.0:
			out.append(UiText.t("perk.earth_practice") % roundi(got))
	return out


func _summary() -> String:
	return UiText.t("perk.earth_heaven")


## 作用于角色本身 → 进 buff 栏
func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
