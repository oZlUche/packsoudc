## 一章：地图从哪来，加上将来的侵蚀日程、敌人池与掉落表（架构文档 5.3 / 7）。
##
## 它是作者数据，走内容管线（10 节）：`data/authoring/chapters/*.json` 导入成
## `data/chapters/*.tres`。导入器不认识它 —— 反射填字段，和道具一样。
##
## [b]现在只有地图。[/b] 侵蚀日程（第 7 阶段）、敌人池与掉落表（M4）到时候各加一个字段，
## 导入器、导出器、编辑器一行不改。
class_name ChapterDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 随机生成还是载入预设，见 5.3.1
@export var map_source: MapSource = null
