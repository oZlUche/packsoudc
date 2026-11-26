## 388 第 3 批（作者牌表 11-24）：自然之神的【枯萎】/【新生】与自然之神的牌在战斗里的那一半。一条规则（[FaithMechanicTrigger] 听伤害、资源变化，
## 另按 [FaithPulseCadence] 每秒一拍）放整套，数由 [NatureCyclePerk] 编译时按拿了哪些牌填好。
##
## - 核心：敌人每失去 1 点生命（持续伤害也算）敌人身上 +1 层【枯萎】；我每回 1 点生命（每秒回复也算）我身上 +1 层【新生】。
## - 凋零：敌人每得一层枯萎，生命上限少 [member decay_percent]% 层。轮回：自己积的新生每 [member cycle_every] 层给敌人 [member cycle_stacks] 层枯萎，反过来也一样（互给的不再算）。
## - 护佑：每 [member guard_every] 秒清空新生，按层数的 [member guard_percent]% 给护甲。收割：第 [member harvest_at] 秒给敌人枯萎 [member harvest_percent]% 层的【收割】，敌人生命不高于它就死。
## - 丰饶：溢出的治疗加成等量的生命上限（【丰饶】的层数 = 加了几点，战后升级版按它留一半）。
## - 回春 / 毒气：每 2 秒给自己【回春】（生命回复轴）/ 给敌人【中毒】。求生本能：生命第一次低于一半时回最大生命的几成。
## 一场里新生到最大生命的 [member heal_mark]%、枯萎到敌人最大生命的 [member heal_mark]%，各记一次（`faith_mechanic`，经验值按它给）
class_name NatureCycle
extends CombatEffect

const WITHER := &"nature_wither"
const RENEWAL := &"nature_renewal"
const HARVEST := &"nature_harvest"
const BOUNTY := &"nature_bounty"
const POISON := &"poison"
const STEP := 1.0

@export var heal_mark: int = 10
## 凋零（0 = 没拿）
@export var decay_percent: float = 0.0
## 轮回（0 = 没拿）
@export var cycle_every: int = 5
@export var cycle_stacks: int = 0
## 护佑（0 = 没拿）
@export var guard_every: float = 0.0
@export var guard_percent: float = 0.0
## 护佑（升级，报告 399 第六节）：每次消耗新生的百分之几（向下取整，剩下的留给生长、收获），每消耗 1 层给几点护甲（0 = 按 [member guard_percent]）
@export var guard_share: float = 100.0
@export var guard_per: float = 0.0
## 收割（0 = 没拿）
@export var harvest_at: float = 0.0
@export var harvest_percent: float = 0.0
## 丰饶
@export var bounty: bool = false
## 回春 / 毒气：每几秒、每次几层（0 = 没拿）
@export var every_sec: float = 2.0
@export var rejuv: int = 0
@export var poison: int = 0
## 求生本能：低于几成、回几成（0 = 没拿）
@export var survive_below: float = 50.0
@export var survive_percent: float = 0.0

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
		_tick(ctx)
		return
	var foe := ctx.opponent()
	match e.name:
		BattleEvent.DAMAGE:
			if foe != null and e.side == foe.side and not e.get_bool(&"cancelled"):
				_gain_wither(ctx, maxi(0, e.get_int(&"amount")), true)
				_reap(ctx)
			elif e.side == me.side:
				_survive(ctx)
		BattleEvent.RESOURCE_CHANGED:
			if e.side == me.side and String(e.payload.get("key", "")) == String(BattleStats.RES_HP):
				var reason := String(e.payload.get("reason", ""))
				if reason == String(BattleEvent.REASON_HEAL) or reason == String(BattleEvent.REASON_REGEN):
					_gain_renewal(ctx, e.get_int(&"delta"), true)
					_bounty(ctx)


#region 积
## 敌人失去 [param amount]（定点）生命；[param natural] 假 = 轮回给的（不再回给新生）
func _gain_wither(ctx: RuleContext, amount: int, natural: bool) -> void:
	if amount <= 0:
		return
	var st := ctx.state()
	var before := floori(StatMath.to_float(int(st.get("w_pts", 0))))
	st["w_pts"] = int(st.get("w_pts", 0)) + amount
	var gained := floori(StatMath.to_float(int(st["w_pts"]))) - before
	if gained <= 0:
		return
	st["wither"] = int(st.get("wither", 0)) + gained
	var foe := ctx.opponent()
	if decay_percent > 0.0 and foe != null and not foe.dead:
		var cut := StatMath.from_float(gained * decay_percent / 100.0)
		foe.add_max(BattleStats.RES_HP, -cut, StatMath.ONE)
	if natural and cycle_stacks > 0:
		st["w_nat"] = int(st.get("w_nat", 0)) + gained
		@warning_ignore("integer_division")
		var owed := int(st["w_nat"]) / maxi(1, cycle_every) * cycle_stacks - int(st.get("w_paid", 0))
		if owed > 0:
			st["w_paid"] = int(st.get("w_paid", 0)) + owed
			_gain_renewal(ctx, owed * StatMath.ONE, false)
	_mark(ctx, "nature_wither", int(st["wither"]), foe)
	_show(ctx)


## 我回了 [param amount]（定点）生命
func _gain_renewal(ctx: RuleContext, amount: int, natural: bool) -> void:
	if amount <= 0:
		return
	var st := ctx.state()
	var before := floori(StatMath.to_float(int(st.get("r_pts", 0))))
	st["r_pts"] = int(st.get("r_pts", 0)) + amount
	var gained := floori(StatMath.to_float(int(st["r_pts"]))) - before
	if gained <= 0:
		return
	st["renewal"] = int(st.get("renewal", 0)) + gained
	if natural and cycle_stacks > 0:
		st["r_nat"] = int(st.get("r_nat", 0)) + gained
		@warning_ignore("integer_division")
		var owed := int(st["r_nat"]) / maxi(1, cycle_every) * cycle_stacks - int(st.get("r_paid", 0))
		if owed > 0:
			st["r_paid"] = int(st.get("r_paid", 0)) + owed
			_gain_wither(ctx, owed * StatMath.ONE, false)
	_mark(ctx, "nature_heal", int(st.get("r_total", 0)) + gained, ctx.owner)
	st["r_total"] = int(st.get("r_total", 0)) + gained
	_show(ctx)


## 到最大生命的 [member heal_mark]% 记一次（经验值）
func _mark(ctx: RuleContext, key: String, total: int, who: CombatantRuntime) -> void:
	var st := ctx.state()
	if who == null or bool(st.get(key + "_done", false)):
		return
	if total * 100 * StatMath.ONE >= who.resources.maximum(BattleStats.RES_HP) * heal_mark:
		st[key + "_done"] = true
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": key})
#endregion


#region 节拍
func _tick(ctx: RuleContext) -> void:
	var st := ctx.state()
	var me := ctx.owner
	var foe := ctx.opponent()
	@warning_ignore("integer_division")
	var sec := ctx.battle.now / StatMath.ONE
	st["sec"] = sec
	var every := maxi(1, roundi(every_sec))
	if sec > 0 and sec % every == 0:
		if rejuv > 0:
			ShiftAxis.shift(ctx.battle, me, StatAxes.REGEN_HP, rejuv, false)     # 【回春】就是生命回复轴的正向
		if poison > 0 and foe != null and not foe.dead and buff_of(POISON) != null:
			ApplyStatus.give(ctx, foe, buff_of(POISON), poison)
	if guard_every > 0.0 and sec > 0 and sec % maxi(1, roundi(guard_every)) == 0:
		var n := floori(int(st.get("renewal", 0)) * guard_share / 100.0)
		if n > 0:
			st["renewal"] = int(st.get("renewal", 0)) - n
			var gain := StatMath.from_float(n * guard_per if guard_per > 0.0 else n * guard_percent / 100.0)
			if gain > 0:
				me.add_max(BattleStats.RES_ARMOR, gain)
			ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "nature_guard_armor", "count": n})
	if harvest_at > 0.0 and not st.has("harvest") and sec >= roundi(harvest_at) and foe != null and not foe.dead:
		st["harvest"] = floori(int(st.get("wither", 0)) * harvest_percent / 100.0)
		_reap(ctx)
	_bounty(ctx)
	_show(ctx)


## 收割：敌人生命不高于【收割】层数就死
func _reap(ctx: RuleContext) -> void:
	var st := ctx.state()
	var foe := ctx.opponent()
	var n := int(st.get("harvest", 0))
	if n <= 0 or foe == null or foe.dead:
		return
	var hp := foe.resources.current(BattleStats.RES_HP)
	if hp > 0 and hp <= n * StatMath.ONE:
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "nature_reap"})
		var p := DamagePacket.create(DamageTypes.PHYSICAL, hp, foe, ctx.owner.side, 0, false)
		p.pure = true
		DamageResolver.resolve(ctx.battle, p)


## 丰饶：溢出的治疗 → 等量的生命上限
func _bounty(ctx: RuleContext) -> void:
	if not bounty:
		return
	var st := ctx.state()
	var res := ctx.owner.resources
	var spilled := int(res.overflow.get(BattleStats.RES_HP, 0))
	var used := int(st.get("spilled", 0))
	if spilled <= used:
		return
	st["spilled"] = spilled
	var add := spilled - used
	ctx.owner.add_max(BattleStats.RES_HP, add)
	st["bounty_pts"] = int(st.get("bounty_pts", 0)) + add


## 求生本能：第一次低于一半
func _survive(ctx: RuleContext) -> void:
	if survive_percent <= 0.0:
		return
	var st := ctx.state()
	if bool(st.get("survived", false)):
		return
	var me := ctx.owner
	var hp := me.resources.current(BattleStats.RES_HP)
	var hp_max := me.resources.maximum(BattleStats.RES_HP)
	if hp <= 0 or float(hp) * 100.0 >= float(hp_max) * survive_below:
		return
	st["survived"] = true
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "nature_survive"})
	me.heal(ctx.battle, StatMath.mul(hp_max, StatMath.from_float(survive_percent / 100.0)))
#endregion


## 身上的层数跟着记的数走
func _show(ctx: RuleContext) -> void:
	var st := ctx.state()
	var foe := ctx.opponent()
	_hold(ctx, ctx.owner, RENEWAL, int(st.get("renewal", 0)))
	_hold(ctx, ctx.owner, BOUNTY, floori(StatMath.to_float(int(st.get("bounty_pts", 0)))))
	if foe != null and not foe.dead:
		_hold(ctx, foe, WITHER, int(st.get("wither", 0)))
		_hold(ctx, foe, HARVEST, int(st.get("harvest", 0)))


func _hold(ctx: RuleContext, who: CombatantRuntime, id: StringName, want: int) -> void:
	var def := buff_of(id)
	if def == null:
		return
	var have := who.stacks_of(id)
	if want > have:
		ApplyStatus.give(ctx, who, def, want - have)
	elif want < have:
		RemoveStatus.take(ctx, who, id, have - want, "spent")


func describe() -> String:
	return UiText.t("fx.nature_cycle")
