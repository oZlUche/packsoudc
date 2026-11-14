## 经济规则（架构文档 6.6，M4-5）：打赢给多少钱、商店卖什么价、刷新多少钱、哪个撤离点收费。
##
## 作者的设想：打赢战斗获得货币，数量按敌人强度、所在深度与难度；商店售卖随机稀有度道具且可以刷新，
## 都花货币；一个中途撤离点是付费的，费用暂用 50 占位。
##
## 全是数据。章节按 id 引用（`ChapterDef.economy_rules`）；作者数据走内容管线：
## `data/authoring/economy_rules/*.json` → `data/economy_rules/*.tres`。
class_name EconomyRules
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("战斗奖励")
## 打赢一场 = (reward_base + reward_per_strength × 档位) × (1 + reward_depth_gain × 深度) × (1 + reward_difficulty_gain × 难度)，四舍五入
@export var reward_base: int = 10
## 敌人每高一档多给多少（档位 = 6.0 的强度档位，记在节点内容里）
@export var reward_per_strength: int = 10
## 最内（深度 1）比最外多几成
@export var reward_depth_gain: float = 1.0
## 难度每 +1 多几成
@export var reward_difficulty_gain: float = 0.25

@export_group("商店")
## 290（作者 11-07）：商人的货一次摆满、不刷新 —— 开张抽几件（不重复；再按概率加一个包、一件金银），摆不下的丢掉
@export var shop_stock: int = 10
## 290：商人钱袋 = shop_purse_base + shop_purse_depth × 深度（深处的商人有钱）；你付的进袋、他找的出袋，一局不回填
@export var shop_purse_base: int = 100
@export var shop_purse_depth: int = 200
## 货架上道具的稀有度权重，下标即稀有度；× (1 + shop_depth_gain × 深度 × 稀有度)，越深越容易见到好东西
@export var shop_rarity_weights: Array[float] = [40.0, 30.0, 20.0, 8.0, 2.0, 0.5]
@export var shop_depth_gain: float = 1.0
## 售价 = 道具价值（6.4 的 ItemValue）× 这个倍数
@export var shop_price_mult: float = 1.0
## 087（作者定）：卖给店里回定价的几成；251（作者 2026-10-24）：数据里写三成，带回基地五成（[member MetaRules.sell_ratio]）
@export var shop_sell_ratio: float = 0.5
## 不上架的道具标签（珍宝只从敌人身上掉）
@export var shop_exclude_tags: Array[StringName] = [&"treasure"]
## 209：每次上货有多大概率把一格换成包（从章节的包池按权重 × 稀有度权重抽）；0 = 不卖包
@export var shop_bag_slot_chance: float = 0.3
## 244：每次上货有多大概率把一格换成金银（一次最多一格）；0 = 不卖
@export var bullion_slot_chance: float = 0.35
## 244 补充一：金银那一格从哪几件里抽 —— 最外（深度 0）的权重表 id → 权重，和最内（深度 1）的那张按深度线性混合：外环见银、内环见金
@export var bullion_shallow: Dictionary = {"silver_nugget": 1.0, "silver_bar": 1.0, "silver_ingot_large": 1.0, "gold_nugget": 1.0}
@export var bullion_deep: Dictionary = {"gold_nugget": 1.0, "gold_bar": 1.0, "gold_ingot": 1.0, "silver_ingot_large": 1.0}
## 244：金银的售价 = 面值 × 这个数（不乘 [member shop_price_mult]、不乘 buff 的倍数 —— 打折买金、基地全价回收就成了白来的钱）
@export var bullion_premium: float = 1.1
## 160 补一：货架之外一排「随身」—— 候选的随身技能 id → 权重；开张时抽 1 ～ [member belt_picks] 种，成交了直接进腰带。空 = 没有这一排
@export var belt_stock: Dictionary = {}
@export_range(1, 4) var belt_picks: int = 2
## 319（局外机制树「局内商店刷新」）：换一次货要多少钱（局内的钱）。首轮试的数：比付费撤离点（50）便宜一点，约一件紫色货的价
@export var shop_refresh_price: int = 40

@export_group("付费撤离点")
## 几个中途撤离点收费（挑最深的那几个）
@export var paid_extracts: int = 1
## 收多少。50 是作者给的占位
@export var extract_fee: int = 50


func battle_reward(strength: int, depth: float, difficulty: int) -> int:
	var base := float(reward_base + reward_per_strength * maxi(0, strength))
	var mult := (1.0 + reward_depth_gain * clampf(depth, 0.0, 1.0)) * (1.0 + reward_difficulty_gain * float(maxi(0, difficulty)))
	return maxi(0, roundi(base * mult))


func shop_rarity_weight(rarity: int, depth: float) -> float:
	if shop_rarity_weights.is_empty():
		return 0.0
	var w := shop_rarity_weights[clampi(rarity, 0, shop_rarity_weights.size() - 1)]
	return maxf(0.0, w * (1.0 + shop_depth_gain * clampf(depth, 0.0, 1.0) * float(maxi(0, rarity))))


## 290：这个深度的商人开张带多少钱
func purse_at(depth: float) -> int:
	return maxi(0, shop_purse_base + roundi(float(shop_purse_depth) * clampf(depth, 0.0, 1.0)))


## 244 补充一：这个深度金银那一格的权重表（两张按深度线性混合；id 升序、权重为正的才在）
func bullion_weights(depth: float) -> Dictionary:
	var d := clampf(depth, 0.0, 1.0)
	var ids: Array[String] = []
	for k in bullion_shallow:
		ids.append(String(k))
	for k in bullion_deep:
		if not ids.has(String(k)):
			ids.append(String(k))
	ids.sort()
	var out := {}
	for id_ in ids:
		var w := float(bullion_shallow.get(id_, 0.0)) * (1.0 - d) + float(bullion_deep.get(id_, 0.0)) * d
		if w > 0.0:
			out[StringName(id_)] = w
	return out
