## 282（作者 2026-11-05 12:42）：NPC 的一句闲话。台词留空给作者写（道具说明那条规则）
class_name NpcLine
extends Resource

const LORE := &"lore"
const GUIDE := &"guide"
## 300 §2.2：问候 —— 进屏自动说一句（[method NpcChatter.greet]），不进点头像掷的池子
const GREET := &"greet"
const KINDS: Array[StringName] = [LORE, GUIDE, GREET]

@export var id: StringName = &""
## 世界观 `lore` / 指引 `guide` / 问候 `greet`
@export var kind: StringName = LORE
@export var text: String = ""
## 别的语言（`{"en": "..."}`）
@export var texts: Dictionary = {}
## 开放条件（事件那套）；空 = 随时能说
@export var requires: Array[EventCondition] = []
