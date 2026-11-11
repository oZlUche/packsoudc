## 主题奖励池（事件方案 2026-11-11 §8.4）：事件选项「从某一类里给一件」时抽的那张表。
##
## [b]永不抽空[/b]：有放回抽样 —— 抽一次不删候选、不减权重、不记库存；同一事件多抽、不同事件都可能抽到同一件。
## 「一个事件只结算一次」是事件实例的事（结果冻结在节点内容里，见 [EventRewards]），和池子能不能再抽无关。
##
## 权重 = 基础权重 × 深度倍率（深度 0 为 1，到深度 1 线性过渡到 [member RewardPoolEntry.deep_mult]）× [member RewardPoolEntry.hard_mult] ^ 难度档。
## 候选先按章节、最浅深度、道具库里有没有筛，再归一化抽。
## 作者数据，走内容管线：`data/authoring/reward_pools/*.json` → `data/reward_pools/*.tres`，事件的 [GivePoolItem] 按 id 引用。
class_name RewardPool
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var entries: Array[RewardPoolEntry] = []

static var _all: Dictionary = {}


## 资产目录里的全部奖励池：id → 池（第一次用时读盘、记住）
static func load_all() -> Dictionary:
	if _all.is_empty():
		for res in ContentPaths.load_resources(ContentPaths.REWARD_POOLS):
			if res is RewardPool and (res as RewardPool).id != &"":
				_all[(res as RewardPool).id] = res
	return _all


## 一行在这个上下文里的权重；不合格（章节不对、太浅、道具库里没有）是 0
func weight_of(e: RewardPoolEntry, items: ItemDatabase, chapter: StringName, depth: float, level: int) -> float:
	if e == null or e.weight <= 0.0:
		return 0.0
	if items != null and items.get_def(e.item) == null:
		return 0.0
	if not e.chapters.is_empty() and not e.chapters.has(chapter):
		return 0.0
	var d := clampf(depth, 0.0, 1.0)
	if d < e.min_depth:
		return 0.0
	return e.weight * lerpf(1.0, e.deep_mult, d) * pow(e.hard_mult, maxi(0, level))


## 归一化的理论概率：道具 id → 概率（同一道具写了几行的合起来）。没有合格候选返回空
func probabilities(items: ItemDatabase, chapter: StringName, depth: float, level: int) -> Dictionary:
	var out := {}
	var total := 0.0
	for e in entries:
		var w := weight_of(e, items, chapter, depth, level)
		if w > 0.0:
			out[e.item] = float(out.get(e.item, 0.0)) + w
			total += w
	if total <= 0.0:
		return {}
	for k in out:
		out[k] = float(out[k]) / total
	return out


## 有放回地抽 [param n] 件。没有合格候选返回空（调用方禁用那个选项，不先扣再给空）
func draw(items: ItemDatabase, chapter: StringName, depth: float, level: int, rng: RandomNumberGenerator, n: int = 1) -> Array[StringName]:
	var out: Array[StringName] = []
	var cands: Array[StringName] = []
	var weights: Array[float] = []
	for e in entries:
		var w := weight_of(e, items, chapter, depth, level)
		if w > 0.0:
			cands.append(e.item)
			weights.append(w)
	if cands.is_empty() or rng == null:
		return out
	for i in maxi(0, n):
		out.append(cands[MapRng.pick_index(weights, rng)])
	return out
