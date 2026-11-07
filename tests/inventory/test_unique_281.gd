## 281 第三步：八件红武（5 档、独一）裸数据 + 独一闸
extends RefCounted

const REDS := [&"chana", &"duanshui", &"shuangsheng", &"guanri", &"bengshan", &"zhuixing", &"poxiao", &"jimie"]


static func run_reds(t: TestCase) -> void:
	t.begin("281 · 红武：八件 5 档、带独一、说明留空；不进随机池（掉落 / 商店 / 敌人都抽不到），给全库的还在")
	var items := ItemDatabase.new()
	items.load_dir()
	var pool := items.ids()
	var all := items.ids(true)
	for id in REDS:
		var def := items.get_def(id)
		t.check(def != null and def.rarity == 5 and def.is_unique(), "%s：5 档、独一" % id)
		if def == null:
			continue
		t.eq(def.description, "", "%s：说明留空" % id)
		t.eq(def.display_name.length(), 2, "%s：两字名" % id)
		t.check(not pool.has(id), "%s：不进随机池" % id)
		t.check(all.has(id), "%s：全库里有" % id)
		t.eq(items.variants_of(id), [id], "%s：没有赐福版" % id)
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	for eid in [&"brute", &"berserker", &"warden"]:
		var who := enemies.enemy(eid)
		if who == null:
			continue
		var got := EnemyPlacer.school_items(who.schools, items, -1, who)
		t.eq(got.filter(func(id: StringName) -> bool: return items.get_def(id).is_unique()), [], "%s：不带独一" % eid)


static func run_unsellable(t: TestCase) -> void:
	t.begin("281 · 独一不能卖：仓库单卖、一键出售、商店都不收；出售按钮灰掉；铸牌不收")
	var items := ItemDatabase.new()
	items.load_dir()
	var meta := MetaState.new()
	var red := ItemInstance.create(items.get_def(&"chana"))
	t.check(meta.warehouse.try_add(red, true), "刹那进仓库")
	t.eq(meta.sell_item(red.uid), -1, "仓库单卖不了")
	meta.sell_where(-1)
	t.check(meta.warehouse.has_item(red.uid), "一键出售跳过它")
	var act := ItemActions.sell(red, 1, func(_uid): pass)
	t.check(not act.enabled, "出售按钮灰掉")
	var econ := load(ContentPaths.asset_file("economy_rules", "standard")) as EconomyRules
	var shop := ShopSession.new(MapNode.new(), econ, items, Wallet.new())
	t.check(shop.refuse_reason(red) != "", "商店不收（290：上不了秤）")
	t.check(not Forge.accepts(red), "铸牌拖上去无效（不附魔）")
	t.check(Forge.accepts(ItemInstance.create(items.get_def(&"longsword"))), "常规武器照收铸牌")


static func run_owned(t: TestCase) -> void:
	t.begin("281 · 独一闸：仓库 / 本局任一处有了就算已有；事件再给同一件时不给，别的照给")
	var c := TestSupport.load_content("free_mode", ["buffs"])
	var run := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs)
	run.meta = MetaState.new()
	var chana := c.items.get_def(&"chana")
	t.check(UniqueItems.can_give(chana, run.meta, run), "哪儿都没有：能给")
	t.check(UniqueItems.can_give(c.items.get_def(&"longsword"), run.meta, run), "不是独一的总能给")
	var held := ItemInstance.create(c.items.get_def(&"jimie"))
	t.check(run.meta.warehouse.try_add(held, true), "寂灭进仓库")
	t.check(UniqueItems.owned(&"jimie", run.meta, run), "仓库里的算已有")
	t.check(not UniqueItems.owned(&"chana", run.meta, run), "刹那还没有")

	var detail := {"items": ["chana", "chana", "longsword"]}
	run.events.event_resolved.emit(null, &"test", detail)
	var got := run.storage.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"chana")
	t.eq(got.size(), 1, "事件给两次刹那：只落地一件")
	t.eq((detail.get("item_uids", []) as Array).size(), 2, "长剑照给（一刹那 + 一长剑）")
	t.check(UniqueItems.owned(&"chana", run.meta, run), "地上的算已有")
	run.events.event_resolved.emit(null, &"test", {"items": ["jimie"]})
	t.check(run.storage.items().all(func(i: ItemInstance) -> bool: return i.def.id != &"jimie"), "仓库里有寂灭：事件不再给")
