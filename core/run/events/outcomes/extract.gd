## 后果：从这个撤离点撤离（作者定：进撤离点和触发事件一样，先一段对话，选项里撤）。
## 只在撤离点上有意义；付费撤离点付不起就撤不了，事件的结果页会说。撤离本身还是 RunState.try_extract 那一套（付费、清会话、结算）
class_name ExtractOutcome
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.extract = true


func describe() -> String:
	return "从这个撤离点撤离"
