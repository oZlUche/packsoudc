## 一种敌人（架构文档 5.10 / 6.0，M4-1）。
##
## [b]敌人就是一个背包。[/b] 它不带固定的棋盘 —— 棋盘是按规则**组装**出来的：
## 「通用道具 + 流派道具」（[EnemyLoadout]），件数由强度档位定（[StrengthTier]）。
## 同一种敌人在外环是档位 0 背两件，到了核心附近是档位 3 背七件 —— 定义里只写它的
## **本色档位** [member strength]（用来在池里按想要的档位挑人）与**流派** [member schools]。
##
## 流派是标签，可以有多个：「混伤型」不是一种流派，是同时带两个流派的敌人。
## 道具按 [member ItemDef.tags] 里带没带这个流派名归到流派里 —— 新增一种流派 = 给几件道具打上标签，
## 再写一个带这个标签的敌人，代码一行不改。
##
## 作者数据，走内容管线：`data/authoring/enemies/*.json` → `data/enemies/*.tres`。
class_name EnemyDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 本色档位（0 起）。池按节点算出想要的档位后，在 ± tolerance 内挑本色接近的敌人；
## 实际用哪个档位组装，记在节点内容里（`content.strength`），不一定等于本色
@export var strength: int = 0

## 流派标签，可多个。组装时按它挑流派道具
@export var schools: Array[StringName] = []

## 基线属性覆盖（max_hp、armor…）。没写的键用 [CombatantBaseline] 的默认值；
## 档位表的 [member StrengthTier.stat_scale] 再乘上去
@export var base_stats: Dictionary = {}

## 招牌道具：一定背着的道具 id，计入件数。屠夫总带着刀
@export var signature: Array[StringName] = []

## 覆盖池的默认组装规则。null = 用池的
@export var loadout: EnemyLoadout = null

## 覆盖档位表的棋盘尺寸。零 = 用档位表的
@export var board: Vector2i = Vector2i.ZERO


func is_valid() -> bool:
	return id != &"" and strength >= 0
