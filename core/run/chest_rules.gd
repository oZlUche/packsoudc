## 宝箱点的规则（154，作者定）：宝箱多稀有、开锁要按多久、开了能拿到什么。挂在 [member NodeRules.chest]，内容数据。
##
## 宝箱的稀有度生成地图时就定（[ChestPlacer]，5.10），写进 `node.content.chest`；开锁后的收获走现有的搜索会话
## （[method NodeEvents._open_chest]）：只搜一次、不遭遇、能出珍宝、件件不低于下限。
class_name ChestRules
extends Resource

## 每个节点档位（`MapNode.tier`，0 起）一行六个权重（下标 = 稀有度）；越深越肥。超出表长按最后一行
@export var rarity_by_tier: Array = [[60.0, 30.0, 10.0, 0.0, 0.0, 0.0], [20.0, 40.0, 30.0, 10.0, 0.0, 0.0], [0.0, 20.0, 40.0, 30.0, 10.0, 0.0]]
## 高危区（danger ≥ 2）的宝箱稀有度再加这么多，夹到 5
@export var danger_bonus: int = 1
## 六档稀有度各要按住几秒才开得了锁（越好的越久）；超出表长按最后一项
@export var hold_seconds: Array[float] = [1.5, 2.2, 3.0, 4.0, 5.5, 7.0]
## 松手没开开：进度按这个倍速往回退（再按下接着走）；0 = 一松手立刻归零
@export var release_decay: float = 2.0
## 六档各出几件 [min, max]
@export var items_by_rarity: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 4), Vector2i(3, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 6)]
## 六档的收获下限：每一件至少这个稀有度（作者定：宝箱稀有度 − 1，前两档 0）
@export var floor_by_rarity: Array[int] = [0, 0, 1, 2, 3, 4]
## 宝箱里能开出珍宝（搜索点不能）
@export var include_treasure: bool = true
## 收获先摆进这么大的容器
@export var haul_board: Vector2i = Vector2i(6, 4)


## 按住这一档要几秒
func hold_time(rarity: int) -> float:
	if hold_seconds.is_empty():
		return 1.0
	return maxf(0.05, hold_seconds[clampi(rarity, 0, hold_seconds.size() - 1)])


## 这一档出几件
func item_range(rarity: int) -> Vector2i:
	if items_by_rarity.is_empty():
		return Vector2i(1, 1)
	return items_by_rarity[clampi(rarity, 0, items_by_rarity.size() - 1)]


## 这一档的收获下限
func floor_of(rarity: int) -> int:
	if floor_by_rarity.is_empty():
		return 0
	return clampi(floor_by_rarity[clampi(rarity, 0, floor_by_rarity.size() - 1)], 0, 5)


## 在 [param tier] 档、危险 [param danger] 的点上掷一个宝箱稀有度（0～5）
func roll_rarity(tier: int, danger: int, rng: RandomNumberGenerator) -> int:
	var r := 0
	if not rarity_by_tier.is_empty():
		var row: Array = rarity_by_tier[clampi(tier, 0, rarity_by_tier.size() - 1)]
		var total := 0.0
		for w in row:
			total += maxf(0.0, float(w))
		if total > 0.0:
			var x := rng.randf() * total
			for i in row.size():
				x -= maxf(0.0, float(row[i]))
				if x <= 0.0:
					r = i
					break
	if danger >= 2:
		r += danger_bonus
	return clampi(r, 0, 5)
