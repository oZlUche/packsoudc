## 一章：地图从哪来，加上将来的侵蚀日程、敌人池与掉落表（架构文档 5.3 / 7）。
##
## 它是作者数据，走内容管线（10 节）：`data/authoring/chapters/*.json` 导入成
## `data/chapters/*.tres`。导入器不认识它 —— 反射填字段，和道具一样。
##
## 侵蚀日程（第 7 阶段）、掉落表（M4-2）到时候各加一个字段，导入器、导出器、编辑器一行不改 ——
## 敌人池（M4-1）就是这么加进来的。
class_name ChapterDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 随机生成还是载入预设，见 5.3.1
@export var map_source: MapSource = null

## 敌人池的 id（`data/enemy_pools/`，6.0）。空 = 这一章没有敌人（战斗点空着）。
## 按 id 引用而不是内联：几章共用一个池、只改难度是常态
@export var enemy_pool: StringName = &""

## 章节难度，0 起。敌人池的 [StrengthRule] 按它抬档位，掉落规则按它加掉落率；侵蚀将来也看它
@export var difficulty: int = 0

## 掉落规则的 id（`data/drop_rules/`，6.1）。空 = 这一章什么都不掉
@export var drop_rule: StringName = &""
