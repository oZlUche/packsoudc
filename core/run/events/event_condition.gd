## 事件选项的一个条件（构件）：看一眼一局的状态，说能不能选。**只读**，不改任何东西。
## 登记在 [RunRegistry.EVENT_CONDITIONS]；加一种 = 加一个子类、登记一行。
@abstract
class_name EventCondition
extends Resource

@abstract func check(ctx: EventContext) -> bool

## 不满足时给玩家看的一句话（灰掉的选项旁边）
func describe() -> String:
	return ""
