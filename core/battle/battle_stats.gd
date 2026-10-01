## 战斗属性的键名。
##
## 属性用 [StringName] 作键而不是枚举：属性之间彼此独立，没有像乘区那样的
## 「顺序影响取整」问题，因此内容可以自由新增键名而不牵动任何已有数值。
## 需要严格顺序约定的只有 [enum StatMath.Buff]。
class_name BattleStats
extends RefCounted

## 单次触发造成的伤害
const DAMAGE := &"damage"

## 基础冷却，单位：秒（定点）
const COOLDOWN := &"cooldown"

## 触发速度倍率，基础 1.0。越大越快。
## 冷却不直接吃加成 —— 「更快」在语义上是速度变大，而不是冷却时间变大，
## 若把加成加在 COOLDOWN 上，+20% 会让物品变慢，与直觉相反。
const HASTE := &"haste"

## 最大生命值
const MAX_HP := &"max_hp"

## 受到的最终伤害倍率，基准 1.0（103）。伤害管线在护盾、减伤、护甲都算完之后、落到血量之前乘它；
## 加时的「鏖战」是它的第一个用户，「易伤」减益也就是一条作用于它的普通 mod
const DAMAGE_TAKEN := &"damage_taken"

## 护甲，减伤用
const ARMOR := &"armor"

## 资源的上限属性统一以 max_ 开头。
##
## [b]资源由 max_* 属性自动派生[/b]：战斗单位扫描自己的属性表，
## 每发现一个 max_xxx 就开一个名为 xxx 的资源池。
## 新增一种资源（护盾、充能…）只需配一个 max_shield 属性，不改任何代码。
const MAX_PREFIX := "max_"

const RES_HP := &"hp"
const RES_STAMINA := &"stamina"
const RES_MANA := &"mana"
## 护盾。扣血之前先扣它，由伤害类型决定能不能吸收（见 [DamageResolver]）。
const RES_SHIELD := &"shield"

const MAX_STAMINA := &"max_stamina"
const MAX_MANA := &"max_mana"
const MAX_SHIELD := &"max_shield"

## 资源的每秒回复速率，统一以 regen_ 开头，与 max_ 对称。
##
## [b]它就是一条普通属性[/b] —— 所以「某某 buff 让耐力回得更快」不需要任何新机制，
## 一条作用于 regen_stamina 的 StatModifier 就够了，和增伤走的是同一条公式。
##
## 回复是**懒结算**的：没有定时器，也没有每秒一次的事件。
## 推进器每到一个时刻，才按「距上次结算过了多久 × 当时的速率」补上，
## 见 [method CombatantRuntime.settle_regen]。
const REGEN_PREFIX := "regen_"

const REGEN_STAMINA := &"regen_stamina"
const REGEN_HP := &"regen_hp"

## 耐力消耗的面板值。走 4.3 公式结算，
## 因此「减少耐力消耗 20%」就是一条作用于本键的普通 StatModifier。
const STAMINA_COST := &"stamina_cost"
const MANA_COST := &"mana_cost"


## 属性的默认基础值。
##
## 绝大多数属性（伤害、护甲、上限）默认 0，加成从 0 起累加。
## 但**乘法单位元类的属性默认必须是 1.0** —— haste 是速度倍率，
## 没人给它设基础值时它应当是 1.0 而不是 0。
##
## 这条很要命：若默认 0，任何给 haste 加百分比的 buff 都会算出 0 × (1+x) = 0，
## 冷却随之被放大上万倍。新增倍率类属性时记得登记在这里。
const DEFAULT_BASE := {
	HASTE: 1,  # 占位，实际值由 default_base() 换算成定点
	DAMAGE_TAKEN: 1,
}


## 该属性在未被显式设置时的基础值（定点）
static func default_base(key: StringName) -> int:
	return StatMath.ONE if DEFAULT_BASE.has(key) else 0


## max_xxx -> xxx；不是上限属性则返回空
static func resource_of_max(stat_key: StringName) -> StringName:
	var s := String(stat_key)
	if not s.begins_with(MAX_PREFIX):
		return &""
	return StringName(s.substr(MAX_PREFIX.length()))


## xxx -> regen_xxx
static func regen_of_resource(resource_key: StringName) -> StringName:
	return StringName(REGEN_PREFIX + String(resource_key))


## xxx -> max_xxx
static func max_of_resource(resource_key: StringName) -> StringName:
	return StringName(MAX_PREFIX + String(resource_key))
