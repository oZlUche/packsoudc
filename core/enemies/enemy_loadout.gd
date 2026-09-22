## 组装规则：一个敌人背什么（架构文档 6.0）。
##
## 默认规则是「通用道具 + 流派道具」：件数由档位给，其中一部分从带流派标签的道具里抽，
## 其余从带通用标签的道具里抽。招牌道具先占位，计入件数。
##
## 池给一份默认的；某种敌人要不一样（纯流派、不带补给）就在 [member EnemyDef.loadout] 覆盖。
class_name EnemyLoadout
extends Resource

## 算作「通用」的道具标签（护甲、补给、工具、零件…）。带流派标签的道具不算通用，哪怕它也带这些标签
@export var common_tags: Array[StringName] = []

## 件数里流派道具的份额（0～1），四舍五入
@export var school_share: float = 0.5

## 至少几件流派道具（有得选的话）。没有流派道具的敌人就是个背补给的路人
@export var min_school: int = 1

## 稀有度上限，-1 不限。外环的小兵不该背传说品 —— 这是掉落的来源（5.10）
@export var rarity_cap: int = -1

## 同一件道具可否重复
@export var allow_repeat: bool = true
