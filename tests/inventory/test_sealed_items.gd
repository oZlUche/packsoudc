## 封存（报告 079 起）：带 sealed 标签的道具数据保留、按 id 取得到，但不进任何候选（搜索、商店、敌人装备、珍宝、图鉴用的清单）；
## 导入器拦开局装备 / 初始包 / 事件给它。250 起现代道具全删，库里没有封存的了 —— 机制用一件测试里登记的封存道具照测
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _sealed_def() -> ItemDef:
	var def := (_db().get_def(&"knife") as ItemDef).duplicate(true) as ItemDef
	def.id = &"test_sealed_knife"
	def.tags = def.tags.duplicate()
	def.tags.append(ItemDef.SEALED)
	return def


static func run_sealed_listing(t: TestCase) -> void:
	t.begin("封存 · 数据保留、按 id 取得到；ids() 不含封存的、all_ids() 含；候选清单（搜索 / 商店 / 敌人 / 珍宝）一个封存的都没有")
	var db := _db()
	var sealed: Array = db.all_ids().filter(func(id) -> bool: return db.get_def(id).is_sealed())
	t.eq(sealed, [], "250 起库里没有封存的道具（现代道具全删）")
	var def := _sealed_def()
	t.check(db.register(def), "登记一件封存道具")
	t.check(db.get_def(def.id) != null and db.get_def(def.id).is_sealed(), "按 id 取得到、带 sealed 标签")
	t.check(not db.ids().has(def.id), "不在 ids() 里")
	t.check(db.all_ids().has(def.id), "在 all_ids() 里")
	var blessed: Array = db.all_ids().filter(func(id) -> bool: return db.get_def(id).is_blessed())
	var tokens: Array = db.all_ids().filter(func(id) -> bool: return db.get_def(id).is_token())
	var signature: Array = db.all_ids().filter(func(id) -> bool: return db.get_def(id).is_signature())
	t.check(signature.has(&"legion_phalera"), "256：军功牌是随身之物")
	t.eq(db.ids().size() + 1 + db.keepsake_ids().size() + blessed.size() + tokens.size() + signature.size(), db.all_ids().size(), "能用的 + 封存的 + 特殊道具 + 赐福版 + 铸牌 + 随身之物 = 全部（088 / 095 / 175 / 256）")
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
		t.check(not ids.has(def.id), "%s 里没有封存的" % name)


static func run_content(t: TestCase) -> void:
	t.begin("剑与魔法道具 · 走管线；开局装备、角色初始包、敌人招牌都在库里；导入器拦封存的")
	var db := _db()
	for id in [&"shortsword", &"longsword", &"scimitar", &"longbow", &"arrows", &"round_shield", &"leather_armor", &"gambeson",
			&"mithril_sword", &"blessed_shield", &"blessed_longbow", &"salve", &"bandage", &"fire_crystal", &"magic_staff",
			&"warped_obsidian", &"charm_brute", &"pale_shard", &"barbarian_necklace"]:
		var d := db.get_def(id)
		t.check(d != null and not d.is_sealed(), "%s 在库里、没封存" % id)
	t.check(ItemValue.of(db.get_def(&"warped_obsidian")) > ItemValue.of(db.get_def(&"leather_armor")), "异化黑曜石小而贵（value 覆盖）")
	t.check(db.get_def(&"barbarian_necklace").combat == null or db.get_def(&"barbarian_necklace").combat.rules.is_empty(), "项链只值军功、不参战")
	for l in GameFlow.load_loadouts():
		for id in (l as LoadoutDef).items:
			t.check(db.get_def(id) != null and not db.get_def(id).is_sealed(), "开局装备 %s 的 %s 在库里" % [(l as LoadoutDef).id, id])
	for c in GameFlow.load_characters():
		for id in (c as CharacterDef).starting_bags:
			t.check(db.get_def(id) != null and not db.get_def(id).is_sealed(), "角色 %s 的初始包 %s 在库里" % [(c as CharacterDef).id, id])
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	for eid in TestSupport.enemy_ids():
		for id in enemies.enemy(eid).signature:
			t.check(db.get_def(id) != null and not db.get_def(id).is_sealed(), "敌人 %s 的招牌 %s 在库里" % [eid, id])
	# 导入器拦
	var ctx := ContentImporter.Context.new()
	for id in db.all_ids():
		ctx.register_item(db.get_def(id))
	ctx.register_item(_sealed_def())
	var rep := ImportReport.new()
	ContentImporter.import_loadout({"id": "x", "display_name": "x", "items": ["bag_leather", "test_sealed_knife"]}, ctx, rep)
	t.check(rep.to_text().contains("已封存"), "开局装备带封存的道具：导入器报「已封存」")
	var rep2 := ImportReport.new()
	ContentImporter.import_event({"id": "y", "title": "y", "options": [{"label": "a", "outcomes": [{"type": "give_item", "item": "test_sealed_knife"}]}]}, ctx, rep2)
	t.check(rep2.to_text().contains("已封存"), "事件给封存的道具：导入器报「已封存」")
	var rep3 := ImportReport.new()
	var ok := ContentImporter.import_loadout({"id": "z", "display_name": "z", "items": ["bag_leather", "shortsword"]}, ctx, rep3)
	t.check(rep3.ok() and ok != null, "没封存的照过")
