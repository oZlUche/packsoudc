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
## B 段（局内的牌）
const WANE := &"god_nature_wane"
const WANE_UP := &"god_nature_wane_up"
const SEED := &"god_nature_seed"
const SEED_STAGES: Array[StringName] = [&"god_nature_seed", &"god_nature_seed_2", &"god_nature_seed_3", &"god_nature_seed_4"]
const SEED_KEEP := &"god_nature_seed_keep"
const SEED_PICK := &"god_nature_seed_pick"
const NEAR := &"god_nature_near"
const NEAR_UP := &"god_nature_near_up"
const BREED := &"god_nature_breed"
const BREED_UP := &"god_nature_breed_up"
const TALK := &"god_nature_talk"
const TALK_UP := &"god_nature_talk_up"
const HARVEST := &"god_nature_harvest"
const HARVEST_UP := &"god_nature_harvest_up"
const HERB_SENSE := &"god_nature_herb_sense"
const FOOD_SENSE := &"god_nature_food_sense"
const TOUGH := &"god_nature_tough"
const SOW := &"god_nature_sow"
## 战后攒下的整局生命上限
const HP_KEY := "nature_hp"
## 枯荣攒下的标准轴（轴 → 带符号的层数，整局开战就有）
const AXES_KEY := "nature_axes"
## 亲近自然：下一场的临时生命上限
const NEAR_KEY := "nature_near"
## 初种：第几阶（0 = 初种）、这一阶攒了几点新生、等着选「继续培育 / 采摘」、选牌窗正摆着这两张
const SEED_STAGE := "seed_stage"
const SEED_PTS := "seed_pts"
const SEED_CHOICE := "seed_choice"
const SEED_OFFER := "seed_offer"
## 动物交谈：战前屏那个按钮
const TALK_OPTION := &"talk"
## 枯荣抽的标准轴，按对自己有利的方向（受到伤害是负的那边才是好的）
const BENEFIT := {
	StatAxes.ATTACK_SPEED: 1, StatAxes.DAMAGE_DEALT: 1, StatAxes.DAMAGE_TAKEN: -1, StatAxes.REGEN_HP: 1, StatAxes.REGEN_HP_PCT: 1,
	StatAxes.REGEN_STAMINA: 1, StatAxes.CRIT_CHANCE: 1, StatAxes.CRIT_DAMAGE: 1, StatAxes.FIRE_DAMAGE: 1, StatAxes.STAMINA_COST: 1,
	StatAxes.BLOCK: 1, StatAxes.MAX_HP: 1,
}
## 非战斗的点（亲近自然）
const CALM_TYPES: Array[StringName] = [&"event", &"search", &"shop", &"rest", &"random"]


func compile_into(input: CompileInput, board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	var lv := LevelModule.of(run)
	var rule := rule_for(lv)
	input.rules.append(rule)
	if lv == null:
		return
	# 【回春】（作者 11-26 09:54）：背包里每 4 格药品或药材，每张再多 1 层（每张自己算，多张相加）
	if lv.has_card(REJUV):
		var per_cells := maxf(1.0, lv.god_value(REJUV, "cells", 4.0) / lv.count_of(REJUV))
		(rule.effects[0] as NatureCycle).rejuv += lv.count_of(REJUV) * floori(cells_of(board, [&"remedy"], true) / per_cells)
	# 食补 / 药补：开战时按棋盘上的格子数加上限
	var food := lv.god_value(FOOD, "hp")
	var herb := lv.god_value(HERB, "stamina")
	if food > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_HP, StatModifier.Mode.ADD, food * cells_of(board, [&"food", &"ingredient"])))
	if herb > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_STAMINA, StatModifier.Mode.ADD, herb * cells_of(board, [&"remedy"], true)))
	# 枯荣：攒下的标准轴开战就有
	var axes: Variant = lv.god_state.get(AXES_KEY, {})
	if axes is Dictionary:
		for k in axes:
			input.shift_axis(StringName(String(k)), int(axes[k]))
	# 亲近自然：下一场的临时生命上限
	var near := float(lv.god_state.get(NEAR_KEY, 0.0))
	if near > 0.0:
		input.baseline_mods.append(StatModifier.make(BattleStats.MAX_HP, StatModifier.Mode.ADD, near))
	# 育种（升级）：长过一阶的种子出手快
	var haste := lv.god_value(BREED_UP, "haste") if lv.has_card(BREED_UP) else 0.0
	if haste > 0.0 and board != null:
		var dormant := FaithState.dormant_uids(board)
		for raw in board.items():
			var inst := raw as ItemInstance
			if inst == null or inst.def == null or not inst.def.has_tag(NatureGifts.SEED_TAG) or dormant.has(inst.uid):
				continue
			if GrowthProfile.stage_of(inst) <= 0:
				continue
			var mods: Array = input.item_mods.get(inst.uid, [])
			mods.append(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, haste))
			input.item_mods[inst.uid] = mods


## 棋盘上带这些标签的道具一共几格（包、不参战、休眠的不算；食材、药材这类没有战斗那一面的也算）；[param herbs] 真 = 药材（草药素材）也算
static func cells_of(board: GridInventory, tags: Array[StringName], herbs: bool = false) -> int:
	if board == null:
		return 0
	var n := 0
	var tag := FaithState.board_tag(board)
	for raw in board.items():
		var inst := raw as ItemInstance
		if inst.def == null:
			continue
		var hit := tags.any(func(t: StringName) -> bool: return inst.def.tags.has(t)) or (herbs and NatureGifts.is_herb(inst.def))
		if hit and not board.acts_as_bag(inst.def) and not inst.is_benched() and not FaithState.is_inert(inst.def, tag):     # 素材、食材没有战斗那一面，也算
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


#region 战后
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
	lv.god_state.erase(NEAR_KEY)     # 亲近自然：这一场用掉了
	var foe: Dictionary = (result.final.get("sides", [{}, {}]) as Array)[1] if (result.final.get("sides", []) as Array).size() > 1 else {}
	_wane(lv, int((foe.get("buffs", {}) as Dictionary).get(String(NatureCycle.WITHER), 0)))
	_harvest(lv, int(buffs.get(String(NatureCycle.RENEWAL), 0)))
	_seed_grow(lv, renewal_gained(result))
	return add


## 这一场一共积了几层新生（护佑清掉的也算）
static func renewal_gained(result: BattleResult) -> int:
	var n := 0
	for raw in result.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and e.get_name(&"buff") == NatureCycle.RENEWAL and e.get_int(&"delta") > 0:
			n += e.get_int(&"delta")
	return n


## 枯荣：敌人枯萎层数的几成是增益点，每 per 点换一层随机标准轴的正向（不足也给一层），整局有效
static func _wane(lv: LevelModule, wither: int) -> void:
	if not lv.has_card(WANE) or wither <= 0:
		return
	var src := WANE_UP if lv.has_card(WANE_UP) else WANE
	var pts := wither * lv.god_value(src, "pct") / 100.0
	if pts <= 0.0:
		return
	var per := maxf(1.0, lv.card_value(WANE, "per", 20.0))
	var stacks := maxi(1, floori(pts / per))
	var rng := NatureGifts.rng_for(lv.run_state(), "wane")
	var keys: Array = BENEFIT.keys()
	var axes: Dictionary = (lv.god_state.get(AXES_KEY, {}) as Dictionary).duplicate() if lv.god_state.get(AXES_KEY, {}) is Dictionary else {}
	for i in stacks:
		var k: StringName = keys[rng.randi_range(0, keys.size() - 1)]
		axes[String(k)] = int(axes.get(String(k), 0)) + int(BENEFIT[k])
	lv.god_state[AXES_KEY] = axes


## 收获：身上每 every 层新生，地上掉一件自然系道具
static func _harvest(lv: LevelModule, renewal: int) -> void:
	if not lv.has_card(HARVEST) or renewal <= 0:
		return
	var src := HARVEST_UP if lv.has_card(HARVEST_UP) else HARVEST
	var every := maxf(1.0, lv.card_value(src, "every", 40.0))
	var n := floori(renewal / every)
	if n <= 0:
		return
	var run := lv.run_state()
	var defs := NatureGifts.pool(run, NatureGifts.NATURE)
	var w := NatureGifts.weights_of(lv, src, NatureGifts.WEIGHTS_WIDE)
	var floor_r := roundi(lv.card_value(src, "floor", 0.0))
	for i in n:
		NatureGifts.give(run, NatureGifts.roll(defs, w, NatureGifts.rng_for(run, "harvest"), floor_r), true)
#endregion


#region 初种
## 初种在第几阶（0 初种 / 1 幼芽 / 2 新蕊）；没拿 = -1
static func seed_stage(lv: LevelModule) -> int:
	return int(lv.god_state.get(SEED_STAGE, 0)) if lv != null and lv.count_of(SEED) > 0 else -1


## 神恩区显示哪一张（初种 / 幼芽 / 新蕊）
static func seed_shown(lv: LevelModule) -> StringName:
	return SEED_STAGES[clampi(seed_stage(lv), 0, SEED_STAGES.size() - 1)]


## 等着选「继续培育 / 采摘」
static func choice_due(lv: LevelModule) -> bool:
	return lv != null and bool(lv.god_state.get(SEED_CHOICE, false)) and lv.count_of(SEED) > 0


## 战后：攒新生，够了进一阶（幼芽、新蕊等着选；硕果直接给传说的、放回池子）
static func _seed_grow(lv: LevelModule, gained: int) -> void:
	var stage := seed_stage(lv)
	if stage < 0 or gained <= 0 or choice_due(lv):
		return
	var pts := int(lv.god_state.get(SEED_PTS, 0)) + gained
	var need := roundi(lv.card_value(SEED_STAGES[stage], "need", 100.0))     # 每一阶的牌上写着攒几点进下一阶
	if pts < need:
		lv.god_state[SEED_PTS] = pts
		return
	lv.god_state[SEED_PTS] = 0
	stage += 1
	lv.god_state[SEED_STAGE] = stage
	if stage >= SEED_STAGES.size() - 1:
		_seed_reap(lv, roundi(lv.card_value(SEED_STAGES[stage], "pick", 4.0)))     # 硕果
	else:
		lv.god_state[SEED_CHOICE] = true


## 选了：[param keep] 真 = 继续培育，假 = 采摘（幼芽给稀有、新蕊给史诗，然后放回池子）
static func seed_choose(lv: LevelModule, keep: bool) -> void:
	lv.god_state.erase(SEED_CHOICE)
	if keep:
		return
	var stage := seed_stage(lv)
	_seed_reap(lv, roundi(lv.card_value(SEED_STAGES[clampi(stage, 0, SEED_STAGES.size() - 1)], "pick", 2.0)))


## 给一件这一档的自然系道具，初种放回质变牌池子
static func _seed_reap(lv: LevelModule, rarity: int) -> void:
	var run := lv.run_state()
	var got := NatureGifts.give(run, NatureGifts.of_rarity(NatureGifts.pool(run, NatureGifts.NATURE), rarity, NatureGifts.rng_for(run, "seed")))
	if got != null:
		lv.god_state["seed_last"] = String(got.def.id)
	lv.taken.erase(String(SEED))
	for k in [SEED_STAGE, SEED_PTS, SEED_CHOICE]:
		lv.god_state.erase(k)
#endregion


#region 拿牌那一下、走到点上、战前屏
## 拿到这张牌当场要做的（坚韧、药材 / 食材感知、培育、动物交谈升级）
static func on_pick(lv: LevelModule, cid: StringName) -> void:
	var run := lv.run_state()
	if run == null:
		return
	match cid:
		TOUGH:
			var n := maxi(1, roundi(lv.card_value(TOUGH, "amount", 1.0)))
			if run.vitality != null:
				for i in n:
					if run.vitality.is_full():
						run.vitality.set_max(run.vitality.maximum + 1, &"level_card", true)
					else:
						run.vitality.restore(1, &"level_card")
		HERB_SENSE, FOOD_SENSE:
			var kind := &"herb" if cid == HERB_SENSE else &"ingredient"
			var w := sense_weights(lv, cid)
			var got := NatureGifts.give(run, NatureGifts.roll(NatureGifts.pool(run, kind), w, NatureGifts.rng_for(run, String(kind))))
			if got != null:
				lv.god_state["sense_last"] = String(got.def.id)
		SOW:
			var got := NatureGifts.give(run, NatureGifts.roll(NatureGifts.pool(run, &"seed"), NatureGifts.weights_of(lv, SOW, NatureGifts.WEIGHTS), NatureGifts.rng_for(run, "sow"), 0, true))
			if got != null:
				lv.god_state["sow_last"] = String(got.def.id)
		TALK_UP:
			beasts_deep(lv)


## 药材 / 食材感知：初值 50 / 35 / 10 / 5，之前每拿一张，第 r 档 ×（1 + gain × 拿过几张）^ r（越往上涨得越多）
static func sense_weights(lv: LevelModule, cid: StringName) -> Array[float]:
	var base := NatureGifts.weights_of(lv, cid, NatureGifts.WEIGHTS)
	var before := maxi(0, lv.count_of(cid) - 1)
	var gain := lv.card_value(cid, "gain", 0.5)
	for r in base.size():
		base[r] *= pow(1.0 + gain * before, r)
	return base


## 动物交谈（升级）：深处（深度不低于 deep）没走过的普通战斗点，按 pct% 换成同档的野兽
static func beasts_deep(lv: LevelModule) -> int:
	var run := lv.run_state()
	var ev := run.events if run != null else null
	if ev == null or ev.graph == null or ev.pool == null or ev.enemies == null or ev.items == null:
		return 0
	var deep := lv.card_value(TALK_UP, "deep", 0.5)
	var pct := lv.card_value(TALK_UP, "pct", 30.0)
	var depth := EnemyPlacer.depths_of(ev.graph)
	var rng := NatureGifts.rng_for(run, "beasts")
	var n := 0
	for id in ev.graph.node_ids():
		var node := ev.graph.get_node(id)
		if node.type != &"battle" or node.is_visited() or float(depth.get(id, 0.0)) < deep or not EnemyKit.has_enemy(node.content):
			continue
		var was := ev.enemies.enemy(StringName(String(node.content.get("enemy", ""))))
		if was == null or was.species == &"beast" or rng.randf() * 100.0 >= pct:
			continue
		var wanted := int(node.content.get("strength", was.strength))
		var best: EnemyPoolEntry = null
		var best_d := 1 << 30
		for e in ev.pool.entries:
			var d := ev.enemies.enemy(e.enemy) if e != null and e.weight > 0.0 else null
			if d == null or d.species != &"beast" or not e.fits(node):
				continue
			var dist := absi(d.strength - wanted)
			if dist < best_d:
				best_d = dist
				best = e
		if best == null:
			continue
		var built := EnemyPlacer.build_content(ev.enemies.enemy(best.enemy), ev.pool, ev.items, wanted, rng, ev.carry_rule, ev.bag_pool)
		if built.is_empty():
			continue
		node.content = built["content"]
		n += 1
	return n


## 亲近自然：第一次走进非战斗的点，下一场临时生命上限 +hp（可叠）
func on_node_entered(run: RunState, node: MapNode, first_visit: bool) -> String:
	var lv := LevelModule.of(run)
	if lv == null or node == null or not first_visit or not lv.has_card(NEAR) or not CALM_TYPES.has(node.type):
		return ""
	if NodeEvents.effective_type(node) in [&"battle", &"elite", &"core"]:
		return ""
	var hp := lv.god_value(NEAR_UP if lv.has_card(NEAR_UP) else NEAR, "hp")
	if hp <= 0.0:
		return ""
	lv.god_state[NEAR_KEY] = float(lv.god_state.get(NEAR_KEY, 0.0)) + hp
	return UiText.t("perk.nature_near") % [hp, float(lv.god_state[NEAR_KEY])]


## 动物交谈：遭遇野兽（首领不算）时战前屏多一个「交谈」：不打，改得一件随机自然系道具
func prebattle_actions(run: RunState, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lv := LevelModule.of(run)
	if lv == null or not lv.has_card(TALK) or type == &"core" or run.events == null:
		return out
	var spec := run.events.pending_battle_spec()
	var enemy := run.events.enemies.enemy(StringName(String((run.events.pending_battle.get("content", {}) as Dictionary).get("enemy", "")))) if run.events.enemies != null else null
	if spec == null or enemy == null or enemy.species != &"beast":
		return out
	out.append({"option": TALK_OPTION, "label": UiText.t("perk.nature_talk"), "why": ""})
	return out


func prebattle_apply(run: RunState, option: StringName = &"") -> bool:
	if option != TALK_OPTION or run == null or run.events.pending_battle.is_empty():
		return false
	var type := StringName(String(run.events.pending_battle.get("type", "battle")))
	if prebattle_actions(run, type).is_empty():
		return false
	var lv := LevelModule.of(run)
	var src := TALK_UP if lv.has_card(TALK_UP) else TALK
	var def := NatureGifts.roll(NatureGifts.pool(run, NatureGifts.NATURE), NatureGifts.weights_of(lv, src, NatureGifts.WEIGHTS_WIDE),
		NatureGifts.rng_for(run, "talk"), roundi(lv.card_value(src, "floor", 0.0)))
	if not run.events.skip_pending_battle():
		return false
	var got := NatureGifts.give(run, def)
	if got != null:
		lv.god_state["talk_last"] = String(got.def.id)
	return true


## 育种：背包里的种子每走一步算长几步（没拿 = 1）
static func seed_speed(run: RunState, inst: ItemInstance) -> int:
	var lv := LevelModule.of(run)
	if lv == null or inst == null or inst.def == null or not inst.def.has_tag(NatureGifts.SEED_TAG) or not lv.has_card(BREED):
		return 1
	return maxi(1, roundi(lv.card_value(BREED, "speed", 2.0)))
#endregion


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
