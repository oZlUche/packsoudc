## 伤害结算管线（架构文档 4.6）。
##
## [b]一切血量的减少都走这里[/b] —— 武器命中、持续伤害、以血为代价的自伤，
## 区别只在伤害类型。这样减伤、护盾、免疫、反转只需要实现一次。
##
## 五步，顺序不可调换：
## [codeblock]
## 1. 确认类型      这一下能不能被护盾吸收、吃不吃护甲、要不要通知
## 2. 护盾吸收      能吸收则先扣护盾，中毒之类绕过
## 3. 受伤前效果    【同步派发】效果在这里改写伤害包：减伤、反转、免疫
## 4. 计算受伤量    百分比 → 固定增减 → 反转 → 护甲，然后落到血量
## 5. 受伤后效果    发 damage 事件；流失类不通知默认监听
## [endcodeblock]
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

	# --- 2. 护盾吸收 ---
	# 放在受伤前效果之前，是因为「这一下还剩多少要扛」本身就是减伤效果的判断依据。
	if td.shield_absorbable and packet.raw > 0:
		var pool := victim.resources
		if pool.has(BattleStats.RES_SHIELD):
			var take := mini(pool.current(BattleStats.RES_SHIELD), packet.raw)
			if take > 0:
				pool.change(BattleStats.RES_SHIELD, -take, BattleEvent.REASON_ABSORBED)
				packet.absorbed = take

	# --- 3. 受伤前效果。同步派发，不入队 —— 排队就赶不上这次结算了 ---
	ctx.dispatch_before_damage(packet)

	if packet.cancelled:
		packet.final = 0
		packet.applied = 0
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
	# 护甲只挡伤害，不挡治疗
	if amount > 0 and td.armor_applies:
		packet.armor = mini(victim.stat(BattleStats.ARMOR, 0), amount)
		amount -= packet.armor
	packet.final = amount

	if amount > 0:
		packet.applied = victim.resources.change(
			BattleStats.RES_HP, -amount, BattleEvent.REASON_DAMAGE
		)
		# 093（蛮神 4 级）：坚持期里血停在 0，扣不动 —— 但受到的伤害**照记**（作者定），事件里的 amount 是真实伤害
		if victim.undying_active() and -packet.applied < amount:
			packet.applied = -amount
	elif amount < 0:
		packet.applied = victim.resources.change(
			BattleStats.RES_HP, -amount, BattleEvent.REASON_HEAL
		)

	# --- 5. 受伤后 ---
	_notify(ctx, packet, td)
	if victim.resources.current(BattleStats.RES_HP) <= 0 and victim.mark_dead():
		ctx.emit(BattleEvent.DIED, victim.side, {})
	return -packet.applied


## 发出 damage 事件。
##
## [b]不招致反应的类型也照发。[/b] 过滤发生在扳机那一侧（[DamageTrigger] 默认只认
## provokes 为真的类型），而不是这里不发 —— 不发的话「中毒时净化」「流失时回气」
## 这类联动就永远没有接入点，而那正是我们想留的口子。
static func _notify(ctx: BattleContext, packet: DamagePacket, td: DamageTypeDef) -> void:
	ctx.emit(BattleEvent.DAMAGE, packet.victim_side(), {
		"type": String(packet.type),
		"raw": packet.raw,
		"absorbed": packet.absorbed,
		"armor": packet.armor,
		"amount": -packet.applied,
		"provokes": td.provokes,
		"source_side": packet.source_side,
		"uid": packet.source_uid,
	})


## 便捷入口：造一包伤害并当场结算。
static func deal(
	ctx: BattleContext, victim: CombatantRuntime, raw: int,
	type: StringName = DamageTypes.PHYSICAL,
	source_side: int = -1, source_uid: int = 0
) -> int:
	return resolve(ctx, DamagePacket.create(type, raw, victim, source_side, source_uid))
