## 后果：一段话（结果页上显示，日志里也记）
class_name Say
extends EventOutcome

@export_multiline var text: String = ""
## 221 F2：别的语言的那段话，`{"en": "…"}`；按当前语言取，没写回落 text
@export var texts: Dictionary = {}


func apply(ctx: EventContext) -> void:
	if text == "":
		return
	var line := Names.pick(texts, text)
	# 事件方案 2026-11-11：`{reward_name}` 换成这次从池里发的那件的 `{item:…}`（最后一份），显示时和别的 `{item:…}` 一起上色
	for k in ctx.reward_names:
		line = line.replace("{reward_name}", "{item:%s}" % ctx.reward_names[k])
	ctx.log.append(line)


func describe() -> String:
	return "说一句「%s%s」" % [text.left(20), "…" if text.length() > 20 else ""]
