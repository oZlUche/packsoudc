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

## 节点规则的 id（`data/node_rules/`，6.2 / 7.1）：随机点变什么、搜索怎么搜、输了扣多少、休息回多少。
## 空 = 踩到点只标用过，什么都不发生
@export var node_rules: StringName = &""

## 经济规则的 id（`data/economy_rules/`，6.6）：打赢给多少钱、商店、付费撤离点。空 = 这一章不算钱
@export var economy_rules: StringName = &""

@export_group("开局屏（083）")
## 开局屏上的先后（小的在前）；序章 0、第一章 1
@export var order: int = 0
## 局外解锁 id（[MetaState.unlocks]）：没解锁不列。空 = 一直可选
@export var requires_unlock: StringName = &""
## 撤离成功给的局外解锁 id（序章通关解锁第一章）。空 = 不给
@export var grants_unlock: StringName = &""
## 能选的角色 id；空 = 全部
@export var characters: Array[StringName] = []
## 开局能不能从仓库带东西进来（序章不能：教程从空包开始）
@export var allow_carry_in: bool = true
## 开局直接站在第一个出生点上，不用挑（084：序章只有一条路、一个出生点）
@export var auto_spawn: bool = false


## 这个角色在这一章能不能选
func allows_character(id: StringName) -> bool:
	return characters.is_empty() or characters.has(id)
