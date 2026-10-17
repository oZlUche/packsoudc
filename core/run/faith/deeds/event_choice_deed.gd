## 在事件中选特定的选项：选项带 [member tag] 标签（[EventOption.tags]）的给 amount 点；tag 为空 = 任何选项
class_name EventChoiceDeed
extends FaithDeed

@export var tag: StringName = &""


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"event_choice":
		return 0
	if tag == &"":
		return amount
	for t in payload.get("tags", []):
		if StringName(String(t)) == tag:
			return amount
	return 0


func describe() -> String:
	return ("事件里选带「%s」的选项 +%d" % [Glossary.tag_name(tag), amount]) if tag != &"" else ("事件里做选择 +%d" % amount)
