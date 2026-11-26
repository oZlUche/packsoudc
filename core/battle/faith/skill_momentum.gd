## 396 第 B 批（作者牌表 11-25「技巧之神」）：技巧之神的【连击】与技巧之神的牌在战斗里的那一半。一条规则（[FaithMechanicTrigger] 听开战、
## 受伤前、伤害、出手、出手没付起，另按 [member STEP] 秒打节拍）放整套，数由 [SkillMomentumPerk] 编译时按拿了哪些牌填好。
##
## - 核心：我方武器每出手一次（额外攻击也算）叠 1 层【连击】，每层急速 +[member haste_per]%，不封顶；
##   有一下因为耐力（消耗）不够没出手（[constant BattleEvent.ITEM_SKIPPED]），清零（【稳手】留几层）。
## - 往上堆：【寻隙】每累积几层，下一次攻击穿透护甲并增伤；【破势】每次攻击附带层数几成的固定伤害；【锋芒】每层暴击率（升级另有暴击伤害）；
##   【以攻待守】至少几层时每次受到的伤害减固定几点（可以减到 0，减到 0 算挡住）；【气功】每几次攻击，下一次给敌人附几层随机元素；
##   【识破】每层无视 1 点固定减伤（受伤前的固定减伤、格挡）；【招架】每累积 10 层给护甲；【行云】至少 10 层时武器耐力消耗降低；
##   【流水】每叠一层另给一份急速，清零不掉；【蓄势】每几秒暴击率一层，暴击时清掉。
## - 清零时：【残心】随机几件武器额外攻击一次（不耗耐力、不动倒计时）；【大巧若拙】按层数几成打真实伤害；【回气】【气血】按层数回耐力、生命。
## - 【架势】：受到的一下直接伤害被护甲、格挡、固定减伤完全挡住（没掉血），叠几层。
## - 【化刚为巧】：暴击不再加伤害，改为再打一下原本伤害的几成（[member CombatantRuntime.crit_plain]）。
## - 开战给【预备】那几层、加上一场带过来的（【一气呵成】，[member carry_in]）。
## 叠连击写战记 `faith_mechanic` / `skill_momentum`（战后的经验值按 buff 层数数，见 [MechanicDeed]）
class_name SkillMomentum
extends CombatEffect

const BUFF_ID := &"skill_momentum"
const FLOW_ID := &"skill_flow"
const POISE_ID := &"skill_poise"
const LIGHT_ID := &"skill_light"
## 战记里写的那一句（[BattleNarrator] 认 `faith_mechanic` + key）
const MECHANIC := "faith_mechanic"
const STEP := 0.2
## 【气功】随机的元素
const ELEMENTS: Array[StringName] = [&"scorch", &"chill", &"poison", &"numb"]

@export var haste_per: float = 1.0
## 开战给几层（预备）
@export var opening: int = 0
## 上一场带过来几层（一气呵成，编译时按存档填）
@export var carry_in: int = 0
## 清零时留几层（稳手）
@export var keep_on_reset: int = 0
## 流水：每叠一层另给的急速（百分数，0 = 没拿）
@export var flow_per: float = 0.0
## 行云：至少几层时武器耐力消耗降低几成（百分数，0 = 没拿）
@export var light_at: int = 10
@export var light_pct: float = 0.0
## 招架：每累积几层给几点护甲（0 = 没拿）
@export var parry_every: int = 10
## 【招架】（作者 11-26 09:54）：回复身上防具护甲上限的百分之几
@export var parry_pct: float = 0.0
## 回气、气血：清零时每层回几点
@export var breath_per: float = 0.0
@export var vigor_per: float = 0.0
## 蓄势：每几秒暴击率一层、一层几成（百分数，0 = 没拿）
@export var poise_sec: float = 3.0
@export var poise_pct: float = 0.0
## 识破：每层无视几点固定减伤
@export var see_per: float = 0.0
## 寻隙：每累积几层（0 = 没拿），下一次攻击增伤几成并穿透护甲
@export var gap_every: int = 0
@export var gap_pct: float = 0.0
## 架势：完全挡住一下时叠几层（0 = 没拿）
@export var stance: int = 0
## 残心：清零时几件武器额外攻击（0 = 没拿）
@export var zanshin: int = 0
## 破势：每次攻击附带层数几成的固定伤害（百分数）
@export var press_pct: float = 0.0
## 以攻待守：至少几层时每次受到的伤害减几点
@export var guard_at: int = 30
@export var guard_flat: float = 0.0
## 气功：每几次攻击（0 = 没拿），下一次附几层随机元素
@export var qigong_every: int = 0
@export var qigong_stacks: int = 0
## 锋芒：每层暴击率、暴击伤害（百分数）
@export var edge_crit: float = 0.0
@export var edge_crit_damage: float = 0.0
## 大巧若拙：清零时按层数几成打真实伤害（百分数）
@export var clumsy_pct: float = 0.0
## 化刚为巧：暴击改为再打一下原本伤害的几成（百分数，0 = 没拿）
@export var soft_pct: float = 0.0

var _def: BuffDef = null
var _flow_def: BuffDef = null
var _poise_def: BuffDef = null
var _light_def: BuffDef = null


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


static func buff_def() -> BuffDef:
	return _load(BUFF_ID)


## 这一份连击（每层急速，锋芒另有暴击；同一个 id，界面认的还是【连击】）
func combo_def() -> BuffDef:
	if _def == null:
		var mods: Array[StatModifier] = [StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, haste_per)]
		if edge_crit != 0.0:
			mods.append(StatModifier.make(BattleStats.CRIT_CHANCE, StatModifier.Mode.ADD, edge_crit / 100.0))
		if edge_crit_damage != 0.0:
			mods.append(StatModifier.make(BattleStats.CRIT_DAMAGE, StatModifier.Mode.ADD, edge_crit_damage / 100.0))
		_def = _own(BUFF_ID, mods)
	return _def


func _defs() -> void:
	if _flow_def == null and flow_per > 0.0:
		_flow_def = _own(FLOW_ID, [StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, flow_per)] as Array[StatModifier])
	if _poise_def == null and poise_pct > 0.0:
		_poise_def = _own(POISE_ID, [StatModifier.make(BattleStats.CRIT_CHANCE, StatModifier.Mode.ADD, poise_pct / 100.0)] as Array[StatModifier])
	if _light_def == null and light_pct > 0.0:
		_light_def = _own(LIGHT_ID, [StatModifier.make(BattleStats.STAMINA_COST, StatModifier.Mode.MULT, -light_pct)] as Array[StatModifier])


static func is_weapon(me: CombatantRuntime, uid: int) -> bool:
	if uid == 0:
		return false
	var tags := me.tags_of(uid)
	return tags.has(&"weapon") or tags.has(&"staff")


func apply(ctx: RuleContext) -> void:
	if ctx.owner == null or ctx.owner.dead or combo_def() == null:
		return
	_defs()
	var e := ctx.event
	if e == null:
		_tick(ctx)
		return
	match e.name:
		BattleEvent.BATTLE_START:
			_start(ctx)
		BattleEvent.BEFORE_DAMAGE:
			_before(ctx)
		BattleEvent.DAMAGE:
			_after(ctx, e)
		BattleEvent.ITEM_FIRED:
			if e.side == ctx.owner.side and is_weapon(ctx.owner, e.get_int(&"uid")):
				_attacked(ctx)
		BattleEvent.ITEM_SKIPPED:
			if e.side == ctx.owner.side and is_weapon(ctx.owner, e.get_int(&"uid")):
				_reset(ctx)


func _start(ctx: RuleContext) -> void:
	if soft_pct > 0.0:
		ctx.owner.crit_plain = true
	var n := opening + carry_in
	if n > 0:
		ApplyStatus.give(ctx, ctx.owner, combo_def(), n)
		_light(ctx)


#region 叠与清
func stacks(ctx: RuleContext) -> int:
	return ctx.owner.stacks_of(BUFF_ID)


## 一次攻击：叠一层；气功数攻击次数
func _attacked(ctx: RuleContext) -> void:
	var st := ctx.state()
	if qigong_every > 0:
		var hits := int(st.get("qigong_n", 0)) + 1
		if hits >= qigong_every:
			hits = 0
			st["qigong_armed"] = true
		st["qigong_n"] = hits
	_gain(ctx, 1)


## 叠 [param n] 层（攻击、架势）：寻隙、招架、流水按累积的层数算
func _gain(ctx: RuleContext, n: int) -> void:
	if n <= 0:
		return
	var me := ctx.owner
	var st := ctx.state()
	ApplyStatus.give(ctx, me, combo_def(), n)
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": MECHANIC, "key": "skill_momentum", "count": n})
	var acc := int(st.get("acc", 0)) + n
	st["acc"] = acc
	if gap_every > 0:
		var g := int(st.get("gap_acc", 0)) + n
		if g >= gap_every:
			g = g % gap_every
			st["gap_armed"] = true
		st["gap_acc"] = g
	if parry_pct > 0.0 and parry_every > 0:
		var p := int(st.get("parry_acc", 0)) + n
		@warning_ignore("integer_division")
		var times := p / parry_every
		st["parry_acc"] = p - times * parry_every
		if times > 0:
			me.restore_armor(parry_pct * times)
	if _flow_def != null:
		ApplyStatus.give(ctx, me, _flow_def, n)
	_light(ctx)


## 清零（耐力不够没出手）：稳手留几层；残心、大巧若拙、回气、气血按清掉前的层数
func _reset(ctx: RuleContext) -> void:
	var me := ctx.owner
	var n := stacks(ctx)
	if n <= 0:
		return
	var keep := mini(n, keep_on_reset)
	if n - keep > 0:
		RemoveStatus.take(ctx, me, BUFF_ID, n - keep, "reset")
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": MECHANIC, "key": "skill_reset", "count": n})
	_light(ctx)
	if breath_per > 0.0 and me.resources.has(BattleStats.RES_STAMINA):
		me.resources.change(BattleStats.RES_STAMINA, StatMath.from_float(breath_per * n), BattleEvent.REASON_HEAL)
	if vigor_per > 0.0:
		me.heal(ctx.battle, StatMath.from_float(vigor_per * n))
	if clumsy_pct > 0.0:
		var foe := ctx.opponent()
		var raw := StatMath.from_float(n * clumsy_pct / 100.0)
		if foe != null and not foe.dead and raw > 0:
			var p := DamagePacket.create(DamageTypes.PHYSICAL, raw, foe, me.side, 0, false)
			p.pure = true
			DamageResolver.resolve(ctx.battle, p)
	if zanshin > 0:
		_zanshin(ctx)


## 残心：随机几件（不重样）武器立即出手一次
func _zanshin(ctx: RuleContext) -> void:
	var me := ctx.owner
	var pool: Array[RuleRuntime] = []
	for rt in me.rules:
		var r := rt as RuleRuntime
		if r.source_uid != 0 and r.buff == null and r.rule != null and r.rule.trigger is OnSchedule and is_weapon(me, r.source_uid):
			pool.append(r)
	for i in mini(zanshin, pool.size()):
		var pick := ctx.roll("skill_zanshin", 0, pool.size() - 1)
		var rt := pool[pick]
		pool.remove_at(pick)
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": MECHANIC, "key": "skill_zanshin", "count": 1})
		RuleEngine.fire_free(ctx.battle, me, rt)


## 行云：至少几层时挂着（耐力消耗降低）
func _light(ctx: RuleContext) -> void:
	if _light_def == null:
		return
	var me := ctx.owner
	var on := stacks(ctx) >= light_at
	var have := me.stacks_of(LIGHT_ID) > 0
	if on and not have:
		ApplyStatus.give(ctx, me, _light_def, 1)
	elif not on and have:
		RemoveStatus.take(ctx, me, LIGHT_ID, me.stacks_of(LIGHT_ID), "faded")


## 节拍：蓄势每几秒一层
func _tick(ctx: RuleContext) -> void:
	if _poise_def == null:
		return
	var st := ctx.state()
	var now := ctx.battle.now
	var next := int(st.get("poise_at", StatMath.from_float(poise_sec)))
	if now >= next:
		ApplyStatus.give(ctx, ctx.owner, _poise_def, 1)
		next = now + StatMath.from_float(poise_sec)
	st["poise_at"] = next
#endregion


#region 出手与挨打
func _before(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or p.pure:
		return
	var me := ctx.owner
	var st := ctx.state()
	var n := stacks(ctx)
	if p.source_side == me.side and p.victim != me and p.direct and is_weapon(me, p.source_uid):
		if press_pct > 0.0 and n > 0:
			p.raw += StatMath.from_float(n * press_pct / 100.0)
		if see_per > 0.0 and n > 0:
			p.ignore_flat += StatMath.from_float(n * see_per)
		if bool(st.get("gap_armed", false)):
			st["gap_armed"] = false
			p.penetration = true
			p.add_percent(StatMath.from_float(gap_pct / 100.0))
			ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": MECHANIC, "key": "skill_gap", "count": 1})
	elif p.victim == me and guard_flat > 0.0 and n >= guard_at and p.raw > 0:
		p.flat -= StatMath.from_float(guard_flat)     # 作者 11-25 20:34：可以减到 0，减到 0 算挡住（架势认）


func _after(ctx: RuleContext, e: BattleEvent) -> void:
	var me := ctx.owner
	if e.get_bool(&"cancelled"):
		return
	var src := e.get_int(&"source_side", -1)
	if e.side == me.side:
		if stance > 0 and src >= 0 and src != me.side and e.get_bool(&"direct") and e.get_int(&"raw") > 0 and e.get_int(&"amount") <= 0 and e.get_int(&"deferred") <= 0:
			_gain(ctx, stance)     # 架势：这一下没掉血
		return
	if src != me.side or not e.get_bool(&"direct") or not is_weapon(me, e.get_int(&"uid")):
		return
	var st := ctx.state()
	if bool(st.get("qigong_armed", false)):
		st["qigong_armed"] = false
		var foe := ctx.opponent()
		var id := ELEMENTS[ctx.roll("skill_qigong", 0, ELEMENTS.size() - 1)]
		var d := _load(id)
		if foe != null and not foe.dead and d != null and qigong_stacks > 0:
			ApplyStatus.give(ctx, foe, d, qigong_stacks)
	if e.get_bool(&"crit"):
		if _poise_def != null and me.stacks_of(POISE_ID) > 0:
			RemoveStatus.take(ctx, me, POISE_ID, me.stacks_of(POISE_ID), "spent")
		if soft_pct > 0.0:
			var foe2 := ctx.opponent()
			var raw := StatMath.mul(e.get_int(&"raw"), StatMath.from_float(soft_pct / 100.0))
			if foe2 != null and not foe2.dead and raw > 0:
				ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": MECHANIC, "key": "skill_soft", "count": 1})
				DamageResolver.deal(ctx.battle, foe2, raw, DamageTypes.PHYSICAL, me.side, 0, true)
#endregion


func describe() -> String:
	return UiText.t("fx.skill_momentum") % TextTemplate.num(haste_per)
