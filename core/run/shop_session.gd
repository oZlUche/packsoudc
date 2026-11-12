## 在一个商店点上做买卖（架构文档 6.6，M4-5；290 重做，作者 2026-11-07 15:11 定）。
##
## 商人一块大棋盘（[member board]，8 × 6），**开张一次摆满、不刷新**（[EconomyRules.shop_stock] 件，再按概率加一个包、一件金银，摆不下的丢掉）；
## 卖掉就空着，这一局这家店不再上货。棋盘整块和商人的钱袋存进 `node.content["shop"]`。
##
## **桌上的买卖**（以物易物）：拖过去就是放上桌 —— 商人的货拖进自己的棋盘 / 地上（[member taken]），自己的东西拖进商人的棋盘
## （[member given]）。东西真的挪过去，拖拽层挪、这里只认账：[method sync] 按「谁原来是谁的、现在在哪」算两份清单。
## 天秤：左盘 = 你拿的货的售价 + 放上桌的随身格 + 商人放上的钱；右盘 = 你给的东西的收购价 + 你放上的钱。
## **右 ≥ 左才能成交**（[method can_deal] / [method deal]）；点自己的钱袋补差（[method toggle_my_coins]），点商人的钱袋让他找钱（[method toggle_his_coins]）。
## 不成交就离开（[method leave]）：桌上的东西各回各家（[method cancel_table]）。
##
## 回购（277 第 4 条）自然成立：卖给他的东西摆在他棋盘上，这次进店内挂的价 = 你拿到的收购价（[member resale]）；离开再来按正常售价。
## 160 补一：「随身」两格（随身技能，不是道具）：点一格放上桌（[method toggle_belt]），成交才进腰带（[member belt_grant]）
class_name ShopSession
extends RefCounted

## 290：商人棋盘的尺寸（UI设计 15:38 按真实格尺寸核过）
const BOARD_SIZE := Vector2i(8, 6)
## 存档格式：v2 = 整块棋盘 + 钱袋（老档只记刷新次数与卖掉的格，读到就按种子重摆一次）
const SAVE_VERSION := 2

## 桌上的东西变了（[method sync] 之后、钱袋点过之后）
signal table_changed()
## 成交了：[param got] 你拿到的道具，[param gave] 你给出去的道具，[param paid] 你付的钱，[param change] 他找的钱
signal dealt(got: Array, gave: Array, paid: int, change: int)
## 160 补一：随身技能进了腰带
signal bought_belt(skill_id: StringName, price: int)
signal closed()

var node: MapNode = null
var rules: EconomyRules = null
var items: ItemDatabase = null
var wallet: Wallet = null
var depth: float = 0.0
## buff 给的售价倍数（[RunContext.shop_price_mult]），乘在规则的倍数之上
var price_mult: float = 1.0
## 209：章节的包池（开张时可能摆一个包）；null = 不卖包
var bag_pool: BagPool = null
## 160 补一：往腰带里放（`func(id, count) -> int`，[NodeEvents] 接 `belt_grant` hook）；没接 = 随身格上不了桌
var belt_grant: Callable = Callable()
## 自己这边的容器：[0] 棋盘，[1] 地上（[RunState] 开店时接上；测试直开的店自己给）。退回东西往这里放
var home_board: GridInventory = null
var home_ground: ItemStash = null

var active: bool = true
## 商人的棋盘
var board: GridInventory = GridInventory.new(BOARD_SIZE, 0, false)
## 商人钱袋里的钱
var purse: int = 0
## 160 补一：「随身」那两格，每格 {"id": 随身技能 id, "price": int}；卖掉的下标在 [member belt_sold]
var belt_offers: Array[Dictionary] = []
var belt_sold: Array[int] = []

## 商人的东西（成交过的才算）：uid → [origin, rotation, def]（他棋盘上的原位，退回时放回去）
var _owned: Dictionary = {}
## 桌上：你拿的货 uid → 价；你给的东西 uid → 价
var taken: Dictionary = {}
var given: Dictionary = {}
## 放上桌的随身格下标
var belt_on: Array[int] = []
## 两边放上天秤的钱
var my_coins: int = 0
var his_coins: int = 0
## 277 第 4 条：这次进店卖给他的 uid → 你拿到的价（原价买回）；离开就没了（不进存档）
var resale: Dictionary = {}


func _init(
	p_node: MapNode, p_rules: EconomyRules, p_items: ItemDatabase, p_wallet: Wallet, p_depth: float = 0.0, p_price_mult: float = 1.0,
	p_bag_pool: BagPool = null
) -> void:
	bag_pool = p_bag_pool
	node = p_node
	rules = p_rules
	items = p_items
	wallet = p_wallet
	depth = p_depth
	price_mult = maxf(0.0, p_price_mult)
	var saved: Dictionary = node.content.get("shop", {}) if node != null else {}
	if int(saved.get("v", 0)) >= SAVE_VERSION and saved.get("board", null) is Dictionary and items != null:
		board = GridInventory.from_dict(saved["board"], items, BOARD_SIZE)
		purse = int(saved.get("purse", 0))
		for i in saved.get("belt_sold", []):
			belt_sold.append(int(i))
		_roll_belt()
	else:
		purse = rules.purse_at(depth) if rules != null else 0
		_stock()
		_roll_belt()
	_commit_owned()
	_persist()


#region 价钱
func price_of(def: ItemDef) -> int:
	return price_for(def, rules, price_mult)


## 256：不开店也要估价（求饶的天平按局内出售价算道具）—— 和 [method price_of] / [method sell_price_of] 同一套
static func price_for(def: ItemDef, p_rules: EconomyRules, p_mult: float = 1.0) -> int:
	if def != null and def.is_bullion():     # 244：面值加手续费，任何倍率都不吃
		return maxi(1, roundi(float(ItemValue.of(def)) * (p_rules.bullion_premium if p_rules != null else 1.0)))
	return maxi(1, roundi(float(ItemValue.of(def)) * (p_rules.shop_price_mult if p_rules != null else 1.0) * p_mult))


## 卖给店里得多少：定价 × 出售比例。246 补充二：给了 [param inst] 且它碎了，定价按 [member WearProfile.broken_value_ratio] 打折
func sell_price_of(def: ItemDef, inst: ItemInstance = null) -> int:
	return sell_price_for(def, inst, rules, price_mult)


static func sell_price_for(def: ItemDef, inst: ItemInstance, p_rules: EconomyRules, p_mult: float = 1.0) -> int:
	if def == null:
		return 0
	var price := float(price_for(def, p_rules, p_mult))
	if inst != null and inst.is_broken():
		price = maxf(1.0, roundf(price * def.wear.broken_value_ratio))
	return maxi(0, floori(price * (p_rules.shop_sell_ratio if p_rules != null else 0.5)))


## 商人这件货挂多少（这次卖给他的按你拿到的价）
func tag_price(inst: ItemInstance) -> int:
	if inst == null:
		return 0
	return int(resale.get(inst.uid, price_of(inst.def)))


## 160 补一：随身技能的售价 = 它的标价 × 规则与 buff 的倍数
func belt_price_of(skill_id: StringName) -> int:
	var def := BeltSkillDef.find(skill_id)
	if def == null:
		return 0
	return maxi(1, roundi(float(def.price) * (rules.shop_price_mult if rules != null else 1.0) * price_mult))
#endregion


#region 谁的东西
## 这件是商人的（在他棋盘上没被你放上桌的，或你拿着还没成交的）
func is_merchants(uid: int) -> bool:
	return _owned.has(uid)


## 你自己的这件能不能放上桌：空串 = 能，否则是原因（锁着的、随身之物、独一的红武、券、装着东西的包）
func refuse_reason(inst: ItemInstance) -> String:
	if inst == null or inst.def == null:
		return UiText.t("shop.no_table")
	if inst.def.is_unique():     # 281：独一的红武不可出售
		return UiText.t("act.unique")
	if inst.def.is_ticket():     # 285：券也不
		return UiText.t("act.ticket")
	if inst.is_locked_by_player() or inst.is_pinned():
		return UiText.t("item.locked_no") % Names.of(inst.def)
	if home_board != null and home_board.has_item(inst.uid):
		if home_board.acts_as_bag(inst.def) and not home_board.contents_of(inst.uid).is_empty():
			return UiText.t("act.bag_full")     # 也盖住「装着随身之物的包」
		if home_board.keeps(inst.uid):
			return UiText.t("notice.rooted")     # 207：扎了根的（随身之物上面已经拦过）
	return ""
#endregion


#region 桌上
## 拖拽 / 双击 / 按钮挪完东西之后叫：按「谁的、在哪」重算桌上两份清单（价在这里定）
func sync() -> void:
	taken.clear()
	given.clear()
	for uid in _owned:
		if not board.has_item(uid):
			taken[uid] = int(resale.get(uid, price_of(_owned[uid][2])))
	for inst in board.items():
		var it := inst as ItemInstance
		if not _owned.has(it.uid):
			given[it.uid] = sell_price_of(it.def, it)
	if table_empty():
		my_coins = 0
		his_coins = 0
	table_changed.emit()


func table_empty() -> bool:
	return taken.is_empty() and given.is_empty() and belt_on.is_empty()


## 天秤左盘的货（你拿的货 + 随身格）
func goods_left() -> int:
	var n := 0
	for uid in taken:
		n += int(taken[uid])
	for i in belt_on:
		n += int(belt_offers[i]["price"])
	return n


## 天秤右盘的货（你给的东西）
func goods_right() -> int:
	var n := 0
	for uid in given:
		n += int(given[uid])
	return n


func left_total() -> int:
	return goods_left() + his_coins


func right_total() -> int:
	return goods_right() + my_coins


## 差额牌：{"kind": "short" 还差 / "even" 够了 / "change" 找你 / "cant_pay" 他只付得起, "n": 数}
func status() -> Dictionary:
	var d := left_total() - right_total()
	if d > 0:
		return {"kind": "short", "n": d}
	if d == 0:
		return {"kind": "even", "n": 0}
	var room := maxi(0, purse - his_coins)
	return {"kind": "change", "n": -d} if room >= -d else {"kind": "cant_pay", "n": room}


func can_deal() -> bool:
	return active and not table_empty() and right_total() >= left_total() and wallet != null and wallet.can_afford(my_coins)


## 点自己的钱袋：没放钱就把还差的那么多放上右盘（不够就放全部）；放过了再点 = 收回。返回现在放着多少
func toggle_my_coins() -> int:
	if my_coins > 0:
		my_coins = 0
	elif active and wallet != null and not table_empty():
		my_coins = clampi(left_total() - goods_right(), 0, wallet.balance)
	table_changed.emit()
	return my_coins


## 点商人的钱袋：右盘重时，他把多出来的放上左盘（不超过他袋里的钱）；放过了再点 = 收回
func toggle_his_coins() -> int:
	if his_coins > 0:
		his_coins = 0
	elif active and not table_empty():
		his_coins = clampi(right_total() - goods_left(), 0, purse)
	table_changed.emit()
	return his_coins


## 160 补一：随身第 i 格放上桌 / 收回。卖掉的、腰带接不上的放不上：返回原因（空串 = 动了）
func toggle_belt(i: int) -> String:
	if not active or i < 0 or i >= belt_offers.size() or belt_sold.has(i):
		return UiText.t("log.shop_no_slot")
	if belt_on.has(i):
		belt_on.erase(i)
	elif not belt_grant.is_valid():
		return UiText.t("log.no_belt")
	else:
		belt_on.append(i)
	if table_empty():
		my_coins = 0
		his_coins = 0
	table_changed.emit()
	return ""


## 成交：随身格先进腰带（满了那格退回、不算钱），钱换手，东西归新主人。成不了返回 false，一分不动
func deal() -> bool:
	sync()
	if not can_deal():
		return false
	for i in belt_on.duplicate():
		var sid := StringName(String(belt_offers[i]["id"]))
		if int(belt_grant.call(sid, 1)) > 0:
			belt_sold.append(i)
			bought_belt.emit(sid, int(belt_offers[i]["price"]))
		else:
			belt_on.erase(i)     # 腰带满了：那格退回，左盘轻了，右 ≥ 左照样成立
	var paid := mini(my_coins, maxi(0, left_total() - goods_right()))     # 退回的那格不收钱
	belt_on.clear()
	var change := mini(his_coins, purse)
	if paid > 0 and not wallet.spend(paid, &"shop"):
		return false
	purse += paid - change
	if change > 0:
		wallet.earn(change, &"shop_sell")
	var got: Array = []
	var gave: Array = []
	for uid in taken:
		var inst := _find_home(uid)
		if inst != null:
			got.append(inst)
		_owned.erase(uid)
		resale.erase(uid)
	for uid in given:
		var inst := board.get_item(uid)
		if inst != null:
			gave.append(inst)
			resale[uid] = int(given[uid])
	taken.clear()
	given.clear()
	my_coins = 0
	his_coins = 0
	_commit_owned()
	_persist()
	dealt.emit(got, gave, paid, change)
	table_changed.emit()
	return true


## 不成交：你给的东西先回自己的棋盘（放不下到地上），腾出原位；你拿的货再放回他棋盘原位（放不下就找空位）；钱收回、随身格撤下
func cancel_table() -> void:
	for v in board.items():
		var inst := v as ItemInstance
		if _owned.has(inst.uid):
			continue
		board.remove(inst.uid)
		if home_board == null or not home_board.try_add(inst, true):
			if home_ground != null:
				home_ground.admit(inst)
	for uid in _owned:
		if board.has_item(uid):
			continue
		var holder := _home_of(uid)
		var inst := holder.get_item(uid) if holder != null else null
		if inst == null:
			continue
		holder.remove(uid)
		var at: Array = _owned[uid]
		if not board.place(inst, at[0], int(at[1])):
			board.try_add(inst)
	belt_on.clear()
	my_coins = 0
	his_coins = 0
	sync()


func leave() -> void:
	if not active:
		return
	cancel_table()
	active = false
	resale.clear()
	closed.emit()
#endregion


#region 开张
## 一次摆满：候选按稀有度 × 深度权重不重复抽 [member EconomyRules.shop_stock] 件，再按概率加一个包、一件金银；大件先放，放不下的丢
func _stock() -> void:
	board = GridInventory.new(BOARD_SIZE, 0, false)
	if rules == null or items == null:
		return
	var seed_ := node.content_seed if node != null else 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:shop" % seed_)
	var picks: Array[ItemDef] = []
	var gold: ItemDef = null
	if node != null and node.content.has(FIXED_KEY):
		picks = fixed_stock(node.content, items)     # 313：节点写死的货架，不抽、不加包和金银
	else:
		var cands := candidates(rules, items)
		var weights: Array[float] = []
		for id in cands:
			weights.append(rules.shop_rarity_weight(items.get_def(id).rarity, depth))
		for _n in rules.shop_stock:
			if cands.is_empty():
				break
			var k := _weighted(rng, weights)
			picks.append(items.get_def(cands[k]))
			cands.remove_at(k)
			weights.remove_at(k)
		var bag := _roll_bag(seed_)
		if bag != null:
			picks.append(bag)
		gold = _roll_bullion(seed_)
		if gold != null:
			picks.append(gold)
	var order := range(picks.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca := picks[a].shape.cells_rotated(0).size() if picks[a].shape != null else 1
		var cb := picks[b].shape.cells_rotated(0).size() if picks[b].shape != null else 1
		return ca > cb or (ca == cb and a < b))
	var gold_uid := -1
	for k in order:
		var inst := ItemInstance.create(picks[k], 0)
		if board.try_add(inst) and picks[k] == gold:
			gold_uid = inst.uid
	if gold != null and gold_uid < 0:
		_make_room_for(gold)     # 金银那一格是规则给的（概率 1 就一定有）：摆满了让最小的一件普通货


## 313（试玩切片）：节点内容里写死的货架 —— 道具 id 的表，照写的顺序上架（同一个 id 写两次就两件）
const FIXED_KEY := "shop_stock"


## 节点内容里写死的货架换成道具；不认识的 id 跳过（清单核对工具会报出来）
static func fixed_stock(content: Dictionary, p_items: ItemDatabase) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for id in content.get(FIXED_KEY, []):
		var def := p_items.get_def(StringName(String(id)))
		if def != null:
			out.append(def)
	return out


## 摆不下 [param def] 时，从最小的普通货起逐件试着拿掉一件给它腾地方；腾不出来就照旧丢（不拿走任何货）
func _make_room_for(def: ItemDef) -> void:
	var goods: Array = board.items().filter(func(i: ItemInstance) -> bool: return not i.def.is_bag and not i.def.is_bullion())
	goods.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.def.cell_count() < b.def.cell_count() or (a.def.cell_count() == b.def.cell_count() and String(a.def.id) < String(b.def.id)))
	for g in goods:
		var inst := g as ItemInstance
		var at := inst.origin
		var rot := inst.rotation
		board.remove(inst.uid)
		if board.try_add(ItemInstance.create(def, 0)):
			return
		board.place(inst, at, rot)


## 按权重抽一个下标；总权重 ≤ 0 就等概率抽一个
static func _weighted(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var k := MapRng.pick_index(weights, rng)
	return k if k >= 0 else rng.randi_range(0, weights.size() - 1)


## 209：按 [member EconomyRules.shop_bag_slot_chance] 加一个包：包池权重 × 稀有度权重（随深度）。随机数另起一条
func _roll_bag(seed_: int) -> ItemDef:
	if bag_pool == null or rules == null or rules.shop_bag_slot_chance <= 0.0:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:shop_bag" % seed_)
	if rng.randf() >= rules.shop_bag_slot_chance:
		return null
	var cands := bag_pool.candidates(items)
	var weights: Array[float] = []
	for e in cands:
		weights.append(e.weight * rules.shop_rarity_weight(items.get_def(e.bag).rarity, depth))
	if cands.is_empty():
		return null
	return items.get_def(cands[_weighted(rng, weights)].bag)


## 244：按 [member EconomyRules.bullion_slot_chance] 加一件金银：补充一，按深度混合的权重表抽（外环银、内环金）
func _roll_bullion(seed_: int) -> ItemDef:
	if rules == null or rules.bullion_slot_chance <= 0.0:
		return null
	var table := rules.bullion_weights(depth)
	var ids: Array[StringName] = []
	var weights: Array[float] = []
	for id in table:
		if items.get_def(id) != null:
			ids.append(id)
			weights.append(float(table[id]))
	if ids.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:shop_bullion" % seed_)
	if rng.randf() >= rules.bullion_slot_chance:
		return null
	return items.get_def(ids[_weighted(rng, weights)])


## 160 补一：「随身」那一排：按权重不重复抽 1 ～ belt_picks 种（同一家店永远同一排，卖掉的记在 [member belt_sold]）
func _roll_belt() -> void:
	belt_offers = []
	if rules == null or rules.belt_stock.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:shop_belt:0" % (node.content_seed if node != null else 0))
	var ids: Array[StringName] = []
	for k in rules.belt_stock:
		if BeltSkillDef.find(StringName(String(k))) != null:
			ids.append(StringName(String(k)))
	Ids.sort(ids)
	var n := mini(ids.size(), rng.randi_range(1, maxi(1, rules.belt_picks)))
	for _i in n:
		var weights: Array[float] = []
		for sid in ids:
			weights.append(maxf(0.0, float(rules.belt_stock.get(String(sid), rules.belt_stock.get(sid, 0.0)))))
		var k := _weighted(rng, weights)
		belt_offers.append({"id": String(ids[k]), "price": belt_price_of(ids[k])})
		ids.remove_at(k)


## 能上架的道具：不是包、不是金银、不带排除标签。id 升序，抽出来的才可复现
static func candidates(p_rules: EconomyRules, p_items: ItemDatabase) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in p_items.ids():
		var d := p_items.get_def(id)
		if d == null or d.is_bag or d.is_bullion():     # 244：金银另抽（[method _roll_bullion]），不进权重池
			continue
		if not d.has_any_tag(p_rules.shop_exclude_tags):
			out.append(id)
	Ids.sort(out)
	return out
#endregion


## 成交之后（与开张时）：他棋盘上的东西都是他的，记下原位
func _commit_owned() -> void:
	_owned.clear()
	for v in board.items():
		var inst := v as ItemInstance
		_owned[inst.uid] = [inst.origin, inst.rotation, inst.def]


## 他的这件现在在哪（他棋盘、你的棋盘、地上）
func _home_of(uid: int) -> ItemContainer:
	if board.has_item(uid):
		return board
	if home_board != null and home_board.has_item(uid):
		return home_board
	if home_ground != null and home_ground.has_item(uid):
		return home_ground
	return null


func _find_home(uid: int) -> ItemInstance:
	var c := _home_of(uid)
	return c.get_item(uid) if c != null else null


## 存档只在桌上空着时写（开张、成交之后）：棋盘整块 + 钱袋 + 卖掉的随身格
func _persist() -> void:
	if node != null:
		node.content["shop"] = {"v": SAVE_VERSION, "board": board.to_dict(), "purse": purse, "belt_sold": belt_sold.duplicate()}
