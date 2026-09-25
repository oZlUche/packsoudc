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
## 拿到这个局外解锁之后就不再列（084：教程通关就收起，下一张教程图顶上来直接开）。空 = 一直列
@export var hidden_by_unlock: StringName = &""
## 这一章开局多给的体力（084：第二张教程图两场都输也死不了）
@export var vitality_bonus: int = 0
## 开局能不能从仓库带东西进来（序章不能：教程从空包开始）
@export var allow_carry_in: bool = true
## 开局直接站在第一个出生点上，不用挑（084：序章只有一条路、一个出生点）
@export var auto_spawn: bool = false
## 不走开局屏（084，作者：序章不要开局页面）：主菜单「新的一局」时只有这一章可选就直接开，角色取这一章列的第一个、种子随机
@export var skip_setup: bool = false
## 开局先过的事件（intro）：站到出生点之后、地图能动之前弹一屏事件（`data/events/` 里的 id）。空 = 不弹
@export var intro_event: StringName = &""

@export_group("节点浮窗（084，第二章开放）")
## 鼠标移到节点上显示浮窗（敌人数据与背包 / 用过了 / 可能发生什么 / 值得搜）。作者：第二章才开，所以默认关
@export var node_tooltips: bool = false
## "default" 用内置模板；"custom" 用 [member tooltip_texts] 里按类别写的模板（缺的类别退回内置）
@export var tooltip_mode: String = "default"
## 类别 → 模板（占位符见 docs/text-placeholders.md：{battle_data}、{enemy_name}、{node_type}……）。类别：battle / visited / search / event / shop / rest / extract / random / other
@export var tooltip_texts: Dictionary = {}


## 这个角色在这一章能不能选
func allows_character(id: StringName) -> bool:
	return characters.is_empty() or characters.has(id)
