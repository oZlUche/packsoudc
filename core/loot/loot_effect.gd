## 战利品作用域的效果。
##
## [b]不依赖扳机。[/b] 只要处于激活状态，进入战利品掉落计算阶段就生效 ——
## 这是它与 [CombatEffect] 最根本的区别，也是它不需要 [Trigger] 的原因。
##
## 掉落系统（M4）尚未实现，[LootContext] 是它的接口约定。
@abstract
class_name LootEffect
extends Effect

func scope() -> StringName:
	return EffectScope.LOOT


## 在掉落计算阶段被调用，就地修改掉落上下文。
@abstract func modify(ctx: LootContext) -> void
