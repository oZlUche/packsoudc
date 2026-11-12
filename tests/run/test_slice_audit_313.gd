## 313（试玩切片 S1 第三批）：商店照节点写死的货架摆货；清单核对 —— 正式清单没有问题、改坏了能查出来、整局走只见到清单里的东西
extends RefCounted


static func run_fixed_shop(t: TestCase) -> void:
	t.begin("313 · 商店：节点写了货架就照着摆（不抽、不加包和金银）；没写照旧随机")
	var items := ItemDatabase.new()
	items.load_dir()
	var econ: EconomyRules = (load(ContentPaths.asset_file("economy_rules", "standard")) as EconomyRules).duplicate()
	econ.shop_bag_slot_chance = 1.0
	econ.bullion_slot_chance = 1.0
	var node := MapNode.new()
	node.content_seed = 17
	node.content[ShopSession.FIXED_KEY] = ["shortsword", "salve", "salve", "no_such_item"]
	var s := ShopSession.new(node, econ, items, Wallet.new())
	var got: Array = s.board.items().map(func(i: ItemInstance) -> String: return String(i.def.id))
	got.sort()
	t.eq(got, ["salve", "salve", "shortsword"], "照写的摆：重复的两件、不认识的跳过、没有包和金银")
	var other := MapNode.new()
	other.content_seed = 17
	var r := ShopSession.new(other, econ, items, Wallet.new())
	t.check(r.board.item_count() > 0, "没写货架：照旧随机摆货（%d 件）" % r.board.item_count())


static func _db() -> Array:
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	return [items, enemies, RecipeDef.load_all(), EventPlacer.load_all()]


static func run_static(t: TestCase) -> void:
	t.begin("313 · 清单核对（静态）：正式清单没有问题；去掉一件、加一个不存在的、少一条配方原料，都查得出来")
	var db := _db()
	var m := SliceAudit.load_manifest("slice_ruins")
	t.check(not m.is_empty(), "读得到正式清单")
	t.eq(SliceAudit.check_static(m, db[0], db[1], db[2], db[3]), [] as Array[String], "正式清单没有问题")
	var broken := m.duplicate(true)
	(broken["allowed_item_ids"] as Array).erase("shortsword")
	(broken["allowed_item_ids"] as Array).append("no_such_item")
	(broken["recipe_ids"] as Array).append("no_such_recipe")
	var bad := SliceAudit.check_static(broken, db[0], db[1], db[2], db[3])
	t.check(bad.has("清单里的道具 no_such_item 不存在"), "不存在的道具（%s）" % [bad])
	t.check(bad.has("清单里的配方 no_such_recipe 不存在"), "不存在的配方")
	t.check(bad.has("点 4 的道具 shortsword 不在清单里"), "商店的短剑不在清单里")
	var fake := RecipeDef.new()
	fake.id = &"fake_two_shortswords"
	fake.inputs = [&"shortsword", &"shortsword"] as Array[StringName]
	fake.output = &"greatsword"
	var fake2 := RecipeDef.new()
	fake2.id = &"fake_knife_salve"
	fake2.inputs = [&"knife", &"salve"] as Array[StringName]
	fake2.output = &"greatsword"
	bad = SliceAudit.check_static(m, db[0], db[1], [fake, fake2], db[3])
	t.check(not bad.any(func(x: String) -> bool: return x.contains("fake_two_shortswords")), "短剑全图一把：两把短剑的配方做不出来，不报")
	t.check(bad.has("清单外的配方 fake_knife_salve 在切片里做得出来（成品 greatsword）"), "清单外的配方做得出来：报")


static func run_walk(t: TestCase) -> void:
	t.begin("313 · 清单核对（整局走）：3 个种子从出生点走到撤离，见到的道具都在清单里，商店的货也看到了")
	var m := SliceAudit.load_manifest("slice_ruins")
	var allowed: Array = m.get("allowed_item_ids", [])
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	for k in [1, 2, 3]:
		var seen := SliceAudit.walk(m, k, items, enemies, sets)
		t.check(seen.has("shortsword"), "种子 %d 走到了商店（%s）" % [k, seen.keys()])
		t.eq(seen.keys().filter(func(id) -> bool: return not allowed.has(String(id))), [], "种子 %d 没见到清单外的东西" % k)
