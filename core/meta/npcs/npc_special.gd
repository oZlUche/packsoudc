## 282：NPC 的专属对话 —— 条件都满足时优先于闲聊、一辈子只说一次（[member MetaState.npc_done]），说完可以给一件道具进仓库
class_name NpcSpecial
extends Resource

@export var id: StringName = &""
@export var text: String = ""
@export var texts: Dictionary = {}
@export var requires: Array[EventCondition] = []
## 说完给的道具（空 = 不给）；独一道具过 [UniqueItems] 闸
@export var give: StringName = &""
