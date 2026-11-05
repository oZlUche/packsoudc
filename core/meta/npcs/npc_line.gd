## 282（作者 2026-11-05 12:42）：NPC 的一句闲话。台词留空给作者写（道具说明那条规则）
class_name NpcLine
extends Resource

const LORE := &"lore"
const GUIDE := &"guide"
const KINDS: Array[StringName] = [LORE, GUIDE]

@export var id: StringName = &""
## 世界观 `lore` / 指引 `guide`
@export var kind: StringName = LORE
@export var text: String = ""
## 别的语言（`{"en": "..."}`）
@export var texts: Dictionary = {}
## 开放条件（事件那套）；空 = 随时能说
@export var requires: Array[EventCondition] = []
