## 事件的一个选项：一行字，若干条件（都满足才能选），若干后果（按顺序执行）。
class_name EventOption
extends Resource

@export var label: String = ""
## 091：别的语言的选项文字，`{"en": "..."}`；事件屏用 [method label_for] 取
@export var labels: Dictionary = {}
## 标签（082）：信力的「在事件中选特定选项」按它认（[EventChoiceDeed.tag]）；别的机制以后也可以看
@export var tags: Array[StringName] = []
## 条件不满足时：灰掉（默认）还是干脆不显示
@export var hide_when_locked: bool = false
## 113：条件没过时给玩家看的一句（模板，可用占位符）。不显示的选项在事件屏底部灰字显示它；灰掉的选项用它替代条件的默认说明。
## 教程的门禁靠它说「为什么现在不行」（「先把护符放进包里」）
@export var hint_when_hidden: String = ""
@export var requires: Array[EventCondition] = []
@export var outcomes: Array[EventOutcome] = []


## 当前语言（或指定语言）下的选项文字；没写回落 label（[method Names.pick]）
func label_for(lang: String = "") -> String:
	return Names.pick(labels, label, lang)


## 每一条条件都过了才能选。返回第一条没过的说明；空串 = 能选
func locked_reason(ctx: EventContext) -> String:
	for c in requires:
		var cond := c as EventCondition
		if cond != null and not cond.check(ctx):
			return cond.describe()
	return ""
