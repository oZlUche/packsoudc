## 信仰重构 D（交接方案 §6.3）：自然之神「恢复存量」。一条规则（[FaithMechanicTrigger] 听资源变化、伤害、加时，另按 [FaithPulseCadence] 打节拍）放整套：
##
## - 自启动：每个节拍（默认从第 2 秒起每 4 秒）恢复最大生命 [member pulse_percent]%。
## - 实际回上来的生命（治疗与每秒回血）的 [member store_percent]% 存进【生息】，容量是最大生命的 [member cap_percent]%；
##   生息自己放出来的那口治疗不再存（[code]skip[/code] 记着）。层数 = 存着的整点生命。
## - 一阶：生命低于 [member low_percent]% 时放出生息治疗（最多补到满，按实际回了多少扣），两次至少隔 [member release_gap_sec] 秒。
## - 二阶：棋盘上每件有效食物容量 +[member food_percent]%，最多算 [member food_cap] 件（件数由 perk 编译时数好放进 [member food]）。
## - 三阶：进加时的第一下给【守护】（短时减伤，buff 自己定时长与轴），一场一次。
## 一场里有效治疗到最大生命的 [member heal_mark]%、放出过生息，各记一次（`faith_mechanic`）；没满血时的每次节拍也写一句（`nature_pulse`）
class_name NatureRegrowth
extends CombatEffect

const BUFF_ID := &"nature_regrowth"
const GUARD_ID := &"nature_guard"

@export var tier: int = 0
@export var pulse_percent: int = 2
@export var store_percent: int = 20
@export var cap_percent: int = 15
@export var low_percent: int = 50
@export var release_gap_sec: float = 6.0
@export var food_percent: int = 2
@export var food_cap: int = 3
@export var food: int = 0
@export var heal_mark: int = 10

static var _buffs: Dictionary = {}


static func buff_of(id: StringName) -> BuffDef:
	if not _buffs.has(id):
		var path := ContentPaths.asset_file("buffs", String(id))
		_buffs[id] = load(path) as BuffDef if ResourceLoader.exists(path) else null
	return _buffs[id]


func apply(ctx: RuleContext) -> void:
	var me := ctx.owner
	if me == null or me.dead:
		return
	var e := ctx.event
	if e == null:
		var hp_max := me.resources.maximum(BattleStats.RES_HP)
		if pulse_percent > 0 and hp_max > 0 and me.resources.current(BattleStats.RES_HP) < hp_max:
			# 游戏测试 11-19：周期治疗以前只留一行没来由的「恢复」，战记里看不出是自然；先写一句，紧跟的恢复行就归到它
			ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "nature_pulse"})
			me.heal(ctx.battle, StatMath.mul(hp_max, StatMath.from_percent(pulse_percent)))
		_try_release(ctx)
		return
	match e.name:
		BattleEvent.RESOURCE_CHANGED:
			if e.side == me.side and String(e.payload.get("key", "")) == String(BattleStats.RES_HP):
				var reason := String(e.payload.get("reason", ""))
				if reason == String(BattleEvent.REASON_HEAL) or reason == String(BattleEvent.REASON_REGEN):
					_store(ctx, e.get_int(&"delta"))
		BattleEvent.DAMAGE:
			if e.side == me.side:
				_try_release(ctx)
		BattleEvent.OVERTIME_STACKED:
			var st := ctx.state()
			if tier >= 3 and not bool(st.get("guarded", false)) and buff_of(GUARD_ID) != null:
				st["guarded"] = true
				ApplyStatus.give(ctx, me, buff_of(GUARD_ID), 1)
				ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "nature_guard"})


## 容量（定点生命）
func capacity(me: CombatantRuntime) -> int:
	var pct := cap_percent + (food_percent * mini(food, food_cap) if tier >= 2 else 0)
	return StatMath.mul(me.resources.maximum(BattleStats.RES_HP), StatMath.from_percent(pct))


func _store(ctx: RuleContext, delta: int) -> void:
	if delta <= 0:
		return
	var st := ctx.state()
	var skip := int(st.get("skip", 0))
	if skip > 0:
		var used := mini(skip, delta)
		st["skip"] = skip - used
		delta -= used
		if delta <= 0:
			return
	var me := ctx.owner
	var healed := int(st.get("healed", 0)) + delta
	st["healed"] = healed
	if not bool(st.get("heal_done", false)) and healed * 100 >= me.resources.maximum(BattleStats.RES_HP) * heal_mark:
		st["heal_done"] = true
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "nature_heal"})
	st["stored"] = mini(capacity(me), int(st.get("stored", 0)) + StatMath.mul(delta, StatMath.from_percent(store_percent)))
	_show(ctx)


func _try_release(ctx: RuleContext) -> void:
	if tier < 1:
		return
	var me := ctx.owner
	var st := ctx.state()
	var stored := int(st.get("stored", 0))
	var hp := me.resources.current(BattleStats.RES_HP)
	var hp_max := me.resources.maximum(BattleStats.RES_HP)
	if stored < StatMath.ONE or hp <= 0 or hp * 100 >= hp_max * low_percent:
		return
	var last := int(st.get("released_at", -1))
	if last >= 0 and ctx.battle.now - last < StatMath.from_float(release_gap_sec):
		return
	var want := mini(stored, hp_max - hp)
	st["skip"] = int(st.get("skip", 0)) + want     # 先记下：这口治疗的资源变化事件随后才到
	var got := me.heal(ctx.battle, want)
	st["skip"] = int(st["skip"]) - (want - got)
	if got <= 0:
		return
	st["released_at"] = ctx.battle.now
	st["stored"] = stored - got
	_show(ctx)
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "nature_release", "count": maxi(1, floori(StatMath.to_float(got)))})


## 生息层数跟着存量（整点）走
func _show(ctx: RuleContext) -> void:
	var def := buff_of(BUFF_ID)
	if def == null:
		return
	var want := floori(StatMath.to_float(int(ctx.state().get("stored", 0))))
	var have := ctx.owner.stacks_of(BUFF_ID)
	if want > have:
		ApplyStatus.give(ctx, ctx.owner, def, want - have)
	elif want < have:
		RemoveStatus.take(ctx, ctx.owner, BUFF_ID, have - want, "spent")


func describe() -> String:
	return UiText.t("fx.nature_regrowth") % [store_percent, cap_percent]
