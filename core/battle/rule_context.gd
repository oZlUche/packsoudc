## 一条规则求值时的上下文。时机、频率、消耗、效果四层共用它。
##
## 它是效果访问战场的**唯一入口** —— 效果不持有 [BattleSim] 的引用，
## 也不知道模拟循环怎么跑，这样循环重构时效果无需改动。
class_name RuleContext
extends RefCounted

var battle: BattleContext
var owner: CombatantRuntime
var runtime: RuleRuntime


static func create(p_battle: BattleContext, p_owner: CombatantRuntime, p_rt: RuleRuntime) -> RuleContext:
	var c := RuleContext.new()
	c.battle = p_battle
	c.owner = p_owner
	c.runtime = p_rt
	return c


func opponent() -> CombatantRuntime:
	return battle.opponent_of(owner)


## 取属性值。规则来自物品时按该物品的粒度取（伤害、冷却、消耗都属于单件物品）；
## 规则来自 buff 或套装时退回单位级。
func item_stat(key: StringName, fallback: int = 0) -> int:
	var uid := runtime.source_uid
	if uid == 0:
		return owner.stat(key, fallback)
	return owner.item_stat(uid, key, fallback)


func rng() -> RandomNumberGenerator:
	return battle.rng


## 117：取随机数并记进内部日志（[method BattleContext.roll]）。战斗里的掷骰都走它
func roll(purpose: String, lo: int, hi: int, need: int = -1) -> int:
	return battle.roll(purpose, lo, hi, need)


## 本条规则的持久状态（冷却进度、命中计数…）。
## 同一条 AbilityRule 资源可能被多件物品共用，状态只能存在这里。
func state() -> Dictionary:
	return runtime.state


## 来源物品 uid；0 表示这条规则来自 buff 或套装
func source_uid() -> int:
	return runtime.source_uid


## 规则来自 buff 时，这里是该 buff 的实例（供「每层 N 点伤害」取层数）
func source_buff() -> BuffInstance:
	return runtime.buff


func source_stacks() -> int:
	return runtime.buff.stacks if runtime.buff != null else 1


## 正在结算的那一包伤害；不在受伤前阶段时为 null。
##
## [ModifyDamage] 靠它改写伤害。放在上下文上而不是事件载荷里，
## 是因为效果拿到的只有上下文 —— 事件在时机层就被消费掉了。
func damage() -> DamagePacket:
	return battle.current_damage()


func emit(name: StringName, payload: Dictionary = {}) -> void:
	battle.emit(name, owner.side, payload)
