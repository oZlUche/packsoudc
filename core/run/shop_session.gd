## 在一个商店点上买东西（架构文档 6.6，M4-5）：货架是随机稀有度的道具，可以花钱刷新。
##
## 货架由节点的 `content_seed` 与刷新次数决定：同一局同一家店，第 n 次刷新摆的永远是那几件 ——
## 所以存档只记刷新了几次、卖掉了哪几格（`node.content["shop"]`），货架本身不用存。
## 价格 = 道具价值（6.4）× 倍数。买到的东西交给谁装（玩家棋盘、暂存区）是 M5 的事，这里只发 [signal bought]。
class_name ShopSession
extends RefCounted

## 货架变了（刷新之后）
signal stock_changed()
signal bought(def: ItemDef, price: int)
signal closed()

var node: MapNode = null
var rules: EconomyRules = null
var items: ItemDatabase = null
var wallet: Wallet = null
var depth: float = 0.0

var refreshes: int = 0
## buff 给的售价倍数（[RunContext.shop_price_mult]），乘在规则的倍数之上
var price_mult: float = 1.0
## 卖掉的格子下标
var sold: Array[int] = []
## 货架：每格 {"id": StringName, "price": int}
var stock: Array[Dictionary] = []
var active: bool = true


func _init(
	p_node: MapNode, p_rules: EconomyRules, p_items: ItemDatabase, p_wallet: Wallet, p_depth: float = 0.0, p_price_mult: float = 1.0
) -> void:
	node = p_node
	rules = p_rules
	items = p_items
	wallet = p_wallet
	depth = p_depth
	price_mult = maxf(0.0, p_price_mult)
	if node != null:
		var saved: Dictionary = node.content.get("shop", {})
		refreshes = int(saved.get("refreshes", 0))
		for i in saved.get("sold", []):
			sold.append(int(i))
	_restock()


func refresh_cost() -> int:
	return rules.refresh_cost_at(refreshes) if rules != null else 0


func price_of(def: ItemDef) -> int:
	return maxi(1, roundi(float(ItemValue.of(def)) * (rules.shop_price_mult if rules != null else 1.0) * price_mult))


## 还在架上的格子
func available() -> Array[int]:
	var out: Array[int] = []
	for i in stock.size():
		if not sold.has(i):
			out.append(i)
	return out


func can_buy(i: int) -> bool:
	return active and i >= 0 and i < stock.size() and not sold.has(i) and wallet != null \
		and wallet.can_afford(int(stock[i]["price"]))


## 买第 i 格。钱不够、卖掉了、店关了都返回 null，一分不动
func buy(i: int) -> ItemDef:
	if not can_buy(i):
		return null
	var def := items.get_def(StringName(String(stock[i]["id"])))
	if def == null or not wallet.spend(int(stock[i]["price"]), &"shop"):
		return null
	sold.append(i)
	_persist()
	bought.emit(def, int(stock[i]["price"]))
	return def


func can_refresh() -> bool:
	return active and wallet != null and wallet.can_afford(refresh_cost())


## 花钱换一批。钱不够返回 false
func refresh() -> bool:
	if not can_refresh() or not wallet.spend(refresh_cost(), &"shop_refresh"):
		return false
	refreshes += 1
	sold = []
	_restock()
	_persist()
	stock_changed.emit()
	return true


func leave() -> void:
	if not active:
		return
	active = false
	closed.emit()


## 第 refreshes 次的货架：候选按稀有度权重抽，不重复（候选够多的话）
func _restock() -> void:
	stock = []
	if rules == null or items == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:shop:%d" % [node.content_seed if node != null else 0, refreshes])
	var cands := candidates(rules, items)
	var weights: Array[float] = []
	for id in cands:
		weights.append(rules.shop_rarity_weight(items.get_def(id).rarity, depth))
	for slot in rules.shop_slots:
		if cands.is_empty():
			break
		var total := 0.0
		for w in weights:
			total += w
		var k := cands.size() - 1
		if total > 0.0:
			var x := rng.randf() * total
			for j in cands.size():
				x -= weights[j]
				if x <= 0.0:
					k = j
					break
		else:
			k = rng.randi_range(0, cands.size() - 1)
		var def := items.get_def(cands[k])
		stock.append({"id": String(cands[k]), "price": price_of(def)})
		cands.remove_at(k)
		weights.remove_at(k)


func _persist() -> void:
	if node != null:
		node.content["shop"] = {"refreshes": refreshes, "sold": sold.duplicate()}


## 能上架的道具：不是包、不带排除标签。id 升序，抽出来的才可复现
static func candidates(p_rules: EconomyRules, p_items: ItemDatabase) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in p_items.ids():
		var d := p_items.get_def(id)
		if d == null or d.is_bag:
			continue
		var excluded := false
		for tag in d.tags:
			if p_rules.shop_exclude_tags.has(tag):
				excluded = true
				break
		if not excluded:
			out.append(id)
	out.sort()
	return out
