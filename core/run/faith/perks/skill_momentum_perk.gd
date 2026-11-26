## 396 第 B 批：技巧之神的战斗机制 —— 奉神即有【连击】（核心的数在这里，作者表顶上那一行），技巧之神的牌拿了几张就把数填进 [SkillMomentum]。
## 牌的数在各自的 `run_buffs/god_skill_*.json`（[GodCard]），这里按牌 id 读。【徒手大师】的【拳头】在编译完以后补进参战道具（[method graft_fist]）；
## 【一气呵成】打完一场记下留几层（[method after_battle]），下一场开战给
class_name SkillMomentumPerk
extends FaithPerk

## 旧内容还写着 part：只有 0 编译
@export var part: int = 0
@export var haste_per: float = 1.0

const GAP := &"god_skill_gap"
const GAP_UP := &"god_skill_gap_up"
const STANCE := &"god_skill_stance"
const STANCE_UP := &"god_skill_stance_up"
const ZANSHIN := &"god_skill_zanshin"
const ZANSHIN_UP := &"god_skill_zanshin_up"
const PRESS := &"god_skill_press"
const PRESS_UP := &"god_skill_press_up"
const FIST := &"god_skill_fist"
const FIST_UP := &"god_skill_fist_up"
const GUARD := &"god_skill_guard"
const GUARD_UP := &"god_skill_guard_up"
const QIGONG := &"god_skill_qigong"
const QIGONG_UP := &"god_skill_qigong_up"
const EDGE := &"god_skill_edge"
const EDGE_UP := &"god_skill_edge_up"
const CARRY := &"god_skill_carry"
const CARRY_UP := &"god_skill_carry_up"
const CLUMSY := &"god_skill_clumsy"
const CLUMSY_UP := &"god_skill_clumsy_up"
const SOFT := &"god_skill_soft"
const SOFT_UP := &"god_skill_soft_up"
const STEADY := &"god_skill_steady"
const READY := &"god_skill_ready"
const STREAM := &"god_skill_stream"
const CLOUD := &"god_skill_cloud"
const PARRY := &"god_skill_parry"
const BREATH := &"god_skill_breath"
const VIGOR := &"god_skill_vigor"
const POISE := &"god_skill_poise"
const SEE := &"god_skill_see"
## 作者 11-26：拳头牌（拿了徒手大师才出，之后每次普通选牌保底一张）与专属牌【收式】
const FIST_EDGE := &"god_skill_fist_edge"
const FIST_SHADOW := &"god_skill_fist_shadow"
const FIST_FLOW := &"god_skill_fist_flow"
const FIST_INTENT := &"god_skill_fist_intent"
const FINISH := &"god_skill_finish"
## 一气呵成：上一场留下几层（记在 [member LevelModule.god_state]）
const CARRY_KEY := "skill_carry"
## 【拳头】（代码里拼的道具，不进内容表、不掉落）
const FIST_ID := &"fist"


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	input.rules.append(rule_for(LevelModule.of(run)))


## 拿着 [param lv] 里这些牌的那条规则（[param lv] 空 = 只有核心；测试与台架直接拿）
func rule_for(lv: LevelModule) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BATTLE_START, BattleEvent.BEFORE_DAMAGE, BattleEvent.DAMAGE, BattleEvent.ITEM_FIRED, BattleEvent.ITEM_SKIPPED] as Array[StringName]
	trig.pulse = true
	var cad := FaithPulseCadence.new()
	cad.every_sec = SkillMomentum.STEP
	cad.first_sec = SkillMomentum.STEP
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = cad
	rule.effects.append(effect_for(lv))
	return rule


## 有升级拿升级版的数，没有拿原牌的
static func _pick(lv: LevelModule, base: StringName, up: StringName, key: String, fallback: float = 0.0) -> float:
	return lv.god_value(up if lv.has_card(up) else base, key, fallback)


## 核心的数 + 牌的数
func effect_for(lv: LevelModule) -> SkillMomentum:
	var e := SkillMomentum.new()
	e.haste_per = haste_per
	if lv == null:
		return e
	e.opening = roundi(lv.god_value(READY, "stacks"))
	e.carry_in = roundi(float(lv.god_state.get(CARRY_KEY, 0))) if lv.has_card(CARRY) else 0
	e.keep_on_reset = roundi(lv.god_value(STEADY, "keep"))
	e.flow_per = lv.god_value(STREAM, "pct")
	if lv.has_card(CLOUD):
		e.light_at = roundi(lv.god_value(CLOUD, "at", 10.0) / lv.count_of(CLOUD))
		e.light_pct = lv.god_value(CLOUD, "pct")
	if lv.has_card(PARRY):
		e.parry_every = roundi(lv.god_value(PARRY, "every", 10.0) / lv.count_of(PARRY))
		e.parry_pct = lv.god_value(PARRY, "pct")
	e.breath_per = lv.god_value(BREATH, "per")
	e.vigor_per = lv.god_value(VIGOR, "per")
	if lv.has_card(POISE):
		e.poise_sec = lv.god_value(POISE, "sec", 3.0) / lv.count_of(POISE)
		e.poise_pct = lv.god_value(POISE, "pct")
	e.see_per = lv.god_value(SEE, "per")
	e.fist_extra_pct = minf(100.0, lv.god_value(FIST_FLOW, "pct"))
	e.finish_sec = lv.card_value(FINISH, "sec", 10.0) if lv.has_card(FINISH) else 0.0
	if lv.has_card(GAP):
		e.gap_every = roundi(_pick(lv, GAP, GAP_UP, "every", 5.0))
		e.gap_pct = _pick(lv, GAP, GAP_UP, "pct")
	if lv.has_card(STANCE):
		e.stance = roundi(_pick(lv, STANCE, STANCE_UP, "stacks", 1.0))
	if lv.has_card(ZANSHIN):
		e.zanshin = roundi(_pick(lv, ZANSHIN, ZANSHIN_UP, "weapons", 1.0))
	if lv.has_card(PRESS):
		e.press_pct = _pick(lv, PRESS, PRESS_UP, "pct")
	if lv.has_card(GUARD):
		e.guard_at = roundi(_pick(lv, GUARD, GUARD_UP, "at", 30.0))
		e.guard_flat = _pick(lv, GUARD, GUARD_UP, "flat")
	if lv.has_card(QIGONG):
		e.qigong_every = roundi(_pick(lv, QIGONG, QIGONG_UP, "every", 7.0))
		e.qigong_stacks = roundi(_pick(lv, QIGONG, QIGONG_UP, "stacks", 1.0))
	if lv.has_card(EDGE):
		e.edge_crit = _pick(lv, EDGE, EDGE_UP, "crit")
		e.edge_crit_damage = lv.god_value(EDGE_UP, "crit_damage")
	if lv.has_card(CLUMSY):
		e.clumsy_pct = _pick(lv, CLUMSY, CLUMSY_UP, "pct")
		e.clumsy_refire = lv.has_card(CLUMSY_UP)
	if lv.has_card(SOFT):
		e.soft_pct = _pick(lv, SOFT, SOFT_UP, "pct")
	return e


#region 一气呵成
## 打完一场：按最后还剩几层记下留到下一场的（没拿 = 不记）
static func after_battle(lv: LevelModule, result: BattleResult) -> void:
	if lv == null or not lv.has_card(CARRY):
		return
	var last := 0
	if result != null:
		for raw in result.log:
			var e := raw as BattleEvent
			if e != null and e.side == 0 and (e.name == BattleEvent.STATUS_STACKED or e.name == BattleEvent.STATUS_UNSTACKED) and e.get_name(&"buff") == SkillMomentum.BUFF_ID:
				last = e.get_int(&"stacks")
	lv.god_state[CARRY_KEY] = floori(last * _pick(lv, CARRY, CARRY_UP, "pct") / 100.0)
#endregion


#region 徒手大师
## 这一场有没有【拳头】：拿了徒手大师，且编出来的参战道具里一件武器都没有
static func fist_due(run: RunState, spec: CombatantSpec) -> bool:
	var lv := LevelModule.of(run)
	if lv == null or not lv.has_card(FIST) or spec == null:
		return false
	for it in spec.items:
		if (it as CompiledItem).tags.has(&"weapon"):
			return false
	return true


## 【拳头】：伤害 5、耐力 1、每秒一下，吃效果加成（作者备注）；升级版两连击；拳锋 / 拳影 / 拳意加在这里
static func fist_def(lv: LevelModule) -> ItemDef:
	var d := ItemDef.new()
	d.id = FIST_ID
	d.display_name = UiText.t("skill.fist")
	d.tags = [&"weapon", &"melee", SkillMomentum.FIST_TAG] as Array[StringName]
	d.shape = ItemShape.new()     # 默认一格
	var c := CombatProfile.new()
	c.base_stats = {"damage": lv.god_value(FIST, "damage", 5.0) + lv.god_value(FIST_EDGE, "damage")}
	if lv.has_card(FIST_INTENT):     # 拳意：只加在拳头上（物品的暴击是自己的底数，没写就是默认值）
		c.base_stats[String(BattleStats.CRIT_CHANCE)] = float(BattleStats.DEFAULT_BASE[BattleStats.CRIT_CHANCE]) + lv.god_value(FIST_INTENT, "crit") / 100.0
		c.base_stats[String(BattleStats.CRIT_DAMAGE)] = float(BattleStats.DEFAULT_BASE[BattleStats.CRIT_DAMAGE]) + lv.god_value(FIST_INTENT, "crit_damage") / 100.0
	var r := AbilityRule.new()
	r.trigger = OnSchedule.new()
	var cad := CooldownCadence.new()
	# 拳影：攻速（次 / 秒）加上去，冷却 = 1 / 攻速
	cad.seconds = 1.0 / (1.0 / lv.god_value(FIST, "sec", 1.0) + lv.god_value(FIST_SHADOW, "rate"))
	r.cadence = cad
	var cost := ResourceCost.new()
	cost.amount = lv.god_value(FIST, "stamina", 1.0)
	r.costs = [cost] as Array[Cost]
	var hits := roundi(lv.god_value(FIST_UP, "hits", 1.0)) if lv.has_card(FIST_UP) else 1
	var fx: Array[CombatEffect] = []
	for i in maxi(1, hits):
		fx.append(DealDamage.new())
	r.effects = fx
	c.rules = [r] as Array[AbilityRule]
	d.combat = c
	return d


## 编完以后把【拳头】补进参战道具（按同一份编译输入单独编它，整单位的修饰照样吃；不占背包格子、界面上不画）
static func graft_fist(run: RunState, spec: CombatantSpec, input: CompileInput) -> void:
	if not fist_due(run, spec):
		return
	var board := GridInventory.new(Vector2i(1, 1), -1, false)
	var inst := ItemInstance.create(fist_def(LevelModule.of(run)))
	if not board.place(inst, Vector2i.ZERO, 0):
		return
	var solo := BattleCompiler.compile(board, input)
	for it in solo.items:
		spec.add(it as CompiledItem)
#endregion


func _summary() -> String:
	return UiText.t("perk.skill_momentum") % TextTemplate.num(haste_per)


## 作用于角色本身 → 进 buff 栏
func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
