## 玩家输给猎手之后发生的事（构件，登记在 [EffectRegistry.HUNTER_LOSSES]；069 第七节第 2 条：保留所有选项）。
## 一个猎手定义写一串，按顺序执行。加一种 = 一个子类、登记一行。
@abstract
class_name HunterLossOutcome
extends Resource

@abstract func apply(h: Hunter, sys: HunterSystem) -> void

func describe() -> String:
	return ""
