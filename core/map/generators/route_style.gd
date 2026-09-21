## 一种路线风格（架构文档 5.4.2）。
##
## 路线不是从生成好的图里事后找出来的 —— 每个出生点配一种风格，先铺路线再长地图。
## 风格之间不是「难度相同」，而是**风险与收益各在自己的档位上，且性价比相当**。
class_name RouteStyle
extends Resource

## "combat" / "search" / "mixed" …
@export var id: StringName = &""

## 该路线**独占**的节点里各类型的份额（比例，不必加到 1）。
## 偏战斗：`{"battle": 5, "elite": 1, "event": 1}`
## 偏搜索：`{"search": 4, "event": 2, "battle": 1}`
## [b]M3-3c 才用到。[/b]
@export var mix: Dictionary = {}

## 这条路线的风险分总和该落在哪个区间（相对全图平均）。[b]M3-3c 才用到。[/b]
@export var risk_band: Vector2 = Vector2(0.8, 1.2)

## 同上，收益分。低风险配低收益、高风险配高收益 —— 两个区间一起决定风格。
## [b]M3-3c 才用到。[/b]
@export var reward_band: Vector2 = Vector2(0.8, 1.2)

## 路线的尽头。
##
## [code]&"core"[/code] 走到核心打 BOSS；[code]&"extract"[/code] 在核心前一环结束，
## 末端定为撤离点 —— **偏搜索的路线可以不打最终敌人，搜够了就走**。
## 想打还是能打：换乘点还在。
@export var ends_at: StringName = &"core"

## 每隔几环在这条路线上放一个中途撤离点（0 = 不放）。
## 偏战斗的路线要靠它「战损过高就撤」。[b]M3-3c 才用到。[/b]
@export var bailout_every_rings: int = 0


func is_core_route() -> bool:
	return ends_at != &"extract"
