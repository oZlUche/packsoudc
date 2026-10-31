## 270（作者 2026-10-31 12:01 / 12:58）：集市的一个摊位。五个固定摊（药铺 / 粮铺 / 兵器铺 / 甲胄铺 / 杂货铺）按标签自动列货单、
## 稀有度到集市本级上限（[method Market.catalogue]），买了不减；散货摊（`fixed` 为假）是原来的木凉棚，随机进战斗道具（[method Market.restock]）。
##
## 走内容管线：`data/authoring/market_stalls/*.json` → `data/market_stalls/*.tres`（[method Market.stalls]）。加新道具贴对标签就自动上架
class_name StallDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的摊名（`{"en": "Apothecary"}`，[Names]）
@export var display_names: Dictionary = {}
## 左列摊位键的先后（小的在上）
@export var order: int = 0
## 固定摊：货单固定、不断货；假 = 散货摊（随机、能换货、能锁）
@export var fixed: bool = true
## 带其中一个标签就进这个摊的货单（散货摊不看，看 [member MarketRules.battle_tags]）
@export var tags: Array[StringName] = []
## 点名不进这个摊（集市整体的排除在 [member MarketRules.excluded_ids]）
@export var excluded_ids: Array[StringName] = []
