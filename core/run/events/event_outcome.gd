## 事件选项的一个后果（构件）：往一局的状态上做一件事，或者在上下文里立一面旗（开战、开搜索、接下一个事件）让 [NodeEvents] 接着走。
## 登记在 [EffectRegistry.EVENT_OUTCOMES]；加一种 = 加一个子类、登记一行。
@abstract
class_name EventOutcome
extends Resource

@abstract func apply(ctx: EventContext) -> void

## 给编辑器看的一句话
func describe() -> String:
	return ""
