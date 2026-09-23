## 一局规则作用域的效果（059 的 buff 骨架）：体力上限、开局钱、多搜几次、商店价、幸运……
##
## [b]不依赖扳机。[/b] 只要 buff 处于激活状态，[RunState] 在对应的点算一次 [RunContext] 它就生效 ——
## 与 [LootEffect] 同一种做法：往上下文里加数，各系统读自己关心的那一项。
## 新加一种可改的机制 = [RunContext] 多一个字段 + 一个构件 + 那个系统去读，不改基类、不改导入器。
@abstract
class_name RunEffect
extends Effect

func scope() -> StringName:
	return EffectScope.RUN


## 往一局的上下文里加数
@abstract func modify(ctx: RunContext) -> void
