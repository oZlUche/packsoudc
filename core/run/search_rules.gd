## 搜索点的规则（架构文档 6.2，M4-3）：至多搜几次、每搜一次遭遇概率多高、每次找到几件、找到的东西多稀有。
##
## 作者原话：「可以搜索至多 N 次找战利品，每搜一次遭遇敌人的概率上升；随时可以离开」。
## 遭遇曲线是一张按次数的表（导入器要求非递减），找到的稀有度按深度与危险往上偏 —— 全是数据。
## 搜索点里遭遇的敌人**看不见**（5.10）：踩上去搜到了才知道，那是搜索的风险所在。
class_name SearchRules
extends Resource

## 至多搜几次
@export var max_searches: int = 3

## 第 k 次搜索（0 起）遭遇敌人的概率，非递减；超出表长按最后一档
@export var encounter_curve: Array[float] = [0.1, 0.25, 0.5]

## 每搜一次找到几件 [min, max]
@export var items_per_search: Vector2i = Vector2i(1, 2)

## 稀有度 → 基础权重，下标即稀有度；超出表长按最后一档
@export var rarity_weights: Array[float] = [50.0, 30.0, 15.0, 4.0, 1.0]

## 深度（0 最外 ～ 1 最内）把权重往高稀有度偏多少：权重 × (1 + depth_gain × depth × 稀有度)
@export var depth_gain: float = 1.0

## 危险等级（5.5）同上：权重 × (1 + danger_gain × danger × 稀有度)
@export var danger_gain: float = 0.5

## 不会搜出来的道具标签（珍宝只从敌人身上掉，6.1）
@export var exclude_tags: Array[StringName] = [&"treasure"]

## 搜出来的东西也算搜出来的包？默认不算 —— 包是玩家自己带的
@export var include_bags: bool = false

## 搜到的东西先摆进这么大的容器（塞不下会加高），搜刮界面拿它当容器
@export var haul_board: Vector2i = Vector2i(6, 4)


func encounter_chance(k: int) -> float:
	if encounter_curve.is_empty():
		return 0.0
	return clampf(encounter_curve[clampi(k, 0, encounter_curve.size() - 1)], 0.0, 1.0)


func rarity_weight(rarity: int, depth: float, danger: int) -> float:
	if rarity_weights.is_empty():
		return 0.0
	var base := rarity_weights[clampi(rarity, 0, rarity_weights.size() - 1)]
	var r := float(maxi(0, rarity))
	return maxf(0.0, base * (1.0 + depth_gain * clampf(depth, 0.0, 1.0) * r) * (1.0 + danger_gain * float(maxi(0, danger)) * r))
