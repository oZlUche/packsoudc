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

## 104（作者定）：暴击。暴击率是概率（0.10 = 10%），暴击伤害是倍率（1.5 = 150%）。
## **所有加成一律加算**：这两条只接受固定值（flat），导入器拦乘区（[method additive_only]）。
## 判定在 [DealDamage]：只对从属性取伤害的那一包掷，固定值伤害（灼烧这类）不暴击
const CRIT_CHANCE := &"crit_chance"
const CRIT_DAMAGE := &"crit_damage"


## 属性的默认基础值。
##
## 绝大多数属性（伤害、护甲、上限）默认 0，加成从 0 起累加。
## 但**乘法单位元类的属性默认必须是 1.0** —— haste 是速度倍率，
## 没人给它设基础值时它应当是 1.0 而不是 0。
##
## 这条很要命：若默认 0，任何给 haste 加百分比的 buff 都会算出 0 × (1+x) = 0，
## 冷却随之被放大上万倍。新增倍率类属性时记得登记在这里。
##
## 104：这张表是**真的默认值**（不只是「单位元 1.0」）：暴击率 10%、暴击伤害 150%。
## 表里的属性不跨物品累加（见 [CombatantRuntime]），没写的物品取到的就是这里的值
const DEFAULT_BASE := {
	HASTE: 1.0,
	CRIT_CHANCE: 0.10,
	CRIT_DAMAGE: 1.5,
}

## 104：只接受固定值加成的属性（作者定「所有加成都是加算」）
const ADDITIVE_ONLY: Array[StringName] = [CRIT_CHANCE, CRIT_DAMAGE]
## 104：给人看时按百分数显示的属性（0.05 → 5%）
const PERCENT_DISPLAY: Array[StringName] = [CRIT_CHANCE, CRIT_DAMAGE]


## 该属性在未被显式设置时的基础值（定点）
static func default_base(key: StringName) -> int:
	return StatMath.from_float(float(DEFAULT_BASE[key])) if DEFAULT_BASE.has(key) else 0


## 默认值（浮点，给作者数据与界面用）
static func default_value(key: StringName) -> float:
	return float(DEFAULT_BASE.get(key, 0.0))


static func additive_only(key: StringName) -> bool:
	return ADDITIVE_ONLY.has(key)


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
