## 388 第 1 批（作者牌表 11-24）：蛮神的【怒气】与蛮神的牌在战斗里的那一半。一条规则（[FaithMechanicTrigger] 听受伤前、伤害、状态施加，
## 另按 [member STEP] 秒打节拍）放整套，数由 [BruteRagePerk] 编译时按拿了哪些牌填好。
##
## - 核心：受到对手造成的生命伤害积怒气，每失去 [member hp_per_stack] 点生命一层（作者 11-26：按固定的生命点数，不按百分比）（396 起不封顶，[member cap] 0）；
##   每一笔**单独计时** [member duration_sec] 秒（来源不同各走各的），身上统一显示一个【怒气】，不写倒计时。怒气本身不加属性（396）：
##   每层造成伤害 +[member damage_per]%（【急躁】【破甲】加在这里）、急速 +[member haste_per]%（【狂热】）、生命回复 +[member regen_per]（【不灭】）。怒气不再用掉。
## - 【易怒症】积得多几成。【怒意延绵】持续时间减半，每受到一次伤害所有还在的怒气重新计时（[member refresh_on_hit]）。
## - 【困兽】（396）：每失去 1% 生命，所有属性（[constant BattleStats.ALL_STATS]）各 +[member cornered_per]%（另一个状态【困兽】，层数 = 失去了百分之几）。
## - 【破甲】每层让这一下对护甲多扣几成（[member DamagePacket.armor_bonus]）。
## - 【怒火中烧】每 10 层，武器打中时附几层【灼伤】。【痛觉残留】受到的伤害挪几成到之后几秒慢慢扣（慢慢扣的那份照样积怒气；灼伤这类持续伤害不积，396）。
## - 【以血还血】累计积到几层，随机一把武器立即出手一次（不耗耐力、不动冷却，[method RuleEngine.fire_free]）。
## - 【恨意】被施加负面状态时 +1 层不计上限的怒气，升级版负面状态每跳一下也 +1。
## - 【血甲】受伤后记 [member armor_window] 秒的受伤量，到点给一半的护甲，冷却 [member armor_cd] 秒；升级版也记造成的伤害，这份护甲被打穿时回一半的血。
## - 【余怒】一笔怒气到点消散时，按那笔的几成再给一笔。【嗜血】武器打出的伤害按几成回血。
## 【死斗】走 [method CompileInput.keep_undying]，【神罚】走 [SmitePerk]，都不在这里。积怒气时写战记 `faith_mechanic` / `brute_strike`
class_name BruteRage
extends CombatEffect

const BUFF_ID := &"brute_rage"
const CORNERED_ID := &"brute_cornered"
const SCORCH := &"scorch"
## 节拍：怒气到点、持续伤害跳、血甲到点都在节拍上结算
const STEP := 0.2

## 每失去几点生命积一层（作者 11-26 00:08 定按绝对值；2 是初值）
@export var hp_per_stack: float = 2.0
## 上限（0 = 不封顶，396）
@export var cap: int = 0
@export var duration_sec: float = 4.0
@export var damage_per: float = 0.0
@export var haste_per: float = 0.0
@export var regen_per: float = 0.0
## 不灭按整段给：每满几层才加一次（0 = 按层平摊，[member regen_per] 每层）；整段时每段加 [member regen_step_amount]
@export var regen_step: int = 0
@export var regen_step_amount: float = 0.0
## 积怒气多几成（易怒症，百分数）
@export var gain_bonus: int = 0
## 怒意延绵：每受到一次伤害，所有还在的怒气重新计时
@export var refresh_on_hit: bool = false
## 困兽：每失去 1% 生命，所有属性各加几成（百分数，0 = 没拿）
@export var cornered_per: float = 0.0
## 破甲：每层对护甲多扣几成（百分数）
@export var armor_per: float = 0.0
## 怒火中烧：每几层附一次、一次几层灼伤（0 = 没拿）
@export var scorch_every: int = 10
@export var scorch_stacks: int = 0
## 痛觉残留：挪走几成、分几秒扣完（0 = 没拿）
@export var defer_percent: int = 0
@export var defer_sec: int = 5
## 以血还血：累计积到几层出手一次（0 = 没拿）
@export var strike_every: int = 0
## 恨意：0 = 没拿，1 = 被施加负面状态时，2 = 另外负面状态每跳一下
@export var hate: int = 0
## 恨意升级：寒冷、麻痹减半那一下也算「触发」（作者待定，默认只算跳伤害）
@export var hate_halving: bool = false
## 血甲（armor_window 0 = 没拿）
@export var armor_window: float = 0.0
@export var armor_cd: float = 10.0
@export var armor_percent: int = 50
## 血甲升级：也记造成的伤害；这份护甲打穿时回几成的血（0 = 没升级）
@export var armor_dealt: bool = false
@export var armor_heal_percent: int = 0
## 余怒：到点消散时再给那笔的几成（四舍五入）
@export var linger_percent: float = 0.0
## 嗜血：武器打出伤害的几成回血
@export var lifesteal_percent: float = 0.0
## 作者 11-28 质变牌【竭力】：耐力不够时用等量生命付（[member CombatantRuntime.stamina_from_hp]）；付掉的生命算失去的生命，照常攒怒气、让困兽变强
@export var exert: bool = false
const EXERT_KEY := "brute_exert"

static var _base_def: BuffDef = null
var _def: BuffDef = null
var _cornered_def: BuffDef = null


static func buff_def() -> BuffDef:
	if _base_def == null:
		var path := ContentPaths.asset_file("buffs", String(BUFF_ID))
		_base_def = load(path) as BuffDef if ResourceLoader.exists(path) else null
	return _base_def


## 这一份怒气（按拿的牌带每层的伤害、急速、回血；同一个 id，界面认的还是【怒气】）
func rage_def() -> BuffDef:
	if _def == null and buff_def() != null:
		_def = buff_def().duplicate() as BuffDef
		var mods: Array[StatModifier] = []
		if damage_per != 0.0:
			mods.append(StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, damage_per))
		if haste_per != 0.0:
			mods.append(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, haste_per))
		if regen_per != 0.0 or regen_step > 0:
			mods.append(StatModifier.make(BattleStats.REGEN_HP, StatModifier.Mode.ADD, regen_per))
		_def.mods = mods
	return _def


## 困兽那份状态（每层所有属性各 +[member cornered_per]%）
func cornered_def() -> BuffDef:
	if _cornered_def == null and cornered_per > 0.0:
		var path := ContentPaths.asset_file("buffs", String(CORNERED_ID))
		var base := load(path) as BuffDef if ResourceLoader.exists(path) else null
		if base != null:
			_cornered_def = base.duplicate() as BuffDef
			_cornered_def.mods = BattleStats.all_stats_mods(cornered_per)     # 396 第五节：所有属性
	return _cornered_def


func apply(ctx: RuleContext) -> void:
	if ctx.owner == null or ctx.owner.dead or rage_def() == null:
		return
	var e := ctx.event
	if e == null:
		_tick(ctx)
		return
	match e.name:
		BattleEvent.BEFORE_DAMAGE:
			_before(ctx)
		BattleEvent.DAMAGE:
			_after(ctx, e)
		BattleEvent.BATTLE_START:
			if exert:
				ctx.owner.stamina_from_hp = true
		BattleEvent.EFFECT_RESOLVED:
			if exert and e.side == ctx.owner.side and String(e.payload.get("key", "")) == EXERT_KEY:
				_gather(ctx, e.get_int(&"fp"))
				_sync_cornered(ctx)
		BattleEvent.STATUS_APPLIED:
			if hate >= 1 and e.side == ctx.owner.side and _is_debuff(ctx.owner, e.get_name(&"buff")):
				_add(ctx, 1, true)
		BattleEvent.STATUS_UNSTACKED:
			if hate >= 2 and hate_halving and e.side == ctx.owner.side and String(e.payload.get("reason", "")) == "decay" and _halves_on_act(ctx.owner, e.get_name(&"buff")):
				_add(ctx, 1, true)


## 寒冷（出手）/ 麻痹（付耐力）这类按动作减半的负面状态
static func _halves_on_act(me: CombatantRuntime, id: StringName) -> bool:
	var b := me.find_buff(id)
	if b == null:
		var path := ContentPaths.asset_file("buffs", String(id))
		var d := load(path) as BuffDef if ResourceLoader.exists(path) else null
		return d != null and d.is_debuff and d.decay_halve_on in [BuffDef.HALVE_WEAPON_FIRED, BuffDef.HALVE_STAMINA_PAID]
	return b.def.is_debuff and b.def.decay_halve_on in [BuffDef.HALVE_WEAPON_FIRED, BuffDef.HALVE_STAMINA_PAID]


static func _is_debuff(me: CombatantRuntime, id: StringName) -> bool:
	var b := me.find_buff(id)
	return b != null and b.def.is_debuff and not b.def.system


#region 积与散
## 现在一共几层（计上限的封顶 + 不计上限的；不封顶就是全加起来）
func stacks(st: Dictionary) -> int:
	var normal := 0
	var extra := 0
	for b in st.get("batches", []):
		if bool(b[2]):
			extra += int(b[0])
		else:
			normal += int(b[0])
	return (mini(cap, normal) if cap > 0 else normal) + extra


## 加一笔 [param n] 层（[param uncapped] = 恨意那种不计上限的）。返回实际加了几层
func _add(ctx: RuleContext, n: int, uncapped: bool = false) -> int:
	if n <= 0:
		return 0
	var st := ctx.state()
	var batches: Array = st.get("batches", [])
	if not uncapped and cap > 0:
		var normal := 0
		for b in batches:
			if not bool(b[2]):
				normal += int(b[0])
		n = mini(n, cap - normal)
		if n <= 0:
			return 0
	batches.append([n, ctx.battle.now + StatMath.from_float(duration_sec), uncapped])
	st["batches"] = batches
	_sync(ctx)
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "brute_strike", "count": n})
	if strike_every > 0:
		var acc := int(st.get("strike_acc", 0)) + n
		@warning_ignore("integer_division")
		var times := acc / strike_every
		st["strike_acc"] = acc - times * strike_every
		for i in mini(times, 5):
			_strike(ctx)
	return n


## 身上显示的层数跟着这几笔走
func _sync(ctx: RuleContext) -> void:
	var me := ctx.owner
	var want := stacks(ctx.state())
	var have := me.stacks_of(BUFF_ID)
	if regen_step > 0 and want != have and rage_def() != null:
		# 不灭按整段：每层的量 = 满了几段 × 每段 ÷ 层数（层数变了就重算）
		@warning_ignore("integer_division")
		var per := regen_step_amount * float(want / regen_step) / float(maxi(1, want))
		for m in rage_def().mods:
			if (m as StatModifier).stat == BattleStats.REGEN_HP:
				(m as StatModifier).amount = per
		me.mark_dirty()
	if want > have:
		ApplyStatus.give(ctx, me, rage_def(), want - have)
	elif want < have:
		RemoveStatus.take(ctx, me, BUFF_ID, have - want, "expired")


## 节拍：到点的几笔散掉、余怒、持续伤害、血甲、困兽（回了血层数跟着降）
func _tick(ctx: RuleContext) -> void:
	var st := ctx.state()
	var now := ctx.battle.now
	var batches: Array = st.get("batches", [])
	if not batches.is_empty():
		var keep: Array = []
		var gone: Array = []
		for b in batches:
			if int(b[1]) <= now:
				gone.append(b)
			else:
				keep.append(b)
		if not gone.is_empty():
			st["batches"] = keep
			_sync(ctx)
			if linger_percent > 0.0:
				for b in gone:
					_add(ctx, roundi(int(b[0]) * linger_percent / 100.0))
	_tick_pain(ctx, st, now)
	_tick_armor(ctx, st, now)
	_sync_cornered(ctx)


## 怒意延绵：所有还在的怒气从现在起重新计时
func _refresh(ctx: RuleContext) -> void:
	var until := ctx.battle.now + StatMath.from_float(duration_sec)
	for b in ctx.state().get("batches", []):
		b[1] = maxi(int(b[1]), until)


## 困兽：层数 = 失去了最大生命的百分之几（向下取整）
func _sync_cornered(ctx: RuleContext) -> void:
	var d := cornered_def()
	if d == null:
		return
	var me := ctx.owner
	var have := me.stacks_of(CORNERED_ID)
	var hp_max := me.resources.maximum(BattleStats.RES_HP)
	# 困兽自己也加生命上限（加上限时当前值同量加）：缺的血不受它影响，按去掉它那份的上限算百分比，免得层数来回跳
	var base_max := roundi(float(hp_max) * 100.0 / (100.0 + cornered_per * have))
	if base_max <= 0:
		return
	@warning_ignore("integer_division")
	var want := clampi((hp_max - me.resources.current(BattleStats.RES_HP)) * 100 / base_max, 0, 100)
	if want > have:
		ApplyStatus.give(ctx, me, d, want - have)
	elif want < have:
		RemoveStatus.take(ctx, me, CORNERED_ID, have - want, "faded")
#endregion


#region 出手与挨打
## 受伤前：我打出去的（破甲）；我挨的（痛觉残留）
func _before(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or p.pure:
		return
	var me := ctx.owner
	if p.source_side == me.side and p.victim != me and p.direct:
		var n := me.stacks_of(BUFF_ID)
		if n > 0 and armor_per > 0.0:
			p.armor_bonus += roundi(armor_per * n)
	elif p.victim == me and defer_percent > 0 and p.raw > 0 and p.direct:     # 作者 11-26 00:18：只管直接伤害，持续伤害不经过它
		p.defer_percent = maxi(p.defer_percent, defer_percent)


func _after(ctx: RuleContext, e: BattleEvent) -> void:
	var me := ctx.owner
	if e.get_bool(&"cancelled"):
		return
	var src := e.get_int(&"source_side", -1)
	var amount := e.get_int(&"amount")
	var direct := e.get_bool(&"direct")
	if e.side == me.side:
		var tick := not direct and (src == me.side or src < 0)     # 身上的状态跳的（灼伤、中毒、流血；痛觉残留那份是真实伤害）
		var st := ctx.state()
		if e.get_int(&"deferred") > 0:
			_defer(st, e.get_int(&"deferred"), ctx.battle.now)
		if tick and hate >= 2 and not e.get_bool(&"pure"):
			_add(ctx, 1, true)
		if refresh_on_hit and amount + e.get_int(&"absorbed") > 0:
			_refresh(ctx)
		if (src >= 0 and src != me.side) or (tick and not _pain_tick(e)):
			_gather(ctx, amount)     # 作者 11-26 00:18：中毒、灼伤、流血这类持续伤害照常攒（痛觉残留慢慢扣的那份在 _tick_pain 里算过）
		_hit_armor(ctx, st, amount + e.get_int(&"absorbed"))
		_sync_cornered(ctx)
	elif src == me.side and direct and amount > 0:
		_on_dealt(ctx, e, amount)


## 痛觉残留慢慢扣的那一跳（[method _tick_pain] 打的：物理、真实）；流血是自己的伤害类型，不算
static func _pain_tick(e: BattleEvent) -> bool:
	return e.get_bool(&"pure") and StringName(String(e.payload.get("type", ""))) == DamageTypes.PHYSICAL


func _gather(ctx: RuleContext, lost: int) -> void:
	var me := ctx.owner
	var hp_max := me.resources.maximum(BattleStats.RES_HP)
	lost = mini(lost, hp_max)
	if lost <= 0 or hp_max <= 0:
		return
	var weight := 100 + gain_bonus
	var st := ctx.state()
	var per := StatMath.from_float(hp_per_stack) * 100
	if per <= 0:
		return
	var acc := int(st.get("acc", 0)) + lost * weight
	@warning_ignore("integer_division")
	var gain := acc / per
	st["acc"] = acc - gain * per
	_add(ctx, gain)


## 我的武器打中了：怒火中烧附灼伤、嗜血回血、血甲升级记造成的伤害
func _on_dealt(ctx: RuleContext, e: BattleEvent, amount: int) -> void:
	var me := ctx.owner
	var st := ctx.state()
	if scorch_stacks > 0 and scorch_every > 0 and e.get_int(&"uid") != 0:
		@warning_ignore("integer_division")
		var n := (me.stacks_of(BUFF_ID) / scorch_every) * scorch_stacks
		var foe := ctx.opponent()
		var sdef := _scorch()
		if n > 0 and foe != null and not foe.dead and sdef != null:
			ApplyStatus.give(ctx, foe, sdef, n)
	if lifesteal_percent > 0.0:
		var acc := float(st.get("steal", 0.0)) + amount * lifesteal_percent / 100.0
		var whole := int(acc)
		st["steal"] = acc - whole
		if whole > 0:
			me.heal(ctx.battle, whole)
	if armor_dealt and int(st.get("armor_until", -1)) > 0:
		st["armor_sum"] = int(st.get("armor_sum", 0)) + amount


static var _scorch_def: BuffDef = null


static func _scorch() -> BuffDef:
	if _scorch_def == null:
		var path := ContentPaths.asset_file("buffs", String(SCORCH))
		_scorch_def = load(path) as BuffDef if ResourceLoader.exists(path) else null
	return _scorch_def


## 以血还血：随机一把武器立即出手一次
func _strike(ctx: RuleContext) -> void:
	var me := ctx.owner
	var pool: Array[RuleRuntime] = []
	for rt in me.rules:
		var r := rt as RuleRuntime
		if r.source_uid != 0 and r.buff == null and r.rule != null and r.rule.trigger is OnSchedule and me.tags_of(r.source_uid).has(&"weapon"):
			pool.append(r)
	if pool.is_empty():
		return
	var pick := ctx.roll("brute_strike_back", 0, pool.size() - 1)
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "brute_blood_for_blood", "count": 1})
	RuleEngine.fire_free(ctx.battle, me, pool[pick])
#endregion


#region 痛觉残留
func _defer(st: Dictionary, amount: int, now: int) -> void:
	var dots: Array = st.get("dots", [])
	var n := maxi(1, defer_sec)
	# [每一跳的量, 还剩几跳, 下一跳的时刻, 余数]
	@warning_ignore("integer_division")
	dots.append([amount / n, n, now + StatMath.ONE, amount - (amount / n) * n])
	st["dots"] = dots


func _tick_pain(ctx: RuleContext, st: Dictionary, now: int) -> void:
	var dots: Array = st.get("dots", [])
	if dots.is_empty():
		return
	var keep: Array = []
	var due := 0
	for d in dots:
		while int(d[1]) > 0 and int(d[2]) <= now:
			due += int(d[0]) + (int(d[3]) if int(d[1]) == 1 else 0)
			d[1] = int(d[1]) - 1
			d[2] = int(d[2]) + StatMath.ONE
		if int(d[1]) > 0:
			keep.append(d)
	st["dots"] = keep
	if due > 0:
		var p := DamagePacket.create(DamageTypes.PHYSICAL, due, ctx.owner, ctx.owner.side, 0, false)
		p.pure = true     # 减伤、护甲在挨打那一下已经算过了
		DamageResolver.resolve(ctx.battle, p)
		_gather(ctx, due)     # 慢慢扣的那份原本就是对手打的，照样积怒气（伤害事件排队派发，在这里直接算）
#endregion


#region 血甲
## 挨了一下：开记（不在冷却里）、记进去；升级版那份护甲打穿就回血
func _hit_armor(ctx: RuleContext, st: Dictionary, amount: int) -> void:
	if armor_window <= 0.0:
		return
	var now := ctx.battle.now
	var until := int(st.get("armor_until", -1))
	if until > 0:
		st["armor_sum"] = int(st.get("armor_sum", 0)) + amount
	elif amount > 0 and now >= int(st.get("armor_ready", 0)):
		st["armor_until"] = now + StatMath.from_float(armor_window)
		st["armor_sum"] = amount
	var pool := int(st.get("armor_pool", 0))
	var res := ctx.owner.resources
	if pool > 0 and armor_heal_percent > 0 and res.has(BattleStats.RES_ARMOR) and res.current(BattleStats.RES_ARMOR) <= 0:
		st["armor_pool"] = 0
		ctx.owner.heal(ctx.battle, StatMath.mul(pool, StatMath.from_percent(armor_heal_percent)))


func _tick_armor(ctx: RuleContext, st: Dictionary, now: int) -> void:
	var until := int(st.get("armor_until", -1))
	if until <= 0 or now < until:
		return
	st["armor_until"] = -1
	st["armor_ready"] = now + StatMath.from_float(armor_cd)
	var gain := StatMath.mul(int(st.get("armor_sum", 0)), StatMath.from_percent(armor_percent))
	st["armor_sum"] = 0
	if gain <= 0:
		return
	ctx.owner.add_max(BattleStats.RES_ARMOR, gain)     # 上限加多少当前值同量加；属性重算也留着
	if armor_heal_percent > 0:
		st["armor_pool"] = int(st.get("armor_pool", 0)) + gain
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "brute_blood_armor", "count": 1})
#endregion


func describe() -> String:
	return UiText.t("fx.brute_rage") % [TextTemplate.num(hp_per_stack), TextTemplate.num(duration_sec)]
