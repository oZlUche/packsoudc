## 290（作者 2026-11-07 15:11）：局内商店重做 —— 商人一块大棋盘一次摆满、不刷新；天秤称价、以物易物；两只钱袋；回购只在这次进店
extends RefCounted


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 货量 6：棋盘留出空地好卖东西（10 件的满棋盘在 [method run_stock] 单测）
static func _rules(p_stock: int = 6) -> EconomyRules:
	var r := EconomyRules.new()
	r.id = &"t_shop290"
	r.shop_stock = p_stock
	r.shop_purse_base = 100
	r.shop_purse_depth = 200
	r.shop_sell_ratio = 0.3
	r.shop_bag_slot_chance = 0.0
	r.bullion_slot_chance = 0.0
	return r


static func _node(p_seed: int = 5) -> MapNode:
	var n := MapNode.new()
	n.id = 1
	n.type = &"shop"
	n.content_seed = p_seed
	return n


## 一家店 + 自己的棋盘和地上
static func _shop(items: ItemDatabase, wallet: Wallet, node: MapNode = null, r: EconomyRules = null) -> ShopSession:
	var s := ShopSession.new(node if node != null else _node(), r if r != null else _rules(), items, wallet, 0.3)
	s.home_board = GridInventory.new(Vector2i(10, 10), 1, false)
	s.home_ground = ItemStash.new(4, 0)
	return s


## 拖拽层做的事：商人的货挪进自己的棋盘
static func _take(s: ShopSession, inst: ItemInstance) -> bool:
	s.board.remove(inst.uid)
	var ok := s.home_board.try_add(inst, true)
	s.sync()
	return ok


## 拖拽层做的事：自己的东西挪进商人的棋盘
static func _give(s: ShopSession, inst: ItemInstance) -> bool:
	s.home_board.remove(inst.uid)
	var ok := s.board.try_add(inst, true)
	s.sync()
	return ok


static func _cheapest(s: ShopSession) -> ItemInstance:
	var best: ItemInstance = null
	for v in s.board.items():
		var inst := v as ItemInstance
		if best == null or s.tag_price(inst) < s.tag_price(best):
			best = inst
	return best


static func _own(s: ShopSession, items: ItemDatabase, id: StringName) -> ItemInstance:
	var inst := ItemInstance.create(items.get_def(id))
	s.home_board.try_add(inst, true)
	return inst


static func run_stock(t: TestCase) -> void:
	t.begin("290 · 开张一次摆满：shop_stock 件不重复、能上架的、价 = 价值 × 倍数；没有刷新；同种子同货；深度带钱")
	var items := _items()
	var r := _rules(10)
	var s := _shop(items, Wallet.new(0), _node(), r)
	t.eq(s.board.size, ShopSession.BOARD_SIZE, "商人棋盘 8 × 6")
	var cands := ShopSession.candidates(r, items)
	var seen := {}
	for v in s.board.items():
		var inst := v as ItemInstance
		t.check(cands.has(inst.def.id), "'%s' 能上架" % inst.def.id)
		t.check(not seen.has(inst.def.id), "'%s' 不重复" % inst.def.id)
		seen[inst.def.id] = true
		t.check(s.is_merchants(inst.uid), "是商人的")
		t.eq(s.tag_price(inst), s.price_of(inst.def), "挂的是售价")
	t.check(seen.size() <= r.shop_stock and seen.size() >= r.shop_stock - 3, "摆了约 shop_stock 件（%d，放不下的丢）" % seen.size())
	t.check(s.refresh_reason() != "" and not s.refresh(), "没有刷新（319：点了换货科技才能付钱换一次）")
	var s2 := _shop(items, Wallet.new(0), _node(), r)
	var a: Array = []
	var b: Array = []
	for v in s.board.items():
		a.append([(v as ItemInstance).def.id, (v as ItemInstance).origin])
	for v in s2.board.items():
		b.append([(v as ItemInstance).def.id, (v as ItemInstance).origin])
	t.eq(a, b, "同一个点的棋盘永远一样")
	t.eq(s.purse, r.purse_at(0.3), "钱袋 = 100 + 200 × 深度")
	t.eq(r.purse_at(1.0), 300, "最深 300")
	t.eq(r.purse_at(0.0), 100, "最外 100")
	# 包与金银照概率加
	var r2 := _rules()
	r2.bullion_slot_chance = 1.0
	var s3 := _shop(items, Wallet.new(0), _node(), r2)
	var golds := s3.board.items().filter(func(v): return (v as ItemInstance).def.is_bullion())
	t.eq(golds.size(), 1, "金银概率 1：多摆一件金银")
	# 深度把稀有度往上推
	var r3 := _rules(10)
	var sum_out := 0.0
	var sum_in := 0.0
	var n := 0
	var m := 0
	for seed_ in 60:
		for v in ShopSession.new(_node(seed_), r3, items, Wallet.new(0), 0.0).board.items():
			sum_out += (v as ItemInstance).def.rarity
			n += 1
		for v in ShopSession.new(_node(seed_), r3, items, Wallet.new(0), 1.0).board.items():
			sum_in += (v as ItemInstance).def.rarity
			m += 1
	if r3.shop_depth_gain > 0.0:
		t.check(sum_in / m > sum_out / n, "最内的棋盘（平均稀有度 %.2f）比最外（%.2f）好" % [sum_in / m, sum_out / n])


static func run_buy(t: TestCase) -> void:
	t.begin("290 · 买：拿上秤 → 左盘 = 售价；点钱袋补差；钱不够补不齐不能成交；成交钱进商人钱袋、东西归你")
	var items := _items()
	var wallet := Wallet.new(100000)
	var s := _shop(items, wallet)
	var ware := _cheapest(s)
	var price := s.tag_price(ware)
	var purse0 := s.purse
	t.check(s.table_empty() and not s.can_deal(), "空桌不能成交")
	t.check(_take(s, ware), "拖进自己的棋盘")
	t.eq(s.taken.get(ware.uid, -1), price, "左盘记上这件的售价")
	t.eq(s.left_total(), price, "左盘总价")
	t.eq(s.status(), {"kind": "short", "n": price}, "牌：还差 N")
	t.check(not s.can_deal(), "右盘轻：不能成交")
	t.eq(s.toggle_my_coins(), price, "点自己的钱袋：放上还差的那么多")
	t.eq(s.status()["kind"], "even", "牌：够了")
	t.check(s.can_deal(), "能成交")
	t.eq(s.toggle_my_coins(), 0, "再点一下：收回")
	s.toggle_my_coins()
	var log_: Array = []
	s.dealt.connect(func(got: Array, gave: Array, paid: int, change: int): log_.append([got.size(), gave.size(), paid, change]))
	t.check(s.deal(), "成交")
	t.eq(wallet.balance, 100000 - price, "钱包扣了售价")
	t.eq(s.purse, purse0 + price, "钱进了商人钱袋")
	t.eq(log_, [[1, 0, price, 0]], "dealt：拿到 1 件、付了 N")
	t.check(not s.is_merchants(ware.uid) and s.home_board.has_item(ware.uid), "东西归你了")
	t.check(s.table_empty() and s.my_coins == 0, "桌上清了")
	# 卖掉就空着：再开同一点，那件不在了
	var back := ShopSession.new(s.node, s.rules, items, Wallet.new(0), 0.3)
	t.check(back.board.items().all(func(v): return (v as ItemInstance).def.id != ware.def.id or (v as ItemInstance).uid != ware.uid), "读档：卖掉的不回来")
	t.eq(back.board.items().size(), s.board.items().size(), "读档：棋盘少一件")
	t.eq(back.purse, s.purse, "读档：钱袋记着")
	# 钱不够：补不齐
	var poor := Wallet.new(1)
	var sp := _shop(items, poor, _node(9))
	var pricey: ItemInstance = null
	for v in sp.board.items():
		if sp.tag_price(v) > 1:
			pricey = v
			break
	if pricey != null:
		_take(sp, pricey)
		t.eq(sp.toggle_my_coins(), 1, "钱不够：把能放的全放上")
		t.eq(sp.status()["kind"], "short", "牌仍写还差")
		t.check(not sp.can_deal() and not sp.deal(), "成交不了")
		t.eq(poor.balance, 1, "一分不动")


static func run_barter(t: TestCase) -> void:
	t.begin("290 · 以物易物：给的东西按收购价进右盘；右盘重 = 找你 N，不点商人钱袋就是白送；点了他找钱；付不起写「他只付得起」")
	var items := _items()
	var wallet := Wallet.new(0)
	var s := _shop(items, wallet)
	var ware := _cheapest(s)
	var mine := _own(s, items, &"longsword")
	var sell := s.sell_price_of(mine.def, mine)
	t.eq(sell, floori(float(s.price_of(mine.def)) * 0.3), "收购价 = 售价 × 三成")
	t.check(_give(s, mine), "拖进商人的棋盘")
	t.eq(s.given.get(mine.uid, -1), sell, "右盘记上收购价")
	t.check(not s.is_merchants(mine.uid), "还不是他的（没成交）")
	_take(s, ware)
	var d := sell - s.tag_price(ware)
	if d > 0:
		t.eq(s.status(), {"kind": "change", "n": d}, "右盘重：牌写找你 N")
		t.check(s.can_deal(), "右 ≥ 左：能成交")
		var purse0 := s.purse
		t.eq(s.toggle_his_coins(), d, "点商人的钱袋：他放上多出来的")
		t.eq(s.status()["kind"], "even", "牌：够了")
		t.check(s.deal(), "成交")
		t.eq(wallet.balance, d, "找的钱进了钱包")
		t.eq(s.purse, purse0 - d, "商人钱袋少了")
		t.check(s.is_merchants(mine.uid) and s.home_board.has_item(ware.uid), "两件换了主人")
	# 白送：不点他的钱袋
	var w2 := Wallet.new(0)
	var s2 := _shop(items, w2, _node(7))
	var m2 := _own(s2, items, &"longsword")
	_give(s2, m2)
	var purse2 := s2.purse
	t.eq(s2.status()["kind"], "change", "只卖不买：找你 N")
	t.check(s2.deal(), "不点钱袋也能成交")
	t.eq(w2.balance, 0, "不点就是白送")
	t.eq(s2.purse, purse2, "他一分没出")
	# 付不起
	var w3 := Wallet.new(0)
	var r3 := _rules()
	r3.shop_purse_base = 1
	r3.shop_purse_depth = 0
	var s3 := _shop(items, w3, _node(8), r3)
	var m3 := _own(s3, items, &"longsword")
	_give(s3, m3)
	if s3.given.get(m3.uid, 0) > 1:
		t.eq(s3.status(), {"kind": "cant_pay", "n": 1}, "他钱袋只有 1：他只付得起 1")
		t.eq(s3.toggle_his_coins(), 1, "点他的钱袋：只放得出 1")
		t.check(s3.deal(), "你认了就照样成交")
		t.eq(w3.balance, 1, "拿到 1")
		t.eq(s3.purse, 0, "他钱袋空了")


static func run_leave(t: TestCase) -> void:
	t.begin("290 · 离开：桌上的东西各回各家（他的回原位、你的回自己棋盘，放不下到地上），钱收回")
	var items := _items()
	var wallet := Wallet.new(500)
	var s := _shop(items, wallet)
	var ware := _cheapest(s)
	var at := ware.origin
	var mine := _own(s, items, &"longsword")
	_take(s, ware)
	_give(s, mine)
	s.toggle_my_coins()
	var closed: Array = []
	s.closed.connect(func(): closed.append(1))
	s.leave()
	s.leave()
	t.eq(closed.size(), 1, "关门只发一次")
	t.check(s.board.has_item(ware.uid) and s.board.get_item(ware.uid).origin == at, "他的货回原位")
	t.check(s.home_board.has_item(mine.uid), "你的东西回了自己棋盘")
	t.eq(wallet.balance, 500, "钱没动")
	t.check(s.table_empty() and s.my_coins == 0, "桌上清了")
	t.check(not s.can_deal(), "关了门成交不了")
	# 自己棋盘满了：退回地上
	var s2 := _shop(items, Wallet.new(0), _node(6))
	s2.home_board = GridInventory.new(Vector2i(1, 1), 1, false)
	var big := ItemInstance.create(items.get_def(&"longsword"))
	s2.board.try_add(big, true)
	s2.sync()
	s2.cancel_table()
	t.check(s2.home_ground.has_item(big.uid), "放不下的到地上")


static func run_refuse(t: TestCase) -> void:
	t.begin("290 · 不能上桌：锁住的、独一的红武、券、装着东西的包；平常的能")
	var items := _items()
	var s := _shop(items, Wallet.new(0))
	var plain := _own(s, items, &"longsword")
	t.eq(s.refuse_reason(plain), "", "平常的能")
	var locked := _own(s, items, &"knife")
	locked.set_locked(true)
	t.check(s.refuse_reason(locked) != "", "锁住的不能")
	for id in items.ids():
		var def := items.get_def(id)
		if def.is_unique():
			t.check(s.refuse_reason(ItemInstance.create(def)) != "", "独一的红武不能（%s）" % id)
			break
	for id in items.ids():
		var def := items.get_def(id)
		if def.is_ticket():
			t.check(s.refuse_reason(ItemInstance.create(def)) != "", "券不能（%s）" % id)
			break


static func run_belt(t: TestCase) -> void:
	t.begin("290 · 随身格：点了上桌、价进左盘；成交才进腰带；腰带满了那格退回不算钱；没接腰带放不上")
	var items := _items()
	var r := _rules()
	var std: EconomyRules = load(ContentPaths.asset_file("economy_rules", "standard"))
	r.belt_stock = std.belt_stock.duplicate()
	if r.belt_stock.is_empty():
		t.check(true, "没有随身技能：跳过")
		return
	var wallet := Wallet.new(100000)
	var s := _shop(items, wallet, _node(), r)
	t.check(not s.belt_offers.is_empty(), "随身那一排有货")
	t.check(s.toggle_belt(0) != "", "没接腰带：放不上")
	var granted: Array = []
	s.belt_grant = func(id: StringName, n: int) -> int:
		granted.append(id)
		return n
	t.eq(s.toggle_belt(0), "", "放上桌")
	var price := int(s.belt_offers[0]["price"])
	t.eq(s.left_total(), price, "价进左盘")
	s.toggle_my_coins()
	t.check(s.deal(), "成交")
	t.eq(granted, [StringName(String(s.belt_offers[0]["id"]))], "进了腰带")
	t.eq(wallet.balance, 100000 - price, "付了钱")
	t.check(s.belt_sold.has(0) and s.toggle_belt(0) != "", "卖掉的那格不能再放")
	# 腰带满
	var w2 := Wallet.new(100000)
	var s2 := _shop(items, w2, _node(11), r)
	s2.belt_grant = func(_id: StringName, _n: int) -> int: return 0
	s2.toggle_belt(0)
	var mine := _own(s2, items, &"knife")
	t.check(_give(s2, mine), "再给他一件")
	s2.toggle_my_coins()
	t.check(s2.my_coins > 0, "点钱袋补了差")
	t.check(s2.deal(), "成交")
	t.check(not s2.belt_sold.has(0) and s2.belt_on.is_empty(), "腰带满了：那格退回、没卖掉")
	t.eq(w2.balance, 100000, "那格不算钱")


static func run_resale(t: TestCase) -> void:
	t.begin("290 · 回购：这次卖给他的挂你拿到的价；离开再来按正常售价")
	var items := _items()
	var wallet := Wallet.new(100000)
	var node := _node()
	var s := _shop(items, wallet, node)
	var mine := _own(s, items, &"longsword")
	var sell := s.sell_price_of(mine.def, mine)
	t.check(_give(s, mine), "拖进他的棋盘")
	t.check(s.deal(), "卖给他")
	t.eq(s.tag_price(s.board.get_item(mine.uid)), sell, "这次进店：挂你拿到的价")
	_take(s, s.board.get_item(mine.uid))
	t.eq(s.left_total(), sell, "原价买回")
	s.cancel_table()
	s.leave()
	var again := ShopSession.new(node, _rules(), items, wallet, 0.3)
	var it := again.board.get_item(mine.uid)
	t.not_null(it, "读档：卖给他的摆在他棋盘上")
	if it != null:
		t.eq(again.tag_price(it), again.price_of(it.def), "离开再来：正常售价")


static func run_save(t: TestCase) -> void:
	t.begin("290 · 存档：棋盘整块与钱袋进 node.content[\"shop\"]（v2）；老档没有就按种子摆一次")
	var items := _items()
	var node := _node()
	var s := _shop(items, Wallet.new(0), node)
	var saved: Dictionary = node.content["shop"]
	t.eq(int(saved["v"]), ShopSession.SAVE_VERSION, "v2")
	t.check(saved["board"] is Dictionary and saved.has("purse"), "棋盘与钱袋")
	var round_trip := MapNode.from_dict(JSON.parse_string(JSON.stringify(node.to_dict())))
	var back := ShopSession.new(round_trip, _rules(), items, Wallet.new(0), 0.3)
	t.eq(back.board.items().size(), s.board.items().size(), "读回同样多的货")
	t.eq(back.purse, s.purse, "钱袋读回")
	var old := _node()
	old.content["shop"] = {"refreshes": 2, "sold": [0]}
	var restock := ShopSession.new(old, _rules(), items, Wallet.new(0), 0.3)
	t.eq(restock.board.items().size(), s.board.items().size(), "老档：按种子摆一次")
	t.eq(int(old.content["shop"]["v"]), ShopSession.SAVE_VERSION, "老档改写成 v2")
