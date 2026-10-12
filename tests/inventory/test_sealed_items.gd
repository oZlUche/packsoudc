## 封存与第一批剑与魔法道具（第 8 阶段 8-4 起步，报告 079）：带 sealed 标签的道具数据保留、按 id 取得到，
## 但不进任何候选（搜索、商店、敌人装备、珍宝、图鉴用的清单）；导入器拦开局装备 / 初始包 / 事件给它；
## 开局装备与敌人的招牌只用没封存的；小说里的那批道具走管线。期望从数据推：封存了几件、留着几件都数出来。
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_sealed_listing(t: TestCase) -> void:
	t.begin("封存 · 数据保留、按 id 取得到；ids() 不含封存的、all_ids() 含；候选清单（搜索 / 商店 / 敌人 / 珍宝）一个封存的都没有")
	var db := _db()
	var sealed: Array = db.all_ids().filter(func(id) -> bool: return db.get_def(id).is_sealed())
	var blessed: Array = db.all_ids().filter(func(id) -> bool: return db.get_def(id).is_blessed())
	t.check(sealed.size() >= 10, "封存了 %d 件现代道具" % sealed.size())
	for id in [&"pistol", &"rifle", &"mag", &"battery", &"drone", &"armor", &"core", &"stim", &"medkit", &"crowbar"]:
		t.check(sealed.has(id), "%s 封存了" % id)
		var def := db.get_def(id)
		t.check(def != null and def.is_sealed() and def.tags.has(ItemDef.SEALED), "%s 的数据还在、带 sealed 标签" % id)
		t.check(not db.ids().has(id), "%s 不在 ids() 里" % id)
		t.check(db.all_ids().has(id), "%s 在 all_ids() 里" % id)
	for id in [&"knife", &"ration", &"cleaver", &"belt_potion", &"bag_leather"]:
		t.check(db.ids().has(id) and not db.get_def(id).is_sealed(), "%s 留着" % id)
	t.eq(db.ids().size() + sealed.size() + db.keepsake_ids().size() + blessed.size(), db.all_ids().size(), "能用的 + 封存的 + 特殊道具 + 赐福版 = 全部（088 / 095）")
	t.eq(db.size(), db.all_ids().size(), "size() 数的是全部")

	var rules: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	var econ: EconomyRules = load(ContentPaths.asset_file("economy_rules", "standard"))
	var drop: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	var pool: EnemyPool = load(ContentPaths.asset_file("enemy_pools", "standard_ruins"))
	var lists := {
		"搜索候选": SearchSession.candidates(rules.search, db),
		"商店候选": ShopSession.candidates(econ, db),
		"敌人流派道具": EnemyPlacer.school_items([&"melee", &"ranged", &"rapid", &"burst", &"bleed"] as Array[StringName], db, -1),
		"敌人通用道具": EnemyPlacer.common_items([] as Array[StringName], pool.loadout, db, -1),
		"珍宝 r3": DropResolver.treasure_candidates(drop, db, 3, [] as Array[StringName]),
		"珍宝 r4": DropResolver.treasure_candidates(drop, db, 4, [] as Array[StringName]),
	}
	for name in lists:
		var ids: Array = lists[name]
		t.check(not ids.is_empty(), "%s 非空（%d）" % [name, ids.size()])
		for id in ids:
			t.check(not db.get_def(id).is_sealed(), "%s 里没有封存的：%s" % [name, id])


static func run_content(t: TestCase) -> void:
	t.begin("第一批剑与魔法道具 · 走管线、都没封存；三套开局装备与角色初始包只用没封存的；敌人招牌没封存的；珍宝标签有人带")
	var db := _db()
	for id in [&"shortsword", &"longsword", &"scimitar", &"longbow", &"arrows", &"round_shield", &"leather_armor", &"gambeson",
			&"mithril_sword", &"blessed_shield", &"blessed_longbow", &"salve", &"bandage", &"fire_crystal", &"magic_staff",
			&"warped_obsidian", &"charm_brute", &"pale_shard", &"barbarian_necklace"]:
		var def := db.get_def(id)
		t.check(def != null and not def.is_sealed(), "%s 在库里、没封存" % id)
	t.check(ItemValue.of(db.get_def(&"warped_obsidian")) > ItemValue.of(db.get_def(&"leather_armor")), "异化黑曜石小而贵（value 覆盖）")
	t.check(db.get_def(&"barbarian_necklace").combat == null or db.get_def(&"barbarian_necklace").combat.rules.is_empty(), "项链只值军功、不参战")
	for l in GameFlow.load_loadouts():
		for id in (l as LoadoutDef).items:
			t.check(db.get_def(id) != null and not db.get_def(id).is_sealed(), "开局装备 %s 的 %s 没封存" % [(l as LoadoutDef).id, id])
	for c in GameFlow.load_characters():
		for id in (c as CharacterDef).starting_bags:
			t.check(not db.get_def(id).is_sealed(), "角色 %s 的初始包 %s 没封存" % [(c as CharacterDef).id, id])
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	for eid in TestSupport.enemy_ids():
		for id in enemies.enemy(eid).signature:
			t.check(db.get_def(id) != null and not db.get_def(id).is_sealed(), "敌人 %s 的招牌 %s 没封存" % [eid, id])
	# 导入器拦
	var ctx := ContentImporter.Context.new()
	for id in db.all_ids():
		ctx.register_item(db.get_def(id))
	var rep := ImportReport.new()
	ContentImporter.import_loadout({"id": "x", "display_name": "x", "items": ["bag_leather", "rifle"]}, ctx, rep)
	t.check(rep.to_text().contains("已封存"), "开局装备带封存的道具：导入器报「已封存」")
	var rep2 := ImportReport.new()
	ContentImporter.import_event({"id": "y", "title": "y", "options": [{"label": "a", "outcomes": [{"type": "give_item", "item": "medkit"}]}]}, ctx, rep2)
	t.check(rep2.to_text().contains("已封存"), "事件给封存的道具：导入器报「已封存」")
	var rep3 := ImportReport.new()
	var ok := ContentImporter.import_loadout({"id": "z", "display_name": "z", "items": ["bag_leather", "shortsword"]}, ctx, rep3)
	t.check(rep3.ok() and ok != null, "没封存的照过")
