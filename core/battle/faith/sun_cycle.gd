## 388 第 2 批（作者牌表 11-24）：日神的【日月】与日神的牌在战斗里的那一半。一条规则（[FaithMechanicTrigger] 听受伤前，
## 节拍由 [SunCadence] 按日夜时间轴排：每个阶段的起止、残阳 / 斜月的尾巴、每一整秒）放整套，数由 [SunCyclePerk] 编译时按拿了哪些牌填好。
##
## - 核心：开战是白昼，[member day_sec] 秒后黑夜，[member night_sec] 秒后又是白昼……一边是 0 就一直是另一边。
##   白昼造成伤害 +[member day_damage]%，黑夜急速 +[member night_haste]%。身上挂【白昼】/【黑夜】让界面看得见是哪一边。
## - 「同时视为」：日蚀（白昼也算黑夜）、月蚀（黑夜也算白昼）、残阳（进黑夜的前几秒也算白昼）、斜月（进白昼的前几秒也算黑夜）。
##   残阳 / 斜月升级：在那段尾巴里每秒让那一边的加成再增效 5%（攒着，下次接着叠）。
## - 每一整秒：日光浴 / 月光浴的层数、大日炎炎 / 微月澹澹给敌人挂状态、非黑即白的爬升、日落当息回血、永日 / 永夜的代价。
## - 进白昼：日出当作（生命、耐力上限连当前值）、黎明（护甲）；进黑夜：黄昏（耐力）、日落当息（我方武器停表到黑夜结束）。
## - 每换一次边：星移斗转 +1 层（一局里留着，[LevelModule.god_state]）；写战记 `faith_mechanic` / `sun_window`（经验值按它给）。
## - 受伤前：夜幕（黑夜时受到的伤害按牌数连乘减少）、谦卑（受到和造成的都少几成）
class_name SunCycle
extends CombatEffect

const DAY := &"sun_day"
const NIGHT := &"sun_night"
const SUN_LIGHT := &"sun_light"
const MOON_LIGHT := &"moon_light"
const SHIFT := &"sun_shift"
const ETERNAL := &"sun_eternal"
const SCORCH := &"scorch"
const CHILL := &"chill"

## 时长（秒；这一场按牌算好的）
@export var day_sec: float = 6.0
@export var night_sec: float = 6.0
@export var day_damage: float = 15.0
@export var night_haste: float = 15.0
## 同时视为
@export var eclipse_sun: bool = false
@export var eclipse_sun_haste: float = 0.0
@export var eclipse_moon: bool = false
@export var eclipse_moon_damage: float = 0.0
@export var dusk_sec: float = 0.0
@export var dusk_ramp: float = 0.0
@export var dawn_sec: float = 0.0
@export var dawn_ramp: float = 0.0
## 每秒
@export var sun_light: int = 0
@export var moon_light: int = 0
@export var burn: int = 0
@export var frost: int = 0
@export var ramp: float = 0.0
@export var rest_heal: float = 0.0
@export var rest_haste: bool = false
## 进边
@export var sunrise: float = 0.0
## 日出当作：耐力上限加多少（报告 390 起生命 ×3.5、耐力 ×2，两样分开写）
@export var sunrise_stamina: float = 0.0
@export var dawn_armor: float = 0.0
@export var dusk_stamina: float = 0.0
## 星移斗转：开战时带着几层、每层几成、拿了没有
@export var shift_on: bool = false
@export var shift_start: int = 0
@export var shift_per: float = 1.0
## 永日不落 / 永夜难明（0 = 没拿）
@export var eternal_day: float = 0.0
@export var eternal_day_scorch: int = 0
@export var eternal_night: float = 0.0
@export var eternal_night_hp: int = 0
## 【夜幕】：黑夜时格挡值 +百分之几（作者 11-26 09:54，取代黑夜减伤）
@export var veil: float = 0.0
## 受伤前
@export var humble: float = 0.0

var _day_def: BuffDef = null
var _night_def: BuffDef = null
var _light_def: BuffDef = null
var _moon_def: BuffDef = null
var _shift_def: BuffDef = null
var _eternal_def: BuffDef = null


static func _load(id: StringName) -> BuffDef:
	var path := ContentPaths.asset_file("buffs", String(id))
	return load(path) as BuffDef if ResourceLoader.exists(path) else null


static func _own(id: StringName, mods: Array[StatModifier]) -> BuffDef:
	var base := _load(id)
	if base == null:
		return null
	var d := base.duplicate() as BuffDef
	d.mods = mods
	return d


func _defs() -> void:
	if _day_def != null:
		return
	_day_def = _own(DAY, [StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, 0.0), StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, 0.0)] as Array[StatModifier])
	var night_mods: Array[StatModifier] = [StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, 0.0), StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, 0.0)]
	if veil > 0.0:
		night_mods.append(StatModifier.make(BattleStats.BLOCK, StatModifier.Mode.MULT, veil))     # 【夜幕】（作者 11-26 09:54）：黑夜时盾的格挡值 +几成
	_night_def = _own(NIGHT, night_mods)
	_light_def = _load(SUN_LIGHT)
	_moon_def = _load(MOON_LIGHT)
	var sp := shift_per
	_shift_def = _own(SHIFT, BattleStats.all_stats_mods(sp))     # 396 第五节：所有属性
	_eternal_def = _own(ETERNAL, BattleStats.all_stats_mods(0.0))


#region 时间轴（纯函数：只看时刻）
const CLOCK := "sun_clock"
const CLOCK_KEYS: Array[String] = ["day_sec", "night_sec", "dusk_sec", "dawn_sec", "day_damage", "night_haste"]


## 开战那一下记进日志的时间轴参数（回放用 [method from_clock] 还原，不用再找规则）
func clock_payload() -> Dictionary:
	var out := {"effect": CLOCK, "eclipse_sun": eclipse_sun, "eclipse_moon": eclipse_moon}
	for k in CLOCK_KEYS:
		out[k] = float(get(k))
	return out


## 从日志里那一条还原出只用来算时间轴的一份
static func from_clock(payload: Dictionary) -> SunCycle:
	var c := SunCycle.new()
	for k in CLOCK_KEYS:
		if payload.has(k):
			c.set(k, float(payload[k]))
	c.eclipse_sun = bool(payload.get("eclipse_sun", false))
	c.eclipse_moon = bool(payload.get("eclipse_moon", false))
	return c


## 回放里找开战记下的那一条（没奉日神 = null）
static func clock_of(result: BattleResult) -> SunCycle:
	if result == null:
		return null
	for raw in result.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("effect", "")) == CLOCK:
			return from_clock(e.payload)
		if e.time > 0:
			break
	return null


## [param segs]（[method segments] 算到 [param cap] 秒）里 [param t] 秒那一段：{day, night, left: 离下一次变还有几秒（-1 = 不会变）, span: 这一段多长}
static func clock_at(segs: Array, t: float, cap: float) -> Dictionary:
	for seg in segs:
		if t < float(seg[1]) or seg == segs[-1]:
			var open_end := float(seg[1]) >= cap - 0.001
			return {"day": bool(seg[2]), "night": bool(seg[3]), "left": -1.0 if open_end else maxf(0.0, float(seg[1]) - t),
				"span": float(seg[1]) - float(seg[0])}
	return {"day": true, "night": false, "left": -1.0, "span": 0.0}


## 算多远才够看出「会不会变」：整场再加一个日夜来回
func horizon(duration: float) -> float:
	return duration + maxf(0.0, day_sec) + maxf(0.0, night_sec) + 1.0


## [0, [param until]] 秒里的各段：[[起, 止, 白昼?, 黑夜?], ...]（相邻同状态并成一段）
func segments(until: float) -> Array:
	var out: Array = []
	var end := StatMath.from_float(until)
	var t := 0
	while t < end:
		var nxt := mini(next_boundary(t), end)
		var s := states_at(t)
		if not out.is_empty() and bool(out[-1][2]) == (s.x == 1) and bool(out[-1][3]) == (s.y == 1):
			out[-1][1] = StatMath.to_float(nxt)
		else:
			out.append([StatMath.to_float(t), StatMath.to_float(nxt), s.x == 1, s.y == 1])
		t = nxt
	return out

## [param t]（定点）时在第几个阶段、是不是白昼阶段、进这个阶段多久了、这个阶段几时结束（-1 = 不会结束）
func phase_at(t: int) -> Dictionary:
	var d := StatMath.from_float(maxf(0.0, day_sec))
	var n := StatMath.from_float(maxf(0.0, night_sec))
	if n <= 0:
		return {"day": true, "into": t, "index": 0, "end": -1, "start": 0}
	if d <= 0:
		return {"day": false, "into": t, "index": 0, "end": -1, "start": 0}
	@warning_ignore("integer_division")
	var k := t / (d + n)
	var rest := t - k * (d + n)
	var base := k * (d + n)
	if rest < d:
		return {"day": true, "into": rest, "index": k * 2, "end": base + d, "start": base}
	return {"day": false, "into": rest - d, "index": k * 2 + 1, "end": base + d + n, "start": base + d}


## [param t] 时算不算白昼 / 黑夜（「同时视为」都算上）
func states_at(t: int) -> Vector2i:
	var p := phase_at(t)
	var into := int(p["into"])
	var is_day := bool(p["day"])
	var day := is_day or (eclipse_moon and not is_day) or (not is_day and dusk_sec > 0.0 and int(p["index"]) > 0 and into < StatMath.from_float(dusk_sec))
	var night := (not is_day) or (eclipse_sun and is_day) or (is_day and dawn_sec > 0.0 and int(p["index"]) > 0 and into < StatMath.from_float(dawn_sec))
	return Vector2i(1 if day else 0, 1 if night else 0)


## 现在之后下一个要结算的时刻：阶段起止、残阳 / 斜月的尾巴、下一整秒
func next_boundary(now: int) -> int:
	@warning_ignore("integer_division")
	var best := (now / StatMath.ONE + 1) * StatMath.ONE
	var p := phase_at(now)
	var end := int(p["end"])
	if end > now:
		best = mini(best, end)
	var start := int(p["start"])
	for tail in [dusk_sec, dawn_sec]:
		if float(tail) > 0.0:
			var at := start + StatMath.from_float(float(tail))
			if at > now:
				best = mini(best, at)
	return best


## [param from] 起，黑夜状态到哪一刻结束（一直是黑夜 = [param cap]）
func night_ends(from: int, cap: int) -> int:
	var t := from
	while t < cap:
		t = next_boundary(t)
		if states_at(t).y == 0:
			return t
	return cap
#endregion


func apply(ctx: RuleContext) -> void:
	if ctx.owner == null or ctx.owner.dead:
		return
	_defs()
	var e := ctx.event
	if e == null:
		_tick(ctx)
	elif e.name == BattleEvent.BEFORE_DAMAGE:
		_before(ctx)
	elif e.name == BattleEvent.BATTLE_START:
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, clock_payload())     # 回放的日月盘、色带照它重算时间轴
		_tick(ctx)


func _tick(ctx: RuleContext) -> void:
	var st := ctx.state()
	var now := ctx.battle.now
	var me := ctx.owner
	if not st.has("init"):
		st["init"] = true
		if shift_on and shift_start > 0 and _shift_def != null:
			ApplyStatus.give(ctx, me, _shift_def, shift_start)
	var s := states_at(now)
	var was := Vector2i(int(st.get("day", 0)), int(st.get("night", 0)))
	var phase := int(phase_at(now)["index"])
	if int(st.get("phase", 0)) != phase:
		st["phase"] = phase
		st["ramp_secs"] = 0
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "sun_window", "count": 1})
		if shift_on and _shift_def != null:
			ApplyStatus.give(ctx, me, _shift_def, 1)
	# 每一整秒（第 0 秒不算）
	@warning_ignore("integer_division")
	var sec := now / StatMath.ONE
	if now > 0 and now % StatMath.ONE == 0 and int(st.get("sec", 0)) != sec:
		st["sec"] = sec
		_per_second(ctx, st, Vector2i(was.x, was.y))
	if s.x == 1 and was.x == 0:
		_enter_day(ctx)
	if s.y == 1 and was.y == 0:
		_enter_night(ctx, now)
	st["day"] = s.x
	st["night"] = s.y
	_sync(ctx, st, s)


## 每一秒：按刚过去这一秒的状态结算（[param s]）
func _per_second(ctx: RuleContext, st: Dictionary, s: Vector2i) -> void:
	var me := ctx.owner
	var foe := ctx.opponent()
	if sun_light > 0 and _light_def != null:
		_bump(ctx, me, _light_def, sun_light if s.x == 1 else -1)
	if moon_light > 0 and _moon_def != null:
		_bump(ctx, me, _moon_def, moon_light if s.y == 1 else -1)
	if foe != null and not foe.dead:
		if burn > 0 and s.x == 1:
			_give(ctx, foe, SCORCH, burn)
		if frost > 0 and s.y == 1:
			_give(ctx, foe, CHILL, frost)
	st["ramp_secs"] = int(st.get("ramp_secs", 0)) + 1
	@warning_ignore("integer_division")
	var p := phase_at(ctx.battle.now - StatMath.ONE / 2)
	if dusk_ramp > 0.0 and not bool(p["day"]) and s.x == 1:
		st["dusk_acc"] = float(st.get("dusk_acc", 0.0)) + dusk_ramp
	if dawn_ramp > 0.0 and bool(p["day"]) and s.y == 1:
		st["dawn_acc"] = float(st.get("dawn_acc", 0.0)) + dawn_ramp
	if rest_heal > 0.0 and s.y == 1:
		var amount := StatMath.mul(me.resources.maximum(BattleStats.RES_HP), StatMath.from_float(rest_heal / 100.0))
		if rest_haste:
			amount = StatMath.mul(amount, maxi(1, me.stat(BattleStats.HASTE, StatMath.ONE)))
		me.heal(ctx.battle, amount)
	if eternal_day > 0.0 and s.x == 1 and eternal_day_scorch > 0:
		_give(ctx, me, SCORCH, eternal_day_scorch)
		if foe != null and not foe.dead:
			_give(ctx, foe, SCORCH, eternal_day_scorch)
	if eternal_night > 0.0 and s.y == 1 and eternal_night_hp > 0:
		for who in [me, foe]:
			if who != null and not (who as CombatantRuntime).dead:
				(who as CombatantRuntime).add_max(BattleStats.RES_HP, -StatMath.from_float(eternal_night_hp), StatMath.ONE)


func _give(ctx: RuleContext, who: CombatantRuntime, id: StringName, n: int) -> void:
	var d := _load(id)
	if d != null and n > 0:
		ApplyStatus.give(ctx, who, d, n)


func _bump(ctx: RuleContext, who: CombatantRuntime, def: BuffDef, delta: int) -> void:
	if delta > 0:
		ApplyStatus.give(ctx, who, def, delta)
	elif delta < 0 and who.stacks_of(def.id) > 0:
		RemoveStatus.take(ctx, who, def.id, -delta, "faded")


func _enter_day(ctx: RuleContext) -> void:
	var me := ctx.owner
	var res := me.resources
	if sunrise > 0.0:
		var add := StatMath.from_float(sunrise)
		me.add_max(BattleStats.RES_HP, add)
	if sunrise_stamina > 0.0 and res.has(BattleStats.RES_STAMINA):
		var add_st := StatMath.from_float(sunrise_stamina)
		me.add_max(BattleStats.RES_STAMINA, add_st)
	if dawn_armor > 0.0:
		me.restore_armor(dawn_armor)     # 【黎明】（作者 11-26 09:54）：回复身上防具护甲上限的几成，没穿防具就没有


func _enter_night(ctx: RuleContext, now: int) -> void:
	var me := ctx.owner
	var res := me.resources
	if dusk_stamina > 0.0 and res.has(BattleStats.RES_STAMINA):
		res.change(BattleStats.RES_STAMINA, StatMath.mul(res.maximum(BattleStats.RES_STAMINA), StatMath.from_float(dusk_stamina / 100.0)), BattleEvent.REASON_HEAL)
	if rest_heal > 0.0:
		# 日落当息：武器停表 —— 排好的出手时刻整体往后挪一个黑夜（弹出来时不到点，按新时刻重排）
		var cap := StatMath.from_float(BattleSim.DEFAULT_TIME_LIMIT)
		var shift := night_ends(now, cap) - now
		for rt in me.rules:
			var r := rt as RuleRuntime
			if r.source_uid == 0 or r.buff != null or r.rule == null or not (r.rule.trigger is OnSchedule) or not (r.rule.cadence is CooldownCadence):
				continue
			var rst := RuleContext.create(ctx.battle, me, r).state()
			if rst.has(CooldownCadence.READY_AT):
				rst[CooldownCadence.READY_AT] = int(rst[CooldownCadence.READY_AT]) + shift


## 身上的【白昼】/【黑夜】跟着状态走，加成按牌和攒的增效算
func _sync(ctx: RuleContext, st: Dictionary, s: Vector2i) -> void:
	var me := ctx.owner
	var r_secs := float(st.get("ramp_secs", 0))
	if _day_def != null:
		_day_def.mods[0].amount = (day_damage + eclipse_moon_damage) * (1.0 + float(st.get("dusk_acc", 0.0)) / 100.0)
		_day_def.mods[1].amount = ramp * r_secs
	if _night_def != null:
		_night_def.mods[0].amount = (night_haste + eclipse_sun_haste) * (1.0 + float(st.get("dawn_acc", 0.0)) / 100.0)
		_night_def.mods[1].amount = ramp * r_secs
	_hold(ctx, me, _day_def, s.x == 1)
	_hold(ctx, me, _night_def, s.y == 1)
	if _eternal_def != null and (eternal_day > 0.0 or eternal_night > 0.0):
		var foe := ctx.opponent()
		if eternal_day > 0.0:
			BattleStats.set_all_stats(_eternal_def.mods, eternal_day)
			_hold(ctx, me, _eternal_def, s.x == 1)
		elif foe != null:
			BattleStats.set_all_stats(_eternal_def.mods, -eternal_night)
			_hold(ctx, foe, _eternal_def, s.y == 1)
	me.mark_dirty()


func _hold(ctx: RuleContext, who: CombatantRuntime, def: BuffDef, on: bool) -> void:
	if def == null:
		return
	var have := who.stacks_of(def.id) > 0
	if on and not have:
		ApplyStatus.give(ctx, who, def, 1)
	elif not on and have:
		RemoveStatus.take(ctx, who, def.id, who.stacks_of(def.id), "faded")
	elif on:
		who.mark_dirty()


func _before(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or p.pure:
		return
	var me := ctx.owner
	if p.victim == me:
		var pct := humble
		if pct > 0.0:
			p.add_percent(-StatMath.from_float(minf(100.0, pct) / 100.0))
	elif p.source_side == me.side and humble > 0.0:
		p.add_percent(-StatMath.from_float(minf(100.0, humble) / 100.0))


func describe() -> String:
	return UiText.t("fx.sun_cycle") % [TextTemplate.num(day_sec), TextTemplate.num(night_sec), TextTemplate.num(day_damage), TextTemplate.num(night_haste)]
