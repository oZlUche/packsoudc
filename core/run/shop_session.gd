## 在一个商店点上买东西（架构文档 6.6，M4-5）：货架是随机稀有度的道具，可以花钱刷新。
##
## 货架由节点的 `content_seed` 与刷新次数决定：同一局同一家店，第 n 次刷新摆的永远是那几件 ——
## 所以存档只记刷新了几次、卖掉了哪几格（`node.content["shop"]`），货架本身不用存。
## 价格 = 道具价值（6.4）× 倍数。
##
## 087（作者定）：货架是**栏位**（[member shelves]，每格一块小棋盘，至少 3×4、商品更大就跟着大），商品是真的 [ItemInstance] 摆在里面，
## 玩家看得见尺寸、**拖到自己的包里就是买**（拖拽层挪、这里 [method pay_for] 收钱），双击也是买（[method buy] 自己找位）；
## 把包里的东西拖进 [member sell_box] 就是**卖**（[method sell]，回定价的一半，[EconomyRules.shop_sell_ratio]）。
## 钱不够 [method can_buy] 假、[method pay_for] 假 —— 屏据此把东西弹回栏位并提示
class_name ShopSession
extends RefCounted

## 栏位最小几格（作者定 3×4）
const SLOT_MIN := Vector2i(3, 4)

## 货架变了（刷新之后）
signal stock_changed()
## 买到了：inst 是那件实例。走 [method buy] 时它还不在任何容器里（持有方装到地上）；走 [method pay_for] 时它已经被拖进玩家的容器，inst 为 null
signal bought(def: ItemDef, price: int, inst: ItemInstance)
## 卖掉了一件
signal sold_item(def: ItemDef, gain: int)
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
## 087：每格一块小棋盘，商品实例摆在 (0,0)；卖掉的格子棋盘空着
var shelves: Array[GridInventory] = []
## 087：出售区 —— 把东西拖进来就卖
var sell_box: GridInventory = GridInventory.new(SLOT_MIN, 0, false)
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


## 卖给店里得多少：定价 × 出售比例（作者定一半）
func sell_price_of(def: ItemDef) -> int:
	if def == null:
		return 0
	return maxi(0, floori(float(price_of(def)) * (rules.shop_sell_ratio if rules != null else 0.5)))


## 这件实例摆在第几格；不是货架上的返回 -1
func slot_of(uid: int) -> int:
	for i in shelves.size():
		if shelves[i] != null and shelves[i].has_item(uid):
			return i
	return -1


## 第 i 格摆着的那件；没有 null
func item_at(i: int) -> ItemInstance:
	if i < 0 or i >= shelves.size() or shelves[i] == null:
		return null
	var list := shelves[i].items()
	return list[0] as ItemInstance if not list.is_empty() else null


## 087：把已经被拖走的第 i 格结账（拖拽层先挪、这里后收钱）。钱不够、卖掉了、店关了返回 false —— 调用方得把东西放回去
func pay_for(i: int) -> bool:
	if not can_buy(i):
		return false
	var def := items.get_def(StringName(String(stock[i]["id"])))
	if def == null or not wallet.spend(int(stock[i]["price"]), &"shop"):
		return false
	sold.append(i)
	_persist()
	bought.emit(def, int(stock[i]["price"]), null)
	return true


## 101 第 6 刀（原来在商店屏里）：**拖走了就结账，结不成就放回架上**。
## [param i] 是被拖走的那一格，[param uid] 是那件东西，[param from] 是现在可能拿着它的容器（棋盘、地上）。
## 钱不够 / 卖掉了 / 店关了都算结不成：这里把东西从玩家那边拿回来、原样放回第 i 格，返回 false。
## 界面只负责把 false 说成一句话 —— 回滚是一局的规则，不是画面的事
func pay_or_return(i: int, uid: int, from: Array) -> bool:
	if pay_for(i):
		return true
	if i < 0 or i >= shelves.size() or shelves[i] == null:
		return false
	for c in from:
		var container := c as ItemContainer
		if container == null or not container.has_item(uid):
			continue
		var inst := container.get_item(uid)
		container.remove(uid)
		if inst != null:
			shelves[i].place(inst, Vector2i.ZERO, 0)
		break
	return false


## 087：卖一件（它此刻在 [member sell_box] 里、或由调用方拿着）：拿走它、进账定价的一半。店关了返回 0
func sell(inst: ItemInstance) -> int:
	if not active or inst == null or inst.def == null or wallet == null:
		return 0
	if sell_box.has_item(inst.uid):
		sell_box.remove(inst.uid)
	var gain := sell_price_of(inst.def)
	if gain > 0:
		wallet.earn(gain, &"shop_sell")
	sold_item.emit(inst.def, gain)
	return gain


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


## 买第 i 格（双击 / 按钮）：收钱、把那件从栏位上拿下来交给持有方（[signal bought] 的 inst）。钱不够、卖掉了、店关了都返回 null，一分不动
func buy(i: int) -> ItemDef:
	if not can_buy(i):
		return null
	var def := items.get_def(StringName(String(stock[i]["id"])))
	if def == null or not wallet.spend(int(stock[i]["price"]), &"shop"):
		return null
	sold.append(i)
	var inst := item_at(i)
	if inst != null:
		shelves[i].remove(inst.uid)
	else:
		inst = ItemInstance.create(def, 0)
	_persist()
	bought.emit(def, int(stock[i]["price"]), inst)
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
	shelves = []
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
	_build_shelves()


## 087：每格一块小棋盘（至少 3×4，商品更大就跟着大），没卖的把商品摆在 (0,0)
func _build_shelves() -> void:
	shelves = []
	for i in stock.size():
		var def := items.get_def(StringName(String(stock[i]["id"])))
		var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
		var grid := GridInventory.new(Vector2i(maxi(SLOT_MIN.x, size.x), maxi(SLOT_MIN.y, size.y)), 0, false)
		if def != null and not sold.has(i):
			grid.place(ItemInstance.create(def, 0), Vector2i.ZERO, 0)
		shelves.append(grid)


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
