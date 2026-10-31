## 251：基地集市的规矩 —— 每级几格、到哪一档稀有度、卖什么不卖什么、价钱倍数。下标 0 = 第 1 级，级数比表长按最后一项。
## 270：分摊位 —— 五个固定摊按 [member rarity_cap_per_level] 列货单（[StallDef]）；散货摊按级 [member slots_per_level] 个货位，
## 只进 [member battle_tags]，稀有度从 [member loose_rarity_min] 起按 [member loose_rarity_weights] 抽，能花钱换货（[member refresh_cost]）。
##
## 走内容管线：`data/authoring/base_rules/market.json` → `data/base_rules/market.tres`（[method Market.load_rules]）。数都是占位，作者改 json
class_name MarketRules
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 散货摊每级几个货位
@export var slots_per_level: Array[int] = [4, 6, 8]
## 固定摊每级卖到哪一档稀有度（0 白 / 1 绿 / 2 蓝）
@export var rarity_cap_per_level: Array[int] = [0, 1, 2]
## 270 待定 1：固定摊本级货单不到这么多件，从下一档按价从低到高补到这么多件（白货补齐了自然不用）
@export var stall_min_listed: int = 3
## 买价 = 价值 × 它（基地回收 0.5，没有套利）
@export var price_mult: float = 1.0
## 270：散货摊只进带其中一个标签的（战斗道具）
@export var battle_tags: Array[StringName] = [&"weapon", &"armor", &"shield", &"trinket", &"ammo", &"remedy"]
## 270：散货摊最低稀有度（1 = 绿）
@export var loose_rarity_min: int = 1
## 270：散货摊稀有度抽签权重，下标 0 = [member loose_rarity_min] 那一档（绿 / 蓝 / 紫 / 金 / 红）；不受级数上限；某档没货就不抽它
@export var loose_rarity_weights: Array[float] = [50.0, 30.0, 14.0, 5.0, 1.0]
## 270：散货摊换货价 = 它 + [member refresh_step] × 这次在家已换的次数（回一局归零）
@export var refresh_cost: int = 40
@export var refresh_step: int = 20
## 带其中一个标签就不上架（珍宝、贵重品、金银、特殊道具、铸牌、封存件）；250：信物（带 `faith:<神>`）在 [Market] 里按前缀拦
@export var excluded_tags: Array[StringName] = [&"treasure", &"valuable", &"bullion", &"keepsake", &"token", &"sealed"]
## 252：点名不上架的道具（秘银锭只从铁匠铺来）
@export var excluded_ids: Array[StringName] = []
## 第几级起散货摊最后一格换成一只空包（0 = 不卖包）
@export var bag_slot_from_level: int = 3
## 空包从哪张包池抽
@export var bag_pool: StringName = &"standard"


func slots_at(level: int) -> int:
	return _at(slots_per_level, level, 0)


func rarity_cap_at(level: int) -> int:
	return _at(rarity_cap_per_level, level, -1)


## 散货摊这一档稀有度的权重（不在表里 = 0，抽不到）
func loose_weight(rarity: int) -> float:
	var k := rarity - loose_rarity_min
	if k < 0 or k >= loose_rarity_weights.size():
		return 0.0
	return maxf(0.0, loose_rarity_weights[k])


static func _at(list: Array, level: int, none: int) -> int:
	if level <= 0 or list.is_empty():
		return none
	return int(list[mini(level, list.size()) - 1])
