## 388 第 1 批：蛮神的战斗机制 —— 奉神即有【怒气】（核心的数在这里，作者表顶上那一行），蛮神的牌拿了几张就把数填进 [BruteRage]。
## 牌的数在各自的 `run_buffs/god_brute_*.json`（[GodCard]），这里按牌 id 读；【死斗】编进 [method CompileInput.keep_undying]。
## 信仰阶不再加怒气的东西（报告 372：阶的那几句改成了质变牌）
class_name BruteRagePerk
extends FaithPerk

## 1.1 之前的档、旧内容还写着 part：只有 0 编译
@export var part: int = 0
@export var percent_per_stack: float = 1.0
## 396（作者表 11-25）：核心不再有上限、不再每层加伤害（0 = 不封顶；数留着给旧内容）
@export var cap: int = 0
@export var duration_sec: float = 4.0
@export var damage_per: float = 0.0

## 蛮神的牌（id 与作者表的对应见报告 388 第 1 批的设想对照表）
const BREAK := &"god_brute_break"
const BREAK_UP := &"god_brute_break_up"
const CORNERED := &"god_brute_cornered"
const CORNERED_UP := &"god_brute_cornered_up"
const DEATHFIGHT := &"god_brute_deathfight"
const DEATHFIGHT_UP := &"god_brute_deathfight_up"
const BURN := &"god_brute_burn"
const BURN_UP := &"god_brute_burn_up"
const PAIN := &"god_brute_pain"
const PAIN_UP := &"god_brute_pain_up"
const BLOOD := &"god_brute_blood"
const BLOOD_UP := &"god_brute_blood_up"
const HATE := &"god_brute_hate"
const HATE_UP := &"god_brute_hate_up"
const ARMOR := &"god_brute_armor"
const ARMOR_UP := &"god_brute_armor_up"
const DURATION := &"god_brute_duration"
const HASTE := &"god_brute_haste"
const DAMAGE := &"god_brute_damage"
const REGEN := &"god_brute_regen"
const UNDYING := &"god_brute_undying"
const LIFESTEAL := &"god_brute_lifesteal"
const LINGER := &"god_brute_linger"
const CORNERED_MORE := &"god_brute_cornered_more"
const IRATE := &"god_brute_irate"
const EAT := &"god_brute_eat"
const EAT_UP := &"god_brute_eat_up"
## 396：怒意延绵（质变，没有升级）、献祭（基础牌，一次性）
const PERSIST := &"god_brute_persist"
const SACRIFICE := &"god_brute_sacrifice"
## 【血肉】：能进食的那类（标签）；吃下去攒的生命上限记在 [member LevelModule.god_state] 这一格
const FLESH_TAG := &"blood_flesh"
const FLESH_KEY := "brute_flesh_hp"
## 395：吃下的器官 {道具 id: 几件}；特性按道具现在的 [member ItemDef.eat_trait] × 件数算（改表连旧档一起变）
const ORGANS_KEY := "brute_organs"


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	var lv := LevelModule.of(run)
	input.rules.append(rule_for(lv))
	var hold := undying_sec(lv)
	if hold > 0.0:
		input.keep_undying(hold)


## 【死斗】：坚持几秒（没拿 = 0）
static func undying_sec(lv: LevelModule) -> float:
	if lv == null or not lv.has_card(DEATHFIGHT):
		return 0.0
	return lv.god_value(DEATHFIGHT, "sec") + lv.god_value(DEATHFIGHT_UP, "sec") + lv.god_value(UNDYING, "sec")


#region 献祭（396）
## 献祭能不能进池：剩余体力大于要扣的，且还有质变牌可选
static func can_sacrifice(lv: LevelModule) -> bool:
	var run := lv.run_state() if lv != null else null
	if run == null or run.vitality == null:
		return false
	return run.vitality.current > roundi(lv.card_value(SACRIFICE, "vitality", 2.0)) and lv.has_qual_pool()


## 拿到献祭：扣体力，欠一次质变选牌（[method LevelModule.sacrifice_due]）
static func sacrifice(lv: LevelModule, cid: StringName) -> void:
	var run := lv.run_state()
	if run == null:
		return
	if run.vitality != null:
		run.vitality.spend(roundi(lv.card_value(cid, "vitality", 2.0)), &"sacrifice")
	lv.god_state[LevelModule.SACRIFICE_DUE] = lv.sacrifice_due() + 1
#endregion


#region 啖肉吮血（第 1 批补）
## 这件能不能吃：拿了啖肉吮血、是【血肉】
static func can_eat(run: RunState, inst: ItemInstance) -> bool:
	var lv := LevelModule.of(run)
	return lv != null and inst != null and inst.def != null and inst.def.has_tag(FLESH_TAG) and lv.has_card(EAT)


## 吃下 [param def] 加几点生命上限：每格 × (稀有度 + 1)
static func flesh_gain(lv: LevelModule, def: ItemDef) -> float:
	if lv == null or def == null:
		return 0.0
	var per := lv.god_value(EAT_UP if lv.has_card(EAT_UP) else EAT, "per_cell")
	return per * def.cell_count() * (def.rarity + 1)


## 整局的加成：{max_hp, max_stamina}（没拿 = 空）。升级版的耐力上限按攒下的生命上限算，拿到升级时以前吃的也补上
static func flesh_bonus(lv: LevelModule) -> Dictionary:
	if lv == null or not lv.has_card(EAT):
		return {}
	var hp := float(lv.god_state.get(FLESH_KEY, 0.0))
	if hp <= 0.0:
		return {}
	var out := {&"max_hp": hp}
	if lv.has_card(EAT_UP):
		out[&"max_stamina"] = hp * lv.god_value(EAT_UP, "stamina", 50.0) / 100.0
	return out


## 395：器官（带特性的【血肉】）
static func is_organ(def: ItemDef) -> bool:
	return OrganTraits.is_organ(def)


## 395：蛮神直接吃下的器官合计 {特性键: 数}（没拿啖肉吮血 = 空；食堂那顿饭的在 [OrganTraits]）
static func organ_totals(run: RunState) -> Dictionary:
	var lv := LevelModule.of(run)
	if lv == null or run.items == null or not lv.has_card(EAT):
		return {}
	var eaten: Variant = lv.god_state.get(ORGANS_KEY, {})
	return OrganTraits.sum_of(eaten as Dictionary, run.items) if eaten is Dictionary else {}


## 进食键的提示：肉写加多少生命上限，器官写特性（好处在前）
static func eat_tip(run: RunState, def: ItemDef) -> String:
	if is_organ(def):
		return OrganTraits.line(def.eat_trait)
	return UiText.t("bag.eat_tip") % TextTemplate.num(flesh_gain(LevelModule.of(run), def))


## 进食：从背包拿走这件、记下生命上限（器官记一件，给特性）。返回 {hp, stamina}，器官另有 {trait}（吃不了 = 空）
static func eat(run: RunState, inst: ItemInstance) -> Dictionary:
	if not can_eat(run, inst) or run.board == null or run.board.get_item(inst.uid) == null:
		return {}
	var lv := LevelModule.of(run)
	if is_organ(inst.def):
		run.board.remove(inst.uid)
		var eaten: Dictionary = (lv.god_state.get(ORGANS_KEY, {}) as Dictionary).duplicate() if lv.god_state.get(ORGANS_KEY, {}) is Dictionary else {}
		eaten[String(inst.def.id)] = int(eaten.get(String(inst.def.id), 0)) + 1
		lv.god_state[ORGANS_KEY] = eaten
		return {"hp": 0.0, "stamina": 0.0, "trait": inst.def.eat_trait.duplicate()}
	var before := flesh_bonus(lv)
	var gain := flesh_gain(lv, inst.def)
	run.board.remove(inst.uid)
	lv.god_state[FLESH_KEY] = float(lv.god_state.get(FLESH_KEY, 0.0)) + gain
	var after := flesh_bonus(lv)
	return {"hp": gain, "stamina": float(after.get(&"max_stamina", 0.0)) - float(before.get(&"max_stamina", 0.0))}
#endregion


## 拿着 [param lv] 里这些牌的那条规则（[param lv] 空 = 只有核心；测试与台架直接拿）
func rule_for(lv: LevelModule) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BEFORE_DAMAGE, BattleEvent.DAMAGE, BattleEvent.STATUS_APPLIED, BattleEvent.STATUS_UNSTACKED] as Array[StringName]
	trig.pulse = true
	var cad := FaithPulseCadence.new()
	cad.every_sec = BruteRage.STEP
	cad.first_sec = BruteRage.STEP
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = cad
	rule.effects.append(effect_for(lv))
	return rule


## 核心的数 + 牌的数
func effect_for(lv: LevelModule) -> BruteRage:
	var e := BruteRage.new()
	e.percent_per_stack = percent_per_stack
	e.cap = cap
	e.duration_sec = duration_sec
	e.damage_per = damage_per
	if lv == null:
		return e
	e.duration_sec += lv.god_value(DURATION, "sec")
	if lv.has_card(PERSIST):
		e.duration_sec *= lv.god_value(PERSIST, "pct", 50.0) / 100.0
		e.refresh_on_hit = true
	e.damage_per += lv.god_value(DAMAGE, "pct")
	e.haste_per = lv.god_value(HASTE, "pct")
	if lv.has_card(REGEN):
		var per := maxf(1.0, lv.god_value(REGEN, "per") / lv.count_of(REGEN))
		if lv.god_value(REGEN, "step") > 0.0:
			# 开关 step（作者待定）：满整段才加，不按层平摊
			e.regen_step = roundi(per)
			e.regen_step_amount = lv.god_value(REGEN, "regen")
		else:
			e.regen_per = lv.god_value(REGEN, "regen") / per
	e.gain_bonus = roundi(lv.god_value(IRATE, "pct"))
	if lv.has_card(CORNERED):
		# 困兽犹斗：每张让困兽的数 +25%（加算，作者备注）
		var per := lv.god_value(CORNERED_UP, "pct") if lv.has_card(CORNERED_UP) else lv.god_value(CORNERED, "pct")
		e.cornered_per = per * (1.0 + lv.god_value(CORNERED_MORE, "bonus") / 100.0)
	if lv.has_card(BREAK):
		var src := BREAK_UP if lv.has_card(BREAK_UP) else BREAK
		e.armor_per = lv.god_value(src, "pct")
		e.damage_per += lv.god_value(src, "dmg")
	if lv.has_card(BURN):
		var up := lv.has_card(BURN_UP)
		e.scorch_every = roundi(lv.god_value(BURN, "every", 10.0))
		e.scorch_stacks = roundi(lv.god_value(BURN_UP, "stacks") if up else lv.god_value(BURN, "stacks"))
	if lv.has_card(PAIN):
		var src := PAIN_UP if lv.has_card(PAIN_UP) else PAIN
		e.defer_percent = roundi(lv.god_value(src, "pct"))
		e.defer_sec = roundi(lv.god_value(src, "sec", 5.0))
	if lv.has_card(BLOOD):
		e.strike_every = roundi(lv.god_value(BLOOD_UP, "every") if lv.has_card(BLOOD_UP) else lv.god_value(BLOOD, "every"))
	if lv.has_card(HATE):
		e.hate = 2 if lv.has_card(HATE_UP) else 1
		e.hate_halving = lv.god_value(HATE_UP, "halving") > 0.0     # 开关（作者待定）：寒冷、麻痹减半也算触发
	if lv.has_card(ARMOR):
		e.armor_window = lv.god_value(ARMOR, "window", 3.0)
		e.armor_cd = lv.god_value(ARMOR, "cd", 10.0)
		e.armor_percent = roundi(lv.god_value(ARMOR, "pct", 50.0))
		e.armor_dealt = lv.has_card(ARMOR_UP)
		e.armor_heal_percent = roundi(lv.god_value(ARMOR_UP, "heal"))
	e.linger_percent = lv.god_value(LINGER, "pct")
	e.lifesteal_percent = lv.god_value(LIFESTEAL, "pct")
	return e


func _summary() -> String:
	return UiText.t("perk.brute_rage") % [TextTemplate.num(percent_per_stack), TextTemplate.num(duration_sec)]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
