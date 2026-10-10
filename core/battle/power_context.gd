## 151：估一件道具的战斗力时，构件的估值方法看到的那份「假定的战场」—— 系数表、这件的属性、它自己多快出手、
## 此刻是从谁的角度估（自己 / 对手）、按层数算的效果假定几层、能查到的 buff 定义。
##
## 估值都是**从「主人」的角度**带符号的数：打对手、给自己增益为正；伤自己、给自己减益、给对手增益为负。
## 估 buff 自己的规则时换一份上下文，主人 = 挂着这个 buff 的那一边（[method for_carrier]）
class_name PowerContext
extends RefCounted

var weights: PowerWeights = null
## 这件道具的属性（估直接伤害、冷却用）
var stats: StatSet = null
## 这件道具这一边的直接伤害 DPS 与一秒出手几次（基础 B 那部分）
var own_dps: float = 0.0
var own_hz: float = 0.0
## 主人是不是这件道具这一边（false = 估的是对手身上的东西，主人是对手）
var is_owner: bool = true
## 按层数算的效果（per_stack、按对手层数、清光全部）假定几层；0 = 用系数表的 assumed_stacks
var stacks: float = 0.0
## 这条规则的扳机看的是主人受击（true）还是主人出手（false）：伤害修正、反伤按哪一下算
var incoming: bool = true
## id → [BuffDef]（编辑器给内容库里的；查不到按 unknown_buff_value）
var buffs: Dictionary = {}
## 本件一秒施加某 buff 几层（id → 层 / 秒），门槛扳机（到了几层、施加了某 buff 时）按它算
var applied_rate: Dictionary = {}
## 防止 buff 套 buff 无限递归
var depth: int = 0


func stacks_or_assumed() -> float:
	return stacks if stacks > 0.0 else weights.assumed_stacks


## 主人的直接伤害 DPS（加伤、加速的百分比按它算）
func dps() -> float:
	return own_dps if is_owner else weights.opponent_dps


## 主人一秒出手几次
func hz() -> float:
	return own_hz if is_owner else weights.hit_rate


## 对面的直接伤害 DPS
func other_dps() -> float:
	return weights.opponent_dps if is_owner else own_dps


## 主人这一下直接攻击平均多大
func hit_size() -> float:
	return dps() / hz() if hz() > 0.0 else weights.opponent_dps / maxf(0.01, weights.hit_rate)


## 对面打主人的那一下平均多大
func incoming_hit() -> float:
	var other_hz := weights.hit_rate if is_owner else own_hz
	return other_dps() / maxf(0.01, other_hz)


## 主人一秒挨几下
func hits_taken() -> float:
	return weights.hit_rate if is_owner else own_hz


## 换到挂着某 buff 的那一边（[param on_owner] 真 = 主人自己身上，假 = 主人的对手身上）
func for_carrier(on_owner: bool) -> PowerContext:
	var c := PowerContext.new()
	c.weights = weights
	c.stats = StatSet.new()
	c.own_dps = own_dps
	c.own_hz = own_hz
	c.is_owner = is_owner if on_owner else not is_owner
	c.stacks = 1.0
	c.buffs = buffs
	c.depth = depth + 1
	return c


func buff(id: StringName) -> BuffDef:
	return buffs.get(id, null)


## 同一份，只是「按层数」假定成 [param n] 层（门槛扳机的规则）
func with_stacks(n: float) -> PowerContext:
	var c := PowerContext.new()
	c.weights = weights
	c.stats = stats
	c.own_dps = own_dps
	c.own_hz = own_hz
	c.is_owner = is_owner
	c.stacks = n
	c.incoming = incoming
	c.buffs = buffs
	c.applied_rate = applied_rate
	c.depth = depth
	return c


## 主人身上一条属性修饰每秒值多少（buff 的 mods）。认不出的属性 0
func stat_value(stat: StringName, mode: StatModifier.Mode, amount: float) -> float:
	var mult := mode == StatModifier.Mode.MULT
	var w := weights
	match stat:
		BattleStats.DAMAGE:
			return amount / 100.0 * dps() if mult else amount * hz()
		BattleStats.HASTE:
			return amount / 100.0 * dps() if mult else amount * dps()
		BattleStats.COOLDOWN:
			if mult:
				return -amount / 100.0 * dps()
			return dps() * (1.0 / maxf(0.01, 1.0 + amount * hz()) - 1.0)
		BattleStats.ARMOR:
			return 0.0 if mult else amount * hits_taken()
		BattleStats.MAX_HP:
			var hp := amount / 100.0 * w.assumed_hp if mult else amount
			return hp * w.heal_weight / maxf(1.0, w.horizon_sec)
		BattleStats.REGEN_HP:
			return 0.0 if mult else amount * w.heal_weight
		BattleStats.REGEN_STAMINA:
			return 0.0 if mult else amount * w.stamina_weight
		BattleStats.CRIT_CHANCE:
			return amount * dps()
		BattleStats.CRIT_DAMAGE:
			return amount * w.crit_rate * dps()
		BattleStats.STAMINA_COST:
			return -amount / 100.0 * w.stamina_regen * w.stamina_weight if mult else -amount * hz() * w.stamina_weight
	return 0.0


## 主人身上一层轴（103）每秒值多少（正层；负层由调用方乘负的层数）
func axis_value(axis: StringName) -> float:
	var step := StatAxes.step_of(axis)
	var w := weights
	match axis:
		StatAxes.ATTACK_SPEED, StatAxes.DAMAGE_DEALT:
			return step / 100.0 * dps()
		StatAxes.DAMAGE_TAKEN:
			return -step / 100.0 * other_dps()
		StatAxes.REGEN_HP:
			return step * w.heal_weight
		StatAxes.REGEN_HP_PCT:
			return step / 100.0 * w.assumed_hp * w.heal_weight
		StatAxes.REGEN_STAMINA:
			return step * w.stamina_weight
		StatAxes.CRIT_CHANCE:
			return step * dps()
		StatAxes.CRIT_DAMAGE:
			return step * w.crit_rate * dps()
		StatAxes.STAMINA_COST:
			return (1.0 - step / 100.0) * w.stamina_regen * w.stamina_weight
		StatAxes.ARMOR:
			return step * hits_taken()
		StatAxes.MAX_HP:
			return step * w.heal_weight / maxf(1.0, w.horizon_sec)
	return 0.0
