## 伤害结算管线（架构文档 4.6）。
##
## [b]一切血量的减少都走这里[/b] —— 武器命中、持续伤害、以血为代价的自伤，
## 区别只在伤害类型。这样减伤、护甲、免疫、反转只需要实现一次。
##
## 五步，顺序不可调换：
## [codeblock]
## 1. 确认类型      这一下能不能被护甲吸收、要不要通知；攻方的伤害类型加成（火焰轴）在这里乘
## 2. 护甲吸收      能吸收则先扣护甲，中毒之类绕过
## 3. 受伤前效果    【同步派发】效果在这里改写伤害包：减伤、反转、免疫
## 4. 计算受伤量    百分比 → 固定增减 → 反转 → 格挡（只对直接伤害，106）→ 「受到伤害」轴（103），然后落到血量
## 5. 受伤后效果    发 damage 事件；流失类不通知默认监听（175 补充五：伤害不盖元素印 —— 印只从施加状态来）
## [endcodeblock]
## 175 补充四：真实伤害（[member DamageTypeDef.pure]，流血）跳过 1b–4，原值直接落血；第 4 步末尾再乘守方按类型的易伤（剧毒）
##
## 第 3 步是整条管线存在的理由。护甲那种无条件减伤写成一个属性就够了，
## 但「消耗 2 层格挡减免 10 点」「喝了解毒剂时中毒反转成治疗」有前置条件，
## 它们必须是**带消耗、带扳机的普通规则**，只是作用对象是这一包伤害。
class_name DamageResolver
extends RefCounted


## 结算一包伤害，返回实际扣掉的血量（正数；治疗则为负）。
static func resolve(ctx: BattleContext, packet: DamagePacket) -> int:
	if packet == null or packet.victim == null:
		return 0
	var victim := packet.victim
	var td := packet.def()
	if victim.dead:
		return 0     # 087：倒下的不再受伤也不再被治（倒下是终局）
	# 117：内部日志要「原始值 → 每一级 → 实际扣血」，进管线前先记下起点
	var raw_in := packet.raw
	var hp_before := victim.resources.current(BattleStats.RES_HP) if ctx.trace != null else 0
	var taken_factor := StatMath.ONE

	# --- 1b. 攻方的伤害类型加成（105）：火焰加成是一条标准轴，放在**防御之前**乘原值 ——
	# 和「受到伤害」轴在第 4 步乘守方的最终伤害对称。于是附魔、灼烧、任何火焰来源都吃它
	var pure := td.pure
	if packet.raw > 0 and packet.type == DamageTypes.FIRE and not pure:
		var attacker := _side_of(ctx, packet.source_side)
		if not packet.direct and attacker == victim:
			attacker = ctx.opponent_of(victim)     # 175 补充四：身上的灼伤 / 燃血跳的火伤（非直接、主人是挨打的自己），按对手（施加方）的火焰加成
		if attacker != null:
			var boost := attacker.axis_factor(StatAxes.FIRE_DAMAGE)
			if boost != StatMath.ONE:
				packet.raw = maxi(0, StatMath.mul(packet.raw, boost))

	# --- 2. 护甲吸收 ---
	# 放在受伤前效果之前，是因为「这一下还剩多少要扛」本身就是减伤效果的判断依据。
	if td.armor_absorbable and packet.raw > 0 and not pure:
		var pool := victim.resources
		if pool.has(BattleStats.RES_ARMOR):
			var take := mini(pool.current(BattleStats.RES_ARMOR), packet.raw)
			if take > 0:
				pool.change(BattleStats.RES_ARMOR, -take, BattleEvent.REASON_ABSORBED)
				packet.absorbed = take

	# --- 3. 受伤前效果。同步派发，不入队 —— 排队就赶不上这次结算了 ---
	if not pure:
		ctx.dispatch_before_damage(packet)
	td = packet.def()     # 132：受伤前可能改了类型（convert_damage_type）；之后按新类型通知

	if packet.cancelled:
		packet.final = 0
		packet.applied = 0
		if ctx.trace != null:
			_trace(ctx, packet, raw_in, hp_before, taken_factor)
		_notify(ctx, packet, td)
		return 0

	# --- 4. 计算受伤量 ---
	var amount := packet.pending()
	if packet.percent != 0:
		amount = StatMath.mul(amount, StatMath.ONE + packet.percent)
	amount += packet.flat
	# 减伤减到头就是 0：固定减伤（塔盾 -4 挨一把 3 点的匕首）不能把伤害减成治疗 —— 变治疗只有 invert 一条路（作者反馈 085）
	amount = maxi(0, amount)
	if packet.inverted:
		amount = -amount
	# 格挡只动伤害，不动治疗。106 第八节（作者定）：**只减直接伤害**（武器造成的），
	# buff 造成的灼烧 / 中毒 / 流血不吃格挡 —— 按来源判，不再按伤害类型的护甲列。
	# 格挡为负（破绽）时倒贴：10 点打成 13（作者定），所以负值不走 min。
	# 153：这里读到的已经是「最高那面盾 + 加固 / 破绽」（[CombatantRuntime]），几面盾不相加
	if amount > 0 and packet.direct and not pure:
		var block := victim.stat(BattleStats.BLOCK, 0)
		packet.block = mini(block, amount) if block > 0 else block
		amount = maxi(0, amount - packet.block)
	# 103（作者定）：加时放大的是角色受到的「最终伤害」—— 护甲、减伤、格挡都按原值算完，扛下来的那部分再乘；治疗不放大
	if amount > 0 and not pure:
		var taken := victim.axis_factor(StatAxes.DAMAGE_TAKEN)     # 标准轴（4.3）：易伤为正、坚韧为负，加时在系统层
		taken_factor = taken
		if taken != StatMath.ONE:
			amount = maxi(0, StatMath.mul(amount, taken))
		# 175 补充四：按类型的易伤（剧毒：受到的毒素伤害每层 +X%）—— 只读一次，不加轴
		var by_type := victim.taken_by_type_percent(packet.type)
		if by_type != 0.0:
			amount = maxi(0, StatMath.mul(amount, StatMath.ONE + StatMath.from_float(by_type / 100.0)))
	packet.final = amount

	if amount > 0:
		packet.applied = victim.resources.change(
			BattleStats.RES_HP, -amount, BattleEvent.REASON_DAMAGE
		)
		# 093（蛮神 4 级）：坚持期里血停在 0，扣不动 —— 但受到的伤害**照记**（作者定），事件里的 amount 是真实伤害
		if victim.undying_active() and -packet.applied < amount:
			packet.applied = -amount
	elif amount < 0:
		packet.applied = victim.heal(ctx, -amount)     # 175：反转成的治疗也走治疗入口

	# --- 5. 受伤后 ---
	if ctx.trace != null:
		_trace(ctx, packet, raw_in, hp_before, taken_factor)
	_notify(ctx, packet, td)
	victim.settle_death(ctx)
	return -packet.applied


## 出手的那一方（source_side 没填 / 不在场则 null）。自伤、环境伤害都没有攻方
static func _side_of(ctx: BattleContext, side: int) -> CombatantRuntime:
	if ctx == null or side < 0 or side >= ctx.sides.size():
		return null
	return ctx.sides[side]


## 117：内部日志的一条伤害管线：原始值 → 火焰加成 → 护甲 → 受伤前效果 → 格挡 → 受到伤害轴 → 实际扣血
static func _trace(ctx: BattleContext, packet: DamagePacket, raw_in: int, hp_before: int, taken: int) -> void:
	ctx.trace.record(ctx.now, packet.victim_side(), BattleTrace.DAMAGE, {
		"type": String(packet.type), "source_side": packet.source_side, "uid": packet.source_uid, "victim": packet.victim_side(),
		"raw_in": raw_in, "raw": packet.raw, "crit": packet.crit, "direct": packet.direct,
		"absorbed": packet.absorbed, "flat": packet.flat, "percent": packet.percent, "inverted": packet.inverted,
		"cancelled": packet.cancelled, "block": packet.block, "taken": taken, "final": packet.final,
		"hp_before": hp_before, "hp_after": packet.victim.resources.current(BattleStats.RES_HP),
		"hp_lost": maxi(0, -packet.applied),
	})


## 发出 damage 事件。
##
## [b]不招致反应的类型也照发。[/b] 过滤发生在扳机那一侧（[DamageTrigger] 默认只认
## provokes 为真的类型），而不是这里不发 —— 不发的话「中毒时净化」「流失时回气」
## 这类联动就永远没有接入点，而那正是我们想留的口子。
static func _notify(ctx: BattleContext, packet: DamagePacket, td: DamageTypeDef) -> void:
	var payload := {
		"type": String(packet.type),
		"raw": packet.raw,
		"absorbed": packet.absorbed,
		"block": packet.block,
		"amount": -packet.applied,
		"provokes": td.provokes,
		"source_side": packet.source_side,
		"uid": packet.source_uid,
		"crit": packet.crit,     # 104
		"direct": packet.direct,     # 106：直接 / 非直接（格挡只减直接伤害）
	}
	if packet.cancelled:
		payload["cancelled"] = true     # 175 补充五：被取消的一下（「造成伤害后施加」不认它，[member DamageTrigger.landed_only]）
	ctx.emit(BattleEvent.DAMAGE, packet.victim_side(), payload)


## 便捷入口：造一包伤害并当场结算。附火、反伤、以血为代价都走这里；要先改包（暴击旗）的 [DealDamage] 自己造包
static func deal(
	ctx: BattleContext, victim: CombatantRuntime, raw: int,
	type: StringName = DamageTypes.PHYSICAL,
	source_side: int = -1, source_uid: int = 0, direct: bool = false
) -> int:
	return resolve(ctx, DamagePacket.create(type, raw, victim, source_side, source_uid, direct))
