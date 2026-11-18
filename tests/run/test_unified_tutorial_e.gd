## 统一教程 E（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §6 S5）：序章二第一个岔路合流后的教学商店 ——
## 先过 tut2_shop（讲本局钱包和基地集市的区别、秤上谈价、成交才算、补差找零、拿回来），进去就是写死的货架；可以不进
extends RefCounted


static func _at_shop(t: TestCase) -> Dictionary:
	var c := TestSupport.load_content("prologue_2", ["brutus", "events"])
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	t.not_null(s, "开得了局")
	if s == null:
		return {}
	s.event_defs = c.events
	var shop: MapNode = null
	for id in s.map.node_ids():
		if s.map.get_node(id).type == &"shop":
			shop = s.map.get_node(id)
	t.not_null(shop, "图上有商店")
	if shop == null:
		return {}
	var before := -1
	for id in s.map.neighbors(shop.id):
		if s.map.get_node(id).tier < shop.tier:
			before = id
	s.travel.start_at(before)
	s.events.pending = {}
	t.check(s.step_to(shop.id), "从搜索点 2 走到商店")
	return {"s": s, "shop": shop}


static func run_shop_event(t: TestCase) -> void:
	t.begin("统一教程 E · 序章二教学商店：先看 tut2_shop，进去是写死的货架、商人带着钱袋，可以不买就走")
	var got := _at_shop(t)
	if got.is_empty():
		return
	var s: RunState = got["s"]
	var shop: MapNode = got["shop"]
	var ev := s.events.pending_event()
	t.check(ev != null and ev.id == &"tut2_shop", "先看教学事件")
	if ev == null:
		return
	t.check(ev.text.contains("基地集市") and ev.text.contains("成交"), "讲了和基地集市的区别、成交才算")
	t.eq(ev.options.size(), 2, "进去看看 / 不进")
	t.check(s.events.choose(0), "进去看看")
	var session: ShopSession = s.events.current_shop
	t.not_null(session, "开了店")
	if session == null:
		return
	var want: Array = shop.content["shop_stock"]
	var have: Array = session.board.items().map(func(i: ItemInstance) -> String: return String(i.def.id))
	for id in want:
		t.check(have.has(id), "货架上有 %s" % id)
	t.check(session.purse > 0, "商人带着钱袋（卖东西能找钱）")
	session.leave()
	t.is_null(s.events.current_shop, "不买也能走")


static func run_shop_skip(t: TestCase) -> void:
	t.begin("统一教程 E · 序章二教学商店：选「不进」照样往下走，岔路两个战斗点都还能去")
	var got := _at_shop(t)
	if got.is_empty():
		return
	var s: RunState = got["s"]
	t.check(s.events.choose(1), "不进")
	t.is_null(s.events.current_shop, "没开店")
	var next: Array = s.travel.available_moves().filter(func(id: int) -> bool: return s.map.get_node(id).type == &"battle")
	t.eq(next.size(), 2, "岔路两个战斗点都能走")
