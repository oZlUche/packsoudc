## 信仰重构 D（交接方案 §6.2）：日神「周期」。一条规则（[FaithMechanicTrigger] 听出手、伤害，另按 [FaithPulseCadence] 打节拍）放整套：
##
## - 烈日窗口：从第 [member first_sec] 秒起每 [member every_sec] 秒开一次，开 [member window_sec] 秒，半开区间 [开, 开 + 长)。
##   在不在窗口只按战斗时间算（[method window_at]），节拍只负责写战记「烈日开始 / 结束」。
## - 窗口内每件武器最多一次：这一下直接伤害之后追加 [member fire_percent]% 的火焰伤害（来源是 0，不再引发追加）。
## - 一阶：窗口外的原始出手给下一个窗口蓄力，全单位最多 [member charge_cap] 次，每次 +[member charge_percent]%；开窗时结算并清零。
## - 三阶：每第 [member strong_every] 个窗口的追加 ×[member strong_mult]。
## 有追加的窗口记一次（`faith_mechanic` / `sun_window`），信力按它给
class_name SunCycle
extends CombatEffect

@export var tier: int = 0
@export var first_sec: float = 6.0
@export var every_sec: float = 6.0
@export var window_sec: float = 2.0
@export var fire_percent: int = 20
@export var charge_cap: int = 3
@export var charge_percent: int = 10
@export var strong_every: int = 3
@export var strong_mult: float = 1.5


## [param now] 时刻在第几个窗口里（从 1 数）；不在窗口里 = 0
func window_at(now: int) -> int:
	var first := StatMath.from_float(first_sec)
	var every := StatMath.from_float(every_sec)
	if every <= 0 or now < first:
		return 0
	@warning_ignore("integer_division")
	var k := (now - first) / every
	return k + 1 if now - first - k * every < StatMath.from_float(window_sec) else 0


func apply(ctx: RuleContext) -> void:
	if ctx.owner == null or ctx.owner.dead:
		return
	var e := ctx.event
	var k := _sync(ctx)
	if e == null:
		_pulse(ctx, k)
		return
	match e.name:
		BattleEvent.ITEM_FIRED:
			if k == 0 and tier >= 1 and e.side == ctx.owner.side and not e.payload.has(RuleEngine.CHAIN) \
					and SkillMomentum.is_attack(SkillMomentum.category_of(ctx.owner.tags_of(e.get_int(&"uid")))):
				var st := ctx.state()
				st["charge"] = mini(charge_cap, int(st.get("charge", 0)) + 1)
		BattleEvent.DAMAGE:
			if k > 0:
				_strike(ctx, e, k)


## 进了新窗口就结算蓄力（不管是节拍先到还是出手先到，只结算一次）。返回当前窗口号
func _sync(ctx: RuleContext) -> int:
	var k := window_at(ctx.battle.now)
	var st := ctx.state()
	if k > 0 and k != int(st.get("k", 0)):
		st["k"] = k
		st["used"] = {}
		st["bonus"] = int(st.get("charge", 0)) * charge_percent if tier >= 1 else 0
		st["charge"] = 0
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "sun_open", "count": k})
	return k


## 节拍：窗口刚关的那一下写「烈日结束」
func _pulse(ctx: RuleContext, k: int) -> void:
	var st := ctx.state()
	var opened := int(st.get("k", 0))
	if k == 0 and opened > 0 and int(st.get("closed", 0)) != opened:
		st["closed"] = opened
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "sun_close", "count": opened})


func _strike(ctx: RuleContext, e: BattleEvent, k: int) -> void:
	var me := ctx.owner
	if e.get_int(&"source_side", -1) != me.side or e.side == me.side or not e.get_bool(&"direct") or e.get_bool(&"cancelled"):
		return
	var uid := e.get_int(&"uid")
	var amount := e.get_int(&"amount")
	if uid == 0 or amount <= 0 or not SkillMomentum.is_attack(SkillMomentum.category_of(me.tags_of(uid))):
		return
	var st := ctx.state()
	var used: Dictionary = st.get("used", {})
	if used.has(uid):
		return
	used[uid] = true
	st["used"] = used
	var foe := ctx.opponent()
	if foe == null or foe.dead:
		return
	var raw := StatMath.mul(amount, StatMath.from_percent(fire_percent + int(st.get("bonus", 0))))
	if tier >= 3 and strong_every > 0 and k % strong_every == 0:
		raw = StatMath.mul(raw, StatMath.from_float(strong_mult))
	if int(st.get("scored", 0)) != k:
		st["scored"] = k
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "sun_window"})
	if raw > 0:
		DamageResolver.deal(ctx.battle, foe, raw, DamageTypes.FIRE, me.side, 0, false)


func describe() -> String:
	return UiText.t("fx.sun_cycle") % [TextTemplate.num(every_sec), TextTemplate.num(window_sec), fire_percent]
