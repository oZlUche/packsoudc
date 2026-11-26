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
const STONE := &"god_earth_stone"
const STONE_UP := &"god_earth_stone_up"
const ECHO := &"god_earth_echo"
const ECHO_UP := &"god_earth_echo_up"
## 基础牌
const GROUNDED := &"god_earth_grounded"
const VITAL := &"god_earth_vital"
const STRIVE := &"god_earth_strive"
const DIG := &"god_earth_dig"
const SELECT := &"god_earth_select"
const GEM := &"god_earth_gem"
## 甄选摆出来的三张（不进牌池，牌面写那件道具）
const SELECT_SLOTS: Array[StringName] = [&"god_earth_select_0", &"god_earth_select_1", &"god_earth_select_2"]
const SELECT_KEY := "earth_select"
const SELECT_OFFER := "earth_select_offer"
## 大地共鸣：多翻到的那件按稀有度给几点经验值（普通 → 传说）
const ECHO_XP: Array[int] = [1, 2, 4, 8, 16]
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
	# 基石：按种类与稀有度的增益（防具的护甲在 [method effect_for]，魔法材料的经验在 [method xp_pct]）
	var sb := stone_bonus(lv, board)
	if float(sb["damage"]) > 0.0:
		input.mods.append(StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, float(sb["damage"])))
	if float(sb["haste"]) > 0.0:
		input.mods.append(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, float(sb["haste"])))
	if float(sb["hp"]) > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_HP, StatModifier.Mode.ADD, float(sb["hp"])))
	if float(sb["stamina"]) > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_STAMINA, StatModifier.Mode.ADD, float(sb["stamina"])))
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
	e.armor_gain += roundi(float(stone_bonus(lv, board)["armor"]))
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
## 另加基石里魔法材料的经验加成
static func xp_pct(lv: LevelModule) -> float:
	if lv == null or lv.god() != &"earth":
		return 0.0
	var stone := float(stone_bonus(lv, lv.run_state().board if lv.run_state() != null else null)["xp"])
	if not lv.has_card(MYRIAD):
		return stone
	var pct := _pick(lv, MYRIAD, MYRIAD_UP, "pct", 10.0) * _types_seen(lv)
	if lv.has_card(MYRIAD_UP) and lv.level() >= lv.rules().level_cap:
		pct *= 0.5
	return pct + stone


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
	if lv.has_card(STONE) and run.board != null:
		var made := _make_stone(run, node)
		if made != null:
			lines.append(UiText.t("perk.earth_stone") % Names.of(made.def))
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


#region 基石
## 基石：随机一件还不是基石的大地成为基石（锁在棋盘上）。没有大地 = null
static func _make_stone(run: RunState, node: MapNode) -> ItemInstance:
	var pool: Array[int] = []
	var got := EarthHeaven.roles(run.board)
	for uid in EarthHeaven.uids_of(got, EarthHeaven.GROUND):
		if not run.board.get_item(uid).is_stone():
			pool.append(uid)
	if pool.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.run_seed, node.id if node != null else 0, "earth_stone"])
	var inst := run.board.get_item(pool[rng.randi_range(0, pool.size() - 1)])
	inst.set_stone(true)
	run.board.changed.emit()
	return inst


## 基石是哪一种（作者备注：武器 / 防具 / 饰品 / 自然、工艺、魔法材料）；都不是 = 空
static func stone_kind(def: ItemDef) -> String:
	if def == null:
		return ""
	if def.has_tag(&"weapon") or def.has_tag(&"staff"):
		return "weapon"
	if def.has_tag(&"armor") or def.has_tag(&"shield"):
		return "armor"
	if def.has_tag(&"trinket"):
		return "trinket"
	if SearchSession.is_material(def):
		if def.has_tag(&"magic") or def.has_tag(&"crystal"):
			return "magic"
		if def.has_tag(&"crafted"):
			return "crafted"
		if def.has_tag(&"nature"):
			return "nature"
	return ""


## 棋盘上所有基石合起来的增益：{damage 增伤%, armor 开战护甲, haste 急速%, hp 生命上限, stamina 耐力上限, xp 经验%}；
## 每件 = 这一种的数 ×（稀有度 + 1），升级版翻倍
static func stone_bonus(lv: LevelModule, board: GridInventory) -> Dictionary:
	var out := {"damage": 0.0, "armor": 0.0, "haste": 0.0, "hp": 0.0, "stamina": 0.0, "xp": 0.0}
	if lv == null or board == null or not lv.has_card(STONE):
		return out
	var src := STONE_UP if lv.has_card(STONE_UP) else STONE
	var keys := {"weapon": "damage", "armor": "armor", "trinket": "haste", "nature": "hp", "crafted": "stamina", "magic": "xp"}
	for raw in board.items():
		var inst := raw as ItemInstance
		if not inst.is_stone():
			continue
		var kind := stone_kind(inst.def)
		if kind == "":
			continue
		var per := lv.card_value(src, kind, 0.0) * lv.card_value(src, "mult", 1.0)
		out[keys[kind]] = float(out[keys[kind]]) + per * (inst.rarity() + 1)
	return out
#endregion


#region 拿牌那一下（宝石化、发掘、甄选）与搜索（大地共鸣）
## [LevelModule] 拿到一张大地之神的牌时调
static func on_pick(lv: LevelModule, cid: StringName) -> void:
	var run := lv.run_state()
	if run == null:
		return
	match cid:
		GEM:
			_gem(lv, run)
		DIG:
			_dig(lv, run)
		SELECT:
			_roll_select(lv, run)


## 宝石化：随机一件道具价值和重量翻倍，先挑支柱（不是大地也不是穹顶的）；同一件可以再翻
static func _gem(lv: LevelModule, run: RunState) -> void:
	if run.board == null:
		return
	var got := EarthHeaven.roles(run.board)
	var pool := EarthHeaven.uids_of(got, EarthHeaven.PILLAR)
	if pool.is_empty():
		for uid in got:
			pool.append(int(uid))
		pool.sort()
	if pool.is_empty():
		return
	var rng := NatureGifts.rng_for(run, "earth_gem")
	var inst := run.board.get_item(pool[rng.randi_range(0, pool.size() - 1)])
	inst.state["value"] = ItemValue.of_instance(inst) * 2
	inst.state[ItemWeight.WEIGHT_MULT_KEY] = float(inst.state.get(ItemWeight.WEIGHT_MULT_KEY, 1.0)) * 2.0
	lv.god_state["earth_gem_last"] = String(inst.def.id)
	run.board.changed.emit()
	run.refresh_encumbrance()


## 发掘：当场搜一次（不会遇敌）：按这一局的材料倾向只出那一系的材料（没有倾向就是普通搜索），放进背包，放不下放地上
static func _dig(lv: LevelModule, run: RunState) -> void:
	var ev := run.events
	if ev == null or ev.rules == null or ev.rules.search == null or run.items == null:
		return
	var node := run.current_node() if run.map != null and run.travel != null else null
	var rng := NatureGifts.rng_for(run, "earth_dig")
	var only := MaterialBias.tags_of(run.material_bias)
	var ids := SearchSession.draw_items(ev.rules.search, run.items, ev._depth_of(node) if node != null else 0.0,
		node.danger if node != null else 0, rng, -1, [], node.produce if node != null else {}, only, 0.0)
	var names: PackedStringArray = []
	for id in ids:
		var d := run.items.get_def(id)
		if NatureGifts.give(run, d) != null:
			names.append(Names.of(d))
	lv.god_state["earth_dig_last"] = ", ".join(names)


## 甄选：抽三件稀有度至少【稀有】的材料（不重样），等着三选一
static func _roll_select(lv: LevelModule, run: RunState) -> void:
	var pool: Array[StringName] = []
	for id in run.items.ids():
		var d := run.items.get_def(id)
		if d != null and SearchSession.is_material(d) and d.rarity >= 2 and not d.is_bag and not d.is_unique():
			pool.append(id)
	pool.sort()
	if pool.is_empty():
		return
	var rng := NatureGifts.rng_for(run, "earth_select")
	var picks: Array = []
	while picks.size() < SELECT_SLOTS.size() and not pool.is_empty():
		var at := rng.randi_range(0, pool.size() - 1)
		picks.append(String(pool[at]))
		pool.remove_at(at)
	lv.god_state[SELECT_KEY] = picks
	lv.level_changed.emit()


## 甄选等着选
static func select_due(lv: LevelModule) -> bool:
	return lv != null and lv.god_state.get(SELECT_KEY, []) is Array and not (lv.god_state.get(SELECT_KEY, []) as Array).is_empty()


## 选牌窗正摆着甄选的三件
static func select_offer(lv: LevelModule) -> bool:
	return lv != null and bool(lv.god_state.get(SELECT_OFFER, false)) and not lv.offer_ids.is_empty()


## 摆出来的那几张（几件就几张）
static func select_cards(lv: LevelModule) -> Array[String]:
	var out: Array[String] = []
	var picks: Array = lv.god_state.get(SELECT_KEY, [])
	for i in mini(picks.size(), SELECT_SLOTS.size()):
		out.append(String(SELECT_SLOTS[i]))
	return out


## 第 [param i] 张那件道具（没有 null）
static func select_item(lv: LevelModule, cid: StringName) -> ItemDef:
	var i := SELECT_SLOTS.find(cid)
	var picks: Array = lv.god_state.get(SELECT_KEY, [])
	var run := lv.run_state()
	if i < 0 or i >= picks.size() or run == null or run.items == null:
		return null
	return run.items.get_def(StringName(String(picks[i])))


## 挑了 [param cid]：给那件道具（放进背包，放不下放地上）
static func select_choose(lv: LevelModule, cid: StringName) -> void:
	var d := select_item(lv, cid)
	lv.god_state.erase(SELECT_KEY)
	lv.god_state.erase(SELECT_OFFER)
	if d != null:
		NatureGifts.give(lv.run_state(), d)


## 牌面：那件道具的名字和稀有度
static func select_text(lv: LevelModule, cid: StringName) -> String:
	var d := select_item(lv, cid)
	if d == null:
		return ""
	return UiText.t("level.earth_select_item") % [Names.of(d), UiText.t("tip.rarity_%d" % d.rarity)]


## 大地共鸣：材料节点每搜一次多翻一件（升级两件），翻到的按稀有度给经验值
static func on_search(lv: LevelModule, session: SearchSession) -> void:
	if lv == null or session == null or lv.god() != &"earth" or not lv.has_card(ECHO) or session.only_tags.is_empty():
		return
	session.bonus_items = roundi(_pick(lv, ECHO, ECHO_UP, "n", 1.0))
	session.bonus_cb = func(ids: Array[StringName]) -> void:
		var run := lv.run_state()
		var xp := 0.0
		for id in ids:
			var d := run.items.get_def(id) if run != null and run.items != null else null
			if d != null:
				xp += ECHO_XP[clampi(d.rarity, 0, ECHO_XP.size() - 1)]
		if xp > 0.0:
			lv.gain(xp, LevelModule.SRC_FAITH, "earth_echo")
#endregion


func _summary() -> String:
	return UiText.t("perk.earth_heaven")


## 作用于角色本身 → 进 buff 栏
func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
