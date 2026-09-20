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


## 按 target 解出实际作用对象
static func resolve_targets(ctx: RuleContext, target: Target) -> Array[CombatantRuntime]:
	match target:
		Target.SELF:
			return [ctx.owner] as Array[CombatantRuntime]
		Target.OPPONENT:
			return [ctx.opponent()] as Array[CombatantRuntime]
		_:
			return [ctx.owner, ctx.opponent()] as Array[CombatantRuntime]
