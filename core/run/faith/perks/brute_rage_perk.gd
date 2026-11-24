## 388 第 1 批：蛮神的战斗机制 —— 奉神即有【怒气】（核心的数在这里，作者表顶上那一行），蛮神的牌拿了几张就把数填进 [BruteRage]。
## 牌的数在各自的 `run_buffs/god_brute_*.json`（[GodCard]），这里按牌 id 读；【死斗】编进 [method CompileInput.keep_undying]。
## 信仰阶不再加怒气的东西（报告 372：阶的那几句改成了质变牌）
class_name BruteRagePerk
extends FaithPerk

## 1.1 之前的档、旧内容还写着 part：只有 0 编译
@export var part: int = 0
@export var percent_per_stack: float = 1.0
@export var cap: int = 30
@export var duration_sec: float = 4.0
@export var damage_per: float = 2.0

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
const CAP := &"god_brute_cap"
const HASTE := &"god_brute_haste"
const DAMAGE := &"god_brute_damage"
const REGEN := &"god_brute_regen"
const UNDYING := &"god_brute_undying"
const LIFESTEAL := &"god_brute_lifesteal"
const LINGER := &"god_brute_linger"
const CORNERED_MORE := &"god_brute_cornered_more"
const IRATE := &"god_brute_irate"


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


## 拿着 [param lv] 里这些牌的那条规则（[param lv] 空 = 只有核心；测试与台架直接拿）
func rule_for(lv: LevelModule) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BEFORE_DAMAGE, BattleEvent.DAMAGE, BattleEvent.STATUS_APPLIED] as Array[StringName]
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
	e.cap += roundi(lv.god_value(CAP, "stacks"))
	e.duration_sec += lv.god_value(DURATION, "sec")
	e.damage_per += lv.god_value(DAMAGE, "pct")
	e.haste_per = lv.god_value(HASTE, "pct")
	if lv.has_card(REGEN):
		e.regen_per = lv.god_value(REGEN, "regen") / maxf(1.0, lv.god_value(REGEN, "per") / lv.count_of(REGEN))
	e.gain_bonus = roundi(lv.god_value(IRATE, "pct"))
	if lv.has_card(CORNERED):
		e.low_percent = roundi(lv.god_value(CORNERED, "below", 50.0))
		e.low_bonus = roundi(lv.god_value(CORNERED, "bonus") + lv.god_value(CORNERED_MORE, "bonus"))
		e.low_freeze = lv.has_card(CORNERED_UP)
	if lv.has_card(BREAK):
		e.armor_per = lv.god_value(BREAK_UP, "pct") if lv.has_card(BREAK_UP) else lv.god_value(BREAK, "pct")
		e.ignore_per = lv.god_value(BREAK_UP, "ignore")
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
	return UiText.t("perk.brute_rage") % [TextTemplate.num(percent_per_stack), cap, TextTemplate.num(duration_sec), TextTemplate.num(damage_per)]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
