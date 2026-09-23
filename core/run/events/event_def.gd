## 一个事件（059 的事件层，报告 063）：踩上一个点先看到的那一屏 —— 文字、图像、几个选项，选项决定后续。
##
## 走内容管线：`data/authoring/events/*.json` → `data/events/*.tres`。节点怎么拿到事件见 [NodeRules.events_by_type] 与 [EventPlacer]：
## 生成地图时按 `content_seed` 定进节点内容（`node.content["event"]`），可以被覆盖或替换（作者：不要写死）。
##
## 选项的条件（[EventCondition]）与后果（[EventOutcome]）都是构件、走注册表：加一种条件或后果不改这里、不改导入器。
class_name EventDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
## 正文（多行）
@export_multiline var text: String = ""
## 图像路径，占位：没有文件就画一块底色写路径
@export var image: String = ""
@export var options: Array[EventOption] = []
