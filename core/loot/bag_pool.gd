## 包池（209，作者 21:30 夜间六条之三）：敌人开战背什么包、死了掉什么包装东西、商店的包槽卖什么包 —— 同一张表。
##
## 掉落分两段：[DropResolver] 先照旧掷「掉哪些东西」，再按这里掷「用哪些包装它们」（[method DropResolver.roll_bags]）：
## 要装的格数 = 掉的东西的格数 / [member fill_target]；第一个包必抽，之后每个按 [member extra_bag_chance] 决定还抽不抽，
## 容量够了或到 [member max_bags] 就停；敌人自己背着的包权重 × [member own_bag_weight_mult]（看见它背什么，多半就掉什么）。
## 作者数据，走内容管线：`data/authoring/bag_pools/*.json` → `data/bag_pools/*.tres`，章节按 id 引用（[member ChapterDef.bag_pool]）。
class_name BagPool
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var entries: Array[BagPoolEntry] = []
## 掉的东西装满包的几成就够（0.8 = 包的格数至少是东西的 1.25 倍）
@export var fill_target: float = 0.8
## 一具尸体最多掉几个包
@export var max_bags: int = 3
## 第一个包之后，每多一个包的概率
@export var extra_bag_chance: float = 0.5
## 敌人自己背着的包在掉落时的权重倍率
@export var own_bag_weight_mult: float = 2.0

const DEFAULT_ID := &"standard"

static var _standard: BagPool = null


## 默认包池（没有章节可问的地方用：测试、编辑器里直接组装的敌人）
static func standard() -> BagPool:
	if _standard == null:
		_standard = ContentPaths.load_asset("bag_pools", String(DEFAULT_ID)) as BagPool
	return _standard


## 候选：稀有度 ≤ [param rarity_cap]（-1 不限）、道具库里有、是包、权重 > 0。按池里的顺序
func candidates(items: ItemDatabase, rarity_cap: int = -1) -> Array[BagPoolEntry]:
	var out: Array[BagPoolEntry] = []
	for e in entries:
		if e == null or e.weight <= 0.0 or items == null:
			continue
		var d := items.get_def(e.bag)
		if d == null or not d.is_bag or (rarity_cap >= 0 and d.rarity > rarity_cap):
			continue
		out.append(e)
	return out


## 按权重抽一个包 id；[param boost] 里的 id 权重再乘 [param mult]。没有候选返回空
static func pick(cands: Array[BagPoolEntry], rng: RandomNumberGenerator, boost: Array = [], mult: float = 1.0) -> StringName:
	if cands.is_empty():
		return &""
	var weights: Array[float] = []
	var total := 0.0
	for e in cands:
		var w := e.weight * (mult if boost.has(e.bag) else 1.0)
		weights.append(w)
		total += w
	var x := rng.randf() * total
	for i in cands.size():
		x -= weights[i]
		if x <= 0.0:
			return cands[i].bag
	return cands[cands.size() - 1].bag
