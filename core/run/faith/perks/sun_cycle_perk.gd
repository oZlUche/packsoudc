## 388 第 2 批：日神的战斗机制 —— 奉神即有【日月】（核心的数在这里，作者表顶上那一行；时长 6 秒是报告 388 的初值），
## 日神的牌拿了几张就把数填进 [SunCycle]。牌的数在各自的 `run_buffs/god_sun_*.json`（[GodCard]）。
## 信仰阶不再加日神的战斗效果（报告 372：阶的那几句改成了质变牌）
class_name SunCyclePerk
extends FaithPerk

## 旧内容还写着 part：只有 0 编译
@export var part: int = 0
## 白昼、黑夜各几秒（初值 6，作者表 15，报告 388 第三节缩的）
@export var base_sec: float = 6.0
## 更迭 / 星移斗转升级把时长越缩越短时，每边最短几秒（日长夜短 / 长夜促昼能减到 0，不受它管）
@export var min_sec: float = 1.0
@export var day_damage: float = 15.0
@export var night_haste: float = 15.0

const SUNBATH := &"god_sun_sunbath"
const SUNBATH_UP := &"god_sun_sunbath_up"
const MOONBATH := &"god_sun_moonbath"
const MOONBATH_UP := &"god_sun_moonbath_up"
const ECLIPSE := &"god_sun_eclipse"
const ECLIPSE_UP := &"god_sun_eclipse_up"
const LUNAR := &"god_sun_lunar"
const LUNAR_UP := &"god_sun_lunar_up"
const DUSK := &"god_sun_dusk"
const DUSK_UP := &"god_sun_dusk_up"
const DAWN := &"god_sun_dawn"
const DAWN_UP := &"god_sun_dawn_up"
const SHIFT := &"god_sun_shift"
const SHIFT_UP := &"god_sun_shift_up"
const BLAZE := &"god_sun_blaze"
const BLAZE_UP := &"god_sun_blaze_up"
const FROST := &"god_sun_frost"
const FROST_UP := &"god_sun_frost_up"
const CONTRAST := &"god_sun_contrast"
const CONTRAST_UP := &"god_sun_contrast_up"
const RISE := &"god_sun_rise"
const RISE_UP := &"god_sun_rise_up"
const REST := &"god_sun_rest"
const REST_UP := &"god_sun_rest_up"
const ETERNAL_DAY := &"god_sun_eternal_day"
const ETERNAL_DAY_UP := &"god_sun_eternal_day_up"
const ETERNAL_NIGHT := &"god_sun_eternal_night"
const ETERNAL_NIGHT_UP := &"god_sun_eternal_night_up"
const LONG_DAY := &"god_sun_longday"
const LONG_NIGHT := &"god_sun_longnight"
const FASTER := &"god_sun_faster"
const SLOWER := &"god_sun_slower"
const FULL_MOON := &"god_sun_fullmoon"
const DAWN_LIGHT := &"god_sun_dawnlight"
const DUSK_LIGHT := &"god_sun_dusklight"
const NOON := &"god_sun_noon"
const VEIL := &"god_sun_veil"
const HUMBLE := &"god_sun_humble"
const MIRACLE := &"god_sun_miracle"


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	if part != 0:
		return
	input.rules.append(rule_for(LevelModule.of(run)))


## 白昼、黑夜各几秒（只按牌：日长夜短 / 长夜促昼 / 更迭 / 永恒；[param lv] 空 = 核心）
static func durations(lv: LevelModule, perk: SunCyclePerk = null) -> Vector2:
	var base := perk.base_sec if perk != null else 6.0
	var floor_ := perk.min_sec if perk != null else 1.0
	if lv == null:
		return Vector2(base, base)
	var shift := (lv.god_value(LONG_DAY, "pct") - lv.god_value(LONG_NIGHT, "pct")) / 100.0
	var mult := 1.0
	for i in lv.count_of(FASTER):
		mult *= lv.god_value(FASTER, "mult", 0.8) / maxi(1, lv.count_of(FASTER))
	for i in lv.count_of(SLOWER):
		mult *= lv.god_value(SLOWER, "mult", 1.25) / maxi(1, lv.count_of(SLOWER))
	var d := maxf(0.0, base * (1.0 + shift))
	var n := maxf(0.0, base * (1.0 - shift))
	# 更迭 / 永恒按倍数缩放，缩不到下限以下（已经是 0 的照旧 0）
	d = maxf(floor_, d * mult) if d > 0.0 else 0.0
	n = maxf(floor_, n * mult) if n > 0.0 else 0.0
	return Vector2(d, n)


func rule_for(lv: LevelModule) -> AbilityRule:
	var trig := FaithMechanicTrigger.new()
	trig.events = [BattleEvent.BATTLE_START, BattleEvent.BEFORE_DAMAGE] as Array[StringName]
	trig.pulse = true
	var eff := effect_for(lv)
	var cad := SunCadence.new()
	cad.effect = eff
	var rule := AbilityRule.new()
	rule.trigger = trig
	rule.cadence = cad
	rule.effects.append(eff)
	return rule


func effect_for(lv: LevelModule) -> SunCycle:
	var e := SunCycle.new()
	var dur := durations(lv, self)
	e.day_sec = dur.x
	e.night_sec = dur.y
	e.day_damage = day_damage
	e.night_haste = night_haste
	if lv == null:
		return e
	e.day_damage += lv.god_value(NOON, "pct")
	e.night_haste += lv.god_value(FULL_MOON, "pct")
	if lv.has_card(ECLIPSE):
		e.eclipse_sun = true
		e.eclipse_sun_haste = lv.god_value(ECLIPSE_UP, "pct") if lv.has_card(ECLIPSE_UP) else 0.0
	if lv.has_card(LUNAR):
		e.eclipse_moon = true
		e.eclipse_moon_damage = lv.god_value(LUNAR_UP, "pct") if lv.has_card(LUNAR_UP) else 0.0
	if lv.has_card(DUSK):
		var src := DUSK_UP if lv.has_card(DUSK_UP) else DUSK
		e.dusk_sec = lv.god_value(src, "sec")
		e.dusk_ramp = lv.god_value(DUSK_UP, "ramp") if lv.has_card(DUSK_UP) else 0.0
	if lv.has_card(DAWN):
		var src2 := DAWN_UP if lv.has_card(DAWN_UP) else DAWN
		e.dawn_sec = lv.god_value(src2, "sec")
		e.dawn_ramp = lv.god_value(DAWN_UP, "ramp") if lv.has_card(DAWN_UP) else 0.0
	if lv.has_card(SUNBATH):
		e.sun_light = roundi(lv.god_value(SUNBATH_UP if lv.has_card(SUNBATH_UP) else SUNBATH, "stacks"))
	if lv.has_card(MOONBATH):
		e.moon_light = roundi(lv.god_value(MOONBATH_UP if lv.has_card(MOONBATH_UP) else MOONBATH, "stacks"))
	if lv.has_card(BLAZE):
		e.burn = roundi(lv.god_value(BLAZE_UP if lv.has_card(BLAZE_UP) else BLAZE, "stacks"))
	if lv.has_card(FROST):
		e.frost = roundi(lv.god_value(FROST_UP if lv.has_card(FROST_UP) else FROST, "stacks"))
	if lv.has_card(CONTRAST):
		e.ramp = lv.god_value(CONTRAST_UP if lv.has_card(CONTRAST_UP) else CONTRAST, "pct")
	if lv.has_card(RISE):
		var rise := RISE_UP if lv.has_card(RISE_UP) else RISE
		e.sunrise = lv.god_value(rise, "hp")
		e.sunrise_stamina = lv.god_value(rise, "stamina")
	if lv.has_card(REST):
		var up := lv.has_card(REST_UP)
		e.rest_heal = lv.god_value(REST_UP if up else REST, "pct")
		e.rest_haste = up
	if lv.has_card(SHIFT):
		e.shift_on = true
		e.shift_per = lv.god_value(SHIFT, "pct", 1.0)
		var done := int(lv.god_state.get("sun_shifts", 0))
		e.shift_start = done
		if lv.has_card(SHIFT_UP) and done > 0:
			# 星移斗转升级：一局里每转一次，日夜时长 ×0.99（下限照样管）
			var k := pow(1.0 - lv.god_value(SHIFT_UP, "shrink", 1.0) / 100.0, done)
			e.day_sec = maxf(min_sec, e.day_sec * k) if e.day_sec > 0.0 else 0.0
			e.night_sec = maxf(min_sec, e.night_sec * k) if e.night_sec > 0.0 else 0.0
	if lv.has_card(ETERNAL_DAY):
		var src3 := ETERNAL_DAY_UP if lv.has_card(ETERNAL_DAY_UP) else ETERNAL_DAY
		e.eternal_day = lv.god_value(src3, "pct")
		e.eternal_day_scorch = roundi(lv.god_value(src3, "scorch"))
	if lv.has_card(ETERNAL_NIGHT):
		var src4 := ETERNAL_NIGHT_UP if lv.has_card(ETERNAL_NIGHT_UP) else ETERNAL_NIGHT
		e.eternal_night = lv.god_value(src4, "pct")
		e.eternal_night_hp = roundi(lv.god_value(src4, "hp"))
	e.dawn_armor = lv.god_value(DAWN_LIGHT, "pct")
	e.dusk_stamina = lv.god_value(DUSK_LIGHT, "pct")
	if lv.has_card(VEIL):
		e.veil = (1.0 - pow(1.0 - lv.god_value(VEIL, "pct") / lv.count_of(VEIL) / 100.0, lv.count_of(VEIL))) * 100.0     # 夜幕：乘法叠
	e.humble = lv.god_value(HUMBLE, "pct")
	return e


func _summary() -> String:
	return UiText.t("perk.sun_cycle") % [TextTemplate.num(base_sec), TextTemplate.num(day_damage), TextTemplate.num(night_haste)]


func battle_note(_run: RunState) -> String:
	return _summary() if part == 0 else ""
