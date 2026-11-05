class_name UniqueItems
extends RefCounted
## 281 第三步：带 `unique` 的道具全局只许有一件。
## 仓库、带回来还没收的棋盘、市场货架、本局的棋盘 / 地上 / 保险箱 / 各点存放、等着拿的战利品、
## 搜索的收获箱、商店（货架 / 买回）、地图上敌人带着的、等着开打的那一场 —— 任一处有，就算已有。


## 已有的独一道具 id（StringName → true）。meta / run 都可以是 null；items 缺省用 run 的
static func owned_ids(meta: MetaState, run: RunState = null, items: ItemDatabase = null) -> Dictionary:
	var out := {}
	if meta == null and run != null:
		meta = run.meta
	if items == null and run != null:
		items = run.items
	if meta != null:
		if meta.warehouse != null:
			_add_insts(out, meta.warehouse.items())
		if meta.board != null:
			_add_insts(out, meta.board.items())
		for e in meta.market_stock:
			_add_id(out, e.get("id", ""), items)
	if run != null:
		_add_insts(out, run._owned_now())
		var stored := NodeStorageModule.of(run)
		if stored != null:
			for k in stored.nodes:
				_add_insts(out, stored.nodes[k])
		if run.pending_loot != null:
			_add_insts(out, run.pending_loot.items())
		var ev := run.events
		if ev != null:
			if ev.current_search != null and ev.current_search.haul_box != null:
				_add_insts(out, ev.current_search.haul_box.items())
			if ev.current_shop != null:
				_add_shop(out, ev.current_shop, items)
			if not ev.pending_battle.is_empty():
				_add_content(out, ev.pending_battle.get("content", {}), items)
		if run.map != null:
			for k in run.map.nodes:
				var node := run.map.nodes[k] as MapNode
				if node != null:
					_add_content(out, node.content, items)
	return out


static func owned(id: StringName, meta: MetaState, run: RunState = null, items: ItemDatabase = null) -> bool:
	return owned_ids(meta, run, items).has(id)


## 能不能再给一件：不是独一的总能给；独一的只在哪儿都没有时才能给
static func can_give(def: ItemDef, meta: MetaState, run: RunState = null, items: ItemDatabase = null) -> bool:
	return def != null and (not def.is_unique() or not owned(def.id, meta, run, items))


static func _add_insts(out: Dictionary, insts: Array) -> void:
	for v in insts:
		var inst := v as ItemInstance
		if inst != null and inst.def != null and inst.def.is_unique():
			out[inst.def.id] = true


static func _add_shop(out: Dictionary, shop: ShopSession, items: ItemDatabase) -> void:
	for box in shop.shelves:
		if box != null:
			_add_insts(out, box.items())
	for e in shop.buyback:
		_add_insts(out, [e.get("inst")])
	if items != null:
		for i in shop.stock.size():
			if not shop.sold.has(i):
				var d := items.get_def(StringName(String(shop.stock[i].get("id", ""))))
				if d != null and d.is_unique():
					out[d.id] = true


static func _add_content(out: Dictionary, content: Variant, items: ItemDatabase) -> void:
	if not (content is Dictionary) or items == null:
		return
	for id in DropResolver.carried_ids(content):
		var d := items.get_def(id)
		if d != null and d.is_unique():
			out[d.id] = true


static func _add_id(out: Dictionary, id: Variant, items: ItemDatabase) -> void:
	if items == null:
		return
	var d := items.get_def(StringName(String(id)))
	if d != null and d.is_unique():
		out[d.id] = true
