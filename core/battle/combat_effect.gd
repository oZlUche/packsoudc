## 战斗作用域的效果：在战斗中实际做一件事。
##
## [b]必须同步完成。[/b] 战斗中没有任何玩家操作（4.1），效果不得等待玩家输入。
## 想表达「三选一」只能用随机（走 battle 随机流）或确定性规则，不能弹窗。
##
## 通过 [RuleContext] 访问战场，不持有 [BattleSim] 的引用 ——
## 这样模拟循环重构时效果无需改动。
@abstract
class_name CombatEffect
extends Effect

## 效果指向谁。
##
## [b]BOTH 是真的两边都作用[/b]，不是「任选其一」 ——
## 「双方各回 5 点耐力」「同时点燃自己和对手」用它。
enum Target { OPPONENT, SELF, BOTH }


func scope() -> StringName:
	return EffectScope.COMBAT


@abstract func apply(ctx: RuleContext) -> void


## 估算单次触发造成的伤害，供 UI 实时显示预估 DPS。
##
## 默认 0 表示「估不出来」。新增效果不实现它也不会出错，只是不参与 DPS 预估 ——
## 这比强迫每个子类都编一个数字诚实。
func estimated_damage(_stats: StatSet) -> float:
	return 0.0


## 151：战斗力估算 —— 触发一次值多少，**从主人的角度带符号**（打对手、给自己增益为正；伤自己、给自己减益、给对手增益为负），
## 单位是「抵几点伤害」。默认 NAN = 估不出来：估算器记零并在编辑器里标「未估」—— 新效果加一份估值，不是估算器的事
func estimated_value(_ctx: PowerContext) -> float:
	return NAN


## 151：重复触发打的折扣（零到一）：不可叠层的 buff 还在身上时再上一次是白费。[param rate] = 一秒触发几次
func estimated_cap(_ctx: PowerContext, _rate: float) -> float:
	return 1.0


## 151：作用对象的符号 —— 对手 +1、自己 −1、两边 0（同样的东西两边各来一份，抵掉）
static func side_sign(target: Target) -> float:
	match target:
		Target.OPPONENT:
			return 1.0
		Target.SELF:
			return -1.0
	return 0.0


## 这一包伤害算不算「直接伤害」（106 第八节，作者定）。
##
## 按**来源**定，不按伤害类型：规则属于某件道具（武器出手触发的）→ 直接；
## 规则来自 buff（灼烧、中毒、到期爆发）→ 非直接；套装 / 单位级规则（没有来源道具）→ 非直接。
## 格挡（加固 / 破绽）只减直接伤害。
## [param override] 是效果上的「另行说明」口子：−1 按来源默认，0 / 1 强制。
static func direct_of(ctx: RuleContext, override: int = -1) -> bool:
	if override >= 0:
		return override != 0
	return ctx.source_buff() == null and ctx.source_uid() != 0


## 按 target 解出实际作用对象
static func resolve_targets(ctx: RuleContext, target: Target) -> Array[CombatantRuntime]:
	match target:
		Target.SELF:
			return [ctx.owner] as Array[CombatantRuntime]
		Target.OPPONENT:
			return [ctx.opponent()] as Array[CombatantRuntime]
		_:
			return [ctx.owner, ctx.opponent()] as Array[CombatantRuntime]
