## 一切地图生成器的根（架构文档 5.3）。
##
## 子类只实现 [method build]「造一张图」；**校验与重试由本类包办**，
## 每种形态不必各写一遍「失败了换个种子再来」。
##
## [b]生成失败的统一策略是换种子重来[/b]，而不是写一个保证成功的算法。
## 后者的实现与维护成本高得多，还更容易出现难以察觉的分布偏差 ——
## 「总能生成出合法图」的算法，往往是靠悄悄偏袒某几种形状做到的。
##
## 重试用尽则[b]报错返回 null，绝不降级产出一张坏图[/b]：
## 一张连通性有问题的地图，表现是玩家走到一半发现无路可走，
## 而那时已经离生成现场很远了。
@abstract
class_name MapGenerator
extends RefCounted

## 换种子重试的上限。用尽即失败。
const MAX_ATTEMPTS := 32

## 上一次 [method generate] 实际用了几次尝试。1 = 一次就成。
## 批量调参时看它的分布：次数一高，说明配置与校验在打架，
## 与其调高上限不如改配置。
var attempts_used: int = 0

## 上一次 [method generate] 里各条规则失败了多少次（规则 → 次数）。
## 成功时是上一次失败尝试的累计，全程没失败过则为空。
var failure_tally: Dictionary = {}

## [method build] 返回 null 时，子类可以在这里留一句为什么 ——
## 「出生点放不下」这类配置错误，光说「没能造出图」等于没说。每次尝试前清空。
var build_note: String = ""


## 造一张图。由子类实现。
##
## **子类有义务为每个节点写入 `tier` 与 `erosion_band`**（5.2）—— 前者是难度奖励档位，
## 后者是侵蚀分档，第一章里数值相等但不是一回事。
##
## 造不出来就返回 null，当作一次失败的尝试，由 [method generate] 换种子重来。
@abstract func build(cfg: Resource, rng: RandomNumberGenerator) -> MapGraph


## 一份开箱能跑的默认配置。编辑器靠它给每种生成器摆出参数表单 ——
## 它不认识任何具体的配置类，只管把这个对象的导出属性反射出来。
## 不需要配置的生成器返回 null。
func default_config() -> Resource:
	return null


## 生成一张通过校验的图；[param base_seed] 相同则结果相同。
##
## 失败就换种子重来，至多 [param attempts] 次。全都不成则 `push_error` 并返回 null。
func generate(cfg: Resource, base_seed: int, attempts: int = MAX_ATTEMPTS) -> MapGraph:
	attempts_used = 0
	failure_tally = {}
	var rng := RandomNumberGenerator.new()
	var last := MapValidation.new()

	for i in maxi(1, attempts):
		attempts_used = i + 1
		rng.seed = derive_seed(base_seed, i)
		build_note = ""
		var graph := build(cfg, rng)

		last = MapValidation.new()
		if graph == null:
			last.fail(&"build", build_note if build_note != "" else "生成器没能造出图")
		else:
			validate(graph, last)
		if last.ok():
			return graph

		var tally := last.tally()
		for rule in tally:
			failure_tally[rule] = int(failure_tally.get(rule, 0)) + int(tally[rule])

	push_error(
		"MapGenerator: 种子 %d 连试 %d 次都没生成出合法地图，返回 null。\n%s\n最后一次：\n%s"
		% [base_seed, attempts_used, _tally_text(), last.to_text()]
	)
	return null


## 通用校验：与地图形态无关的那几条。
##
## 子类重写时[b]必须先调 super[/b] —— 环形图的配额、覆盖、路线那些是它自己的规矩，
## 但「图得连得上、入口得有、终点得到得了」是所有形态共通的。
func validate(graph: MapGraph, v: MapValidation) -> void:
	validate_common(graph, v)


## 通用校验的本体。静态的，因为**不是只有生成器要用它**：
## 载入一张预设地图、编辑器里手改一张图，都得问同样这几条，而那时手上没有生成器。
static func validate_common(graph: MapGraph, v: MapValidation) -> void:
	if graph == null:
		v.fail(&"build", "图是 null")
		return

	var ids := graph.node_ids()
	if ids.is_empty():
		v.fail(&"nodes", "一个节点都没有")
		return

	# --- 边的两端都得在 ---
	# add_edge 已经挡了一道，但 edges 是公开的，生成器直接 append 也拦不住。
	# 悬空的边会让后面每一个遍历都得判空，不如在这里一次问清楚。
	for e in graph.edges:
		if not graph.has_node(e.from_id) or not graph.has_node(e.to_id):
			v.fail(&"edge_ends", "有一条边的端点不存在：%d → %d" % [e.from_id, e.to_id])

	# --- 每个节点都得有类型 ---
	for id in ids:
		if graph.get_node(id).type == &"":
			v.fail(&"typed", "节点 %d 没有类型" % id)

	# --- 出生点与终点 ---
	if graph.entry_ids.is_empty():
		v.fail(&"entries", "没有出生点")
	for id in graph.entry_ids:
		if not graph.has_node(id):
			v.fail(&"entries", "出生点 %d 不是图上的节点" % id)
	if graph.goal_ids.is_empty():
		v.fail(&"goals", "没有终点")
	for id in graph.goal_ids:
		if not graph.has_node(id):
			v.fail(&"goals", "终点 %d 不是图上的节点" % id)

	# --- 孤立节点 ---
	# 只连一条边的死胡同是合法的（可以走回头路，死路不是问题），
	# 但一条边都不挨着的节点谁也到不了，那是生成器漏了一步
	for id in ids:
		if graph.edges_of(id).is_empty():
			v.fail(&"isolated", "节点 %d 一条边都不挨着" % id)

	# --- 全图连通：唯一的连通性要求 ---
	# 玩家可以走回头路，所以死路无妨；但每个点都得从某个出生点走得到。
	if graph.entry_ids.is_empty():
		return
	var seen := reachable_from(graph, graph.entry_ids)
	var missed: Array[int] = []
	for id in ids:
		if not seen.has(id):
			missed.append(id)
	if not missed.is_empty():
		v.fail(&"reachable", "%d 个节点从任何出生点都走不到，例如 %s"
			% [missed.size(), str(missed.slice(0, mini(5, missed.size())))])
	for id in graph.goal_ids:
		if graph.has_node(id) and not seen.has(id):
			v.fail(&"goal_reachable", "终点 %d 从任何出生点都走不到" % id)


## 从这几个点出发走得到的全部点（含出发点自己）。单向边只顺着走。
static func reachable_from(graph: MapGraph, from_ids: Array[int]) -> Dictionary:
	var seen := {}
	var queue: Array[int] = []
	for id in from_ids:
		if graph.has_node(id) and not seen.has(id):
			seen[id] = true
			queue.append(id)
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for n in graph.neighbors(id):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## 第 [param attempt] 次尝试用的种子。
##
## 每次尝试的种子各自独立算得出来，所以「种子 12345 的第 7 次尝试」可以单独复现，
## 不必把前六次重放一遍 —— 调生成器时这一点很省事。
##
## 用 `hash(字符串)` 而不是自己写位运算：GDScript 的 `>>` 对负数是算术移位，
## splitmix 那类混合函数照搬过来会在负种子上悄悄失真。
static func derive_seed(base: int, attempt: int) -> int:
	return hash("%d:%d" % [base, attempt])


func _tally_text() -> String:
	if failure_tally.is_empty():
		return "（没有记录到失败原因）"
	var keys: Array = failure_tally.keys()
	keys.sort_custom(func(a, b): return failure_tally[a] > failure_tally[b])
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s × %d" % [k, failure_tally[k]])
	return "各条规则失败次数：" + "，".join(parts)
