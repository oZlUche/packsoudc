## 后果：一段话（结果页上显示，日志里也记）
class_name Say
extends EventOutcome

@export_multiline var text: String = ""


func apply(ctx: EventContext) -> void:
	if text != "":
		ctx.log.append(text)


func describe() -> String:
	return "说一句「%s%s」" % [text.left(20), "…" if text.length() > 20 else ""]
