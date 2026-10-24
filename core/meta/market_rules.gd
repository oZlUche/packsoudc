## 251：基地集市的规矩 —— 每级几格、素材 / 消耗品到哪一档稀有度、卖什么不卖什么、价钱倍数。下标 0 = 第 1 级，级数比表长按最后一项。
##
## 走内容管线：`data/authoring/base_rules/market.json` → `data/base_rules/market.tres`（[method Market.load_rules]）。数都是占位，作者改 json
class_name MarketRules
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 每级几格货
@export var slots_per_level: Array[int] = [4, 6, 8]
## 每级素材到哪一档稀有度（0 白 / 1 绿 / 2 蓝）
@export var rarity_cap_per_level: Array[int] = [0, 1, 2]
## 每级消耗品（药 / 食 / 弹药）到哪一档
@export var consumable_rarity_cap_per_level: Array[int] = [1, 2, 2]
## 买价 = 价值 × 它（基地回收 0.5，没有套利）
@export var price_mult: float = 1.0
## 每次上货素材至少占几成格（向上取整）
@export var material_share: float = 0.5
## 稀有度抽签权重（下标 = 稀有度；比表长按最后一项）
@export var rarity_weights: Array[float] = [40.0, 30.0, 20.0]
## 卖哪几类：带其中一个标签才上架（`material` 是素材，其余算消耗品）
@export var allowed_tags: Array[StringName] = [&"remedy", &"food", &"ammo", &"material"]
## 带其中一个标签就不上架（珍宝、贵重品、金银、特殊道具、铸牌、封存件）；250：信物（带 `faith:<神>`）在 [Market] 里按前缀拦
@export var excluded_tags: Array[StringName] = [&"treasure", &"valuable", &"bullion", &"keepsake", &"token", &"sealed"]
## 第几级起最后一格换成一只空包（0 = 不卖包）
@export var bag_slot_from_level: int = 3
## 空包从哪张包池抽
@export var bag_pool: StringName = &"standard"


func slots_at(level: int) -> int:
	return _at(slots_per_level, level, 0)


func rarity_cap_at(level: int) -> int:
	return _at(rarity_cap_per_level, level, -1)


func consumable_cap_at(level: int) -> int:
	return _at(consumable_rarity_cap_per_level, level, -1)


func rarity_weight(rarity: int) -> float:
	if rarity_weights.is_empty():
		return 1.0
	return maxf(0.0, rarity_weights[clampi(rarity, 0, rarity_weights.size() - 1)])


static func _at(list: Array, level: int, none: int) -> int:
	if level <= 0 or list.is_empty():
		return none
	return int(list[mini(level, list.size()) - 1])
