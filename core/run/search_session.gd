## 在一个搜索点上搜（架构文档 6.2 / 5.4.2，M4-3）：搜几次是玩家手里的旋钮。
##
## 每搜一次：先按 [SearchRules] 找到几件（稀有度随深度与危险上偏），再按遭遇曲线掷一次 ——
## 中了就是遭遇，敌人由 [member encounter_builder] 现造（敌人池按 `search` 类型出人，5.10：搜到了才看得见），
## 搜索到此为止，打完这一场就走。没中可以继续搜，搜满 [member SearchRules.max_searches] 次或随时 [method leave]。
##
## 随机数只用节点的 `content_seed`：同一个点、同样的搜法，每次搜出来的一样。
## 搜过几次记进 `node.content["searches"]`，跟着图存。
class_name SearchSession
extends RefCounted

## 搜了一次：找到了什么、有没有遭遇（遭遇 = 敌人内容，没有 = 空字典）
signal searched(found: Array[StringName], encounter: Dictionary)
## 结束：&"left" 自己走的 / &"exhausted" 搜满了 / &"encounter" 遭遇了
signal ended(reason: StringName)

var node: MapNode = null
var rules: SearchRules = null
var items: ItemDatabase = null
var rng: RandomNumberGenerator = null
## 这个点的深度 0～1（[method EnemyPlacer.depths_of]）
var depth: float = 0.0
## 遭遇时造敌人内容：`Callable() -> Dictionary`。没设 = 这一章没有敌人池，遭遇掷中也只是空手而归
var encounter_builder: Callable = Callable()

var searches_done: int = 0
var found: Array[StringName] = []
var encounter: Dictionary = {}
var active: bool = true


func _init(p_node: MapNode, p_rules: SearchRules, p_items: ItemDatabase, p_rng: RandomNumberGenerator, p_depth: float = 0.0) -> void:
	node = p_node
	rules = p_rules
	items = p_items
	rng = p_rng
	depth = p_depth
	if node != null:
		searches_done = int(node.content.get("searches", 0))


func can_search() -> bool:
	return active and rules != null and searches_done < rules.max_searches


## 下一次搜的遭遇概率（给界面看）
func next_encounter_chance() -> float:
	return rules.encounter_chance(searches_done) if rules != null else 0.0


func searches_left() -> int:
	return maxi(0, rules.max_searches - searches_done) if rules != null else 0


## 搜一次。返回 {"found": [...], "encounter": {}}；不能搜时返回空字典
func search() -> Dictionary:
	if not can_search():
		return {}
	var k := searches_done
	var got := draw_items(rules, items, depth, node.danger if node != null else 0, rng)
	found.append_array(got)
	searches_done += 1
	if node != null:
		node.content["searches"] = searches_done
	var met := {}
	if rng.randf() < rules.encounter_chance(k) and encounter_builder.is_valid():
		var built = encounter_builder.call()
		if built is Dictionary and not (built as Dictionary).is_empty():
			met = built
	encounter = met
	searched.emit(got, met)
	if not met.is_empty():
		_end(&"encounter")
	elif searches_done >= rules.max_searches:
		_end(&"exhausted")
	return {"found": got, "encounter": met}


## 随时可以离开
func leave() -> void:
	if active:
		_end(&"left")


## 搜到的东西摆进容器（6.1 的做法）
func haul() -> GridInventory:
	return LootPacker.board_of(found, rules.haul_board if rules != null else Vector2i(6, 4), items)


func _end(reason: StringName) -> void:
	active = false
	ended.emit(reason)


## 找几件：候选是不带排除标签、（默认）不是包的道具，按稀有度权重抽；权重随深度与危险上偏
static func draw_items(
	p_rules: SearchRules, p_items: ItemDatabase, p_depth: float, danger: int, p_rng: RandomNumberGenerator,
	rarity_cap: int = -1
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
	return out


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
