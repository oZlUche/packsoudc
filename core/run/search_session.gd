## 在一个搜索点上搜（架构文档 6.2 / 5.4.2，M4-3）：搜几次是玩家手里的旋钮。
##
## 每搜一次：先按遭遇曲线掷一次 —— 中了就是遭遇（084：这一次**什么都翻不到**，直接开打），敌人由 [member encounter_builder] 现造
## （敌人池按 `search` 类型出人，5.10：搜到了才看得见），搜索到此为止；没中再按 [SearchRules] 找到几件（稀有度随深度与危险上偏）。没中可以继续搜，搜满 [member SearchRules.max_searches] 次就不能再搜，
## 但会话**不自动结束**（084：最后一次的收获要留给玩家亮出来、拖走），随时 [method leave] 才结束。
##
## 随机数只用节点的 `content_seed`：同一个点、同样的搜法，每次搜出来的一样。
## 搜过几次记进 `node.content["searches"]`，跟着图存。
class_name SearchSession
extends RefCounted

## 搜了一次：找到了什么、有没有遭遇（遭遇 = 敌人内容，没有 = 空字典）
signal searched(found: Array[StringName], encounter: Dictionary)
## 结束：&"left" 自己走的 / &"exhausted" 搜满了才走的 / &"encounter" 遭遇了
signal ended(reason: StringName)
## 收获容器换了一个（原来的放不下，换了高一格的；东西原位搬过去、uid 不变）。界面重新绑
signal haul_changed(box: GridInventory)

var node: MapNode = null
var rules: SearchRules = null
var items: ItemDatabase = null
var rng: RandomNumberGenerator = null
## 这个点的深度 0～1（[method EnemyPlacer.depths_of]）
var depth: float = 0.0
## 遭遇时造敌人内容：`Callable() -> Dictionary`。没设 = 这一章没有敌人池，遭遇掷中也只是空手而归
var encounter_builder: Callable = Callable()

var searches_done: int = 0
## 这个会话里找到过的全部（拿走了也还在这里记着）
var found: Array[StringName] = []
## 收获容器（6.1 的做法）：每搜一次找到的摆进来，亮出来的可以直接从这里拿走；会话结束时剩下的就是 [method haul]
var haul_box: GridInventory = null
var encounter: Dictionary = {}
var active: bool = true
## 095：翻到的东西按概率换成赐福版 `func(ids) -> ids`（NodeEvents 接）
var substitute: Callable = Callable()
## 127：每次搜的逐件稀有度下限（[method floor_for]，开会话时由 NodeEvents 设）；空 = 不保底
var search_floor: Array[int] = []


func _init(p_node: MapNode, p_rules: SearchRules, p_items: ItemDatabase, p_rng: RandomNumberGenerator, p_depth: float = 0.0) -> void:
	node = p_node
	rules = p_rules
	items = p_items
	rng = p_rng
	depth = p_depth
	if node != null:
		searches_done = int(node.content.get("searches", 0))
	haul_box = GridInventory.new(_haul_size(), 0, false)


## buff 给的额外次数（[RunContext.extra_searches]），开会话时由 NodeEvents 设
var extra_searches: int = 0


## 一共能搜几次：规则的上限 + buff 给的；节点内容里的 `search_max` 覆盖规则（083 序章的教程点）
func max_total() -> int:
	var base := rules.max_searches if rules != null else 0
	if node != null and node.content.has("search_max"):
		base = int(node.content["search_max"])
	return base + maxi(0, extra_searches)


## 至少得搜几次才能走（节点内容 `search_min`，083）；0 = 随时可以走
func min_searches() -> int:
	return int(node.content.get("search_min", 0)) if node != null else 0


func can_leave() -> bool:
	return searches_done >= min_searches()


## 第 k 次搜的遭遇概率：节点内容 `search_curve` 覆盖规则的曲线（超出的按最后一项）
func encounter_chance_at(k: int) -> float:
	if node != null and node.content.has("search_curve"):
		var curve: Array = node.content["search_curve"]
		if curve.is_empty():
			return 0.0
		return clampf(float(curve[mini(k, curve.size() - 1)]), 0.0, 1.0)
	return rules.encounter_chance(k) if rules != null else 0.0


func can_search() -> bool:
	return active and rules != null and searches_done < max_total()


## 下一次搜的遭遇概率（给界面看）
func next_encounter_chance() -> float:
	return encounter_chance_at(searches_done)


func searches_left() -> int:
	return maxi(0, max_total() - searches_done) if rules != null else 0


## 搜一次。返回 {"found": [...], "encounter": {}}；不能搜时返回空字典
func search() -> Dictionary:
	if not can_search():
		return {}
	var k := searches_done
	var met := {}
	if rng.randf() < encounter_chance_at(k) and encounter_builder.is_valid():
		var built = encounter_builder.call()
		if built is Dictionary and not (built as Dictionary).is_empty():
			met = built
	var got: Array[StringName] = []
	if met.is_empty():
		got = _scripted_finds(k)
		if got.is_empty():
			got = draw_items(rules, items, depth, node.danger if node != null else 0, rng, -1, search_floor)
			if substitute.is_valid():
				got = substitute.call(got)
		found.append_array(got)
		var packed := LootPacker.add(haul_box, got, items, _haul_size().y)
		if packed["board"] != haul_box:
			haul_box = packed["board"]
			haul_changed.emit(haul_box)
	searches_done += 1
	if node != null:
		node.content["searches"] = searches_done
	encounter = met
	searched.emit(got, met)
	if not met.is_empty():
		_end(&"encounter")
	# 搜满了不在这里结束：屏还要把最后一次的收获亮出来给玩家拖，玩家按「离开」才算走（084）
	return {"found": got, "encounter": met}


## 搜满了没有（满了就不能再搜，但还没走）
func is_exhausted() -> bool:
	return rules != null and searches_done >= max_total()


## 随时可以离开（教程点要求搜够 `search_min` 次才能走：界面按 [method can_leave] 灰掉按钮，这里不拦）。
## 搜满了才走的记作 &"exhausted"，没搜满就走的记作 &"left"
func leave() -> void:
	if active:
		_end(&"exhausted" if is_exhausted() else &"left")


## 节点内容 `search_finds`（083）：第 k 次搜固定找到什么（id 列表的列表）；没写、或超出的返回空 = 照规则抽
func _scripted_finds(k: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if node == null or items == null or not node.content.has("search_finds"):
		return out
	var finds: Array = node.content["search_finds"]
	if k >= finds.size() or not (finds[k] is Array):
		return out
	for raw in finds[k]:
		var id := StringName(String(raw))
		if items.get_def(id) != null:
			out.append(id)
	return out


## 往收获箱里放一件已有的实例（uid 不变）：放不下就一格一格加高，最多到收获箱规定高度的两倍；再放不下 false
func stow(inst: ItemInstance) -> bool:
	if inst == null:
		return false
	while not haul_box.try_add(inst, true):
		if haul_box.size.y >= _haul_size().y * 2:
			return false
		var bigger := GridInventory.new(haul_box.size + Vector2i(0, 1), haul_box.id, false)
		bigger.begin_batch()
		for it in haul_box.items():
			var item := it as ItemInstance
			bigger.place(item, item.origin, item.rotation)
		bigger.end_batch()
		haul_box = bigger
		haul_changed.emit(haul_box)
	return true


## 收获：会话里搜到、还没拿走的都在这个容器里
func haul() -> GridInventory:
	return haul_box


func _haul_size() -> Vector2i:
	return rules.haul_board if rules != null else Vector2i(6, 4)


func _end(reason: StringName) -> void:
	active = false
	ended.emit(reason)


## 091（作者定）：遭遇打赢了接着搜 —— 会话重新开着、遭遇清掉；搜过的次数照旧累计（遭遇概率按曲线接着走）
func resume() -> void:
	active = true
	encounter = {}


## 127：是不是进阶搜索点 —— 节点内容 `search_tier`（"advanced" / "normal"）优先，否则高危区里的（danger ≥ 1）
static func is_advanced(node: MapNode) -> bool:
	if node == null:
		return false
	if node.content.has("search_tier"):
		return String(node.content["search_tier"]) == "advanced"
	return node.danger >= 1


## 127：这个点每次搜的逐件稀有度下限。优先级：节点内容 `search_floor` > 难度覆盖 > 阶梯表（常规用第 level 行、进阶用第 level + 1 行）
static func floor_for(node: MapNode, p_rules: SearchRules, difficulty: DifficultyDef) -> Array[int]:
	var out: Array[int] = []
	if node != null and node.content.has("search_floor"):
		for v in node.content["search_floor"]:
			out.append(int(v))
		return out
	var adv := is_advanced(node)
	var key := "advanced" if adv else "normal"
	if difficulty != null and difficulty.search_floors.has(key):
		for v in difficulty.search_floors[key]:
			out.append(int(v))
		return out
	if p_rules == null:
		return out
	return p_rules.floor_row((difficulty.level if difficulty != null else 0) + (1 if adv else 0))


## 127：给人看的保底说明：「一件绿及以上、两件任意」。空表返回 ""
const FLOOR_COLORS := ["白", "绿", "蓝", "紫", "金", "红"]
const COUNT_WORDS := ["零", "一", "两", "三", "四", "五", "六", "七", "八", "九"]


static func floor_text(p_floor: Array[int]) -> String:
	if p_floor.is_empty():
		return ""
	var counts := {}
	for v in p_floor:
		counts[v] = int(counts.get(v, 0)) + 1
	var keys := counts.keys()
	keys.sort()
	keys.reverse()
	var parts: Array[String] = []
	for k in keys:
		var n: int = counts[k]
		var word: String = COUNT_WORDS[n] if n < COUNT_WORDS.size() else str(n)
		parts.append("%s件%s" % [word, "任意" if int(k) <= 0 else FLOOR_COLORS[clampi(int(k), 0, 5)] + "及以上"])
	return "、".join(parts)


## 找几件：候选是不带排除标签、（默认）不是包的道具，按稀有度权重抽；权重随深度与危险上偏。
## 127：[param p_floor] 是逐件稀有度下限 —— 件数至少是它的长度，第 i 个保底位只在稀有度 ≥ p_floor[i] 的候选里抽
## （那一档以上没有就逐级往下放宽；先夹到 rarity_cap），其余照旧全池抽；有保底时打乱顺序再返回
static func draw_items(
	p_rules: SearchRules, p_items: ItemDatabase, p_depth: float, danger: int, p_rng: RandomNumberGenerator,
	rarity_cap: int = -1, p_floor: Array[int] = []
) -> Array[StringName]:
	var out: Array[StringName] = []
	if p_rules == null or p_items == null:
		return out
	var cands := candidates(p_rules, p_items, rarity_cap)
	if cands.is_empty():
		return out
	var weights: Array[float] = []
	var total := 0.0
	for id in cands:
		var w := p_rules.rarity_weight(p_items.get_def(id).rarity, p_depth, danger)
		weights.append(w)
		total += w
	var n := p_rng.randi_range(p_rules.items_per_search.x, p_rules.items_per_search.y)
	if not p_floor.is_empty():
		n = maxi(n, p_floor.size())
		for f in p_floor:
			out.append(_draw_at_least(cands, weights, p_items, f if rarity_cap < 0 else mini(f, rarity_cap), p_rng))
		n -= p_floor.size()
	for i in maxi(0, n):
		if total <= 0.0:
			out.append(cands[p_rng.randi_range(0, cands.size() - 1)])
			continue
		var x := p_rng.randf() * total
		var picked := cands[cands.size() - 1]
		for j in cands.size():
			x -= weights[j]
			if x <= 0.0:
				picked = cands[j]
				break
		out.append(picked)
	if not p_floor.is_empty():
		_shuffle(out, p_rng)     # 别让玩家从揭示顺序猜哪件是保底
	return out


## 127：在稀有度 ≥ [param at_least] 的候选里按原权重抽一件；那一档以上一件都没有就逐级往下放宽
static func _draw_at_least(cands: Array[StringName], weights: Array[float], p_items: ItemDatabase, at_least: int, p_rng: RandomNumberGenerator) -> StringName:
	for floor_r in range(maxi(0, at_least), -1, -1):
		var idx: Array[int] = []
		var total := 0.0
		for j in cands.size():
			if p_items.get_def(cands[j]).rarity >= floor_r:
				idx.append(j)
				total += weights[j]
		if idx.is_empty():
			continue
		if total <= 0.0:
			return cands[idx[p_rng.randi_range(0, idx.size() - 1)]]
		var x := p_rng.randf() * total
		for j in idx:
			x -= weights[j]
			if x <= 0.0:
				return cands[j]
		return cands[idx[idx.size() - 1]]
	return cands[p_rng.randi_range(0, cands.size() - 1)]


## 用给定的随机数洗牌（Array.shuffle 用的是全局随机数，不可复现）
static func _shuffle(arr: Array[StringName], p_rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := p_rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## 能搜出来的道具，id 升序
static func candidates(p_rules: SearchRules, p_items: ItemDatabase, rarity_cap: int = -1) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in p_items.ids():
		var d := p_items.get_def(id)
		if d == null or (d.is_bag and not p_rules.include_bags):
			continue
		if rarity_cap >= 0 and d.rarity > rarity_cap:
			continue
		var excluded := false
		for tag in d.tags:
			if p_rules.exclude_tags.has(tag):
				excluded = true
				break
		if not excluded:
			out.append(id)
	out.sort()
	return out
