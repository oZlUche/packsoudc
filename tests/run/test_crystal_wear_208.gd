## 208（架构线程夜间方案，待定按推荐）：魔晶石的消耗看得见 —— 实例变体图 `assets/items/<id>@<变体>.png`（耐久 `c<剩几次>`、
## 207 生长 `s<阶>`），没有这一档的图就在左下角画剩余次数点；归零换成碎晶 `crystal_shards`，装载格空出来；老档里碎了的读档时换。
## 246 补充二：魔晶石不再写 `broken_into`（碎了留在原格、低两档），「换成别的件」这条路照旧在，下面拿临时改过的定义验
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const C148 := preload("res://tests/run/test_crystal_148.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _with_charges(db: ItemDatabase, id: StringName, left: int) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id))
	inst.state[WearProfile.CHARGES_KEY] = left
	return inst


static func run_variant_of(t: TestCase) -> void:
	t.begin("208 · variant_of：满的空、没满按张数折算（246 乙：满 27 次四张图 1～9 → c1、10～18 → c2、19～26 → c3）、碎了 c0；没耐久的空；生长到阶 s<阶>")
	var db := _db()
	var fire := ItemInstance.create(db.get_def(&"fire_crystal"))
	t.eq(ItemPainter.variant_of(fire), &"", "满的：本图")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"fire_crystal", 2)), &"c1", "剩 2 次：c1")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"fire_crystal", 9)), &"c1", "剩 9 次：c1")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"fire_crystal", 10)), &"c2", "剩 10 次：c2")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"fire_crystal", 18)), &"c2", "剩 18 次：c2")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"fire_crystal", 19)), &"c3", "剩 19 次：c3")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"fire_crystal", 26)), &"c3", "剩 26 次：c3")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"ice_crystal", 1)), &"c1", "剩 1 次：c1")
	t.eq(ItemPainter.variant_of(_with_charges(db, &"lightning_crystal", 0)), &"c0", "碎了：c0")
	t.eq(ItemPainter.variant_of(ItemInstance.create(db.get_def(&"knife"))), &"", "没有耐久：空")
	t.eq(ItemPainter.variant_of(null), &"", "空实例：空")
	var seed := ItemInstance.create(db.get_def(&"thorn_seed"))
	t.eq(ItemPainter.variant_of(seed), &"", "种子没长：空")
	seed.state[GrowthProfile.STAGE_KEY] = 1
	t.eq(ItemPainter.variant_of(seed), &"s1", "长到第 1 阶：s1")


static func run_art_variant(t: TestCase) -> void:
	t.begin("208 · art_of 认变体：清单里有 → <id>@<变体>；没有 → 回落本图；赐福版回落原件的变体")
	var db := _db()
	ItemPainter.clear_art_cache()
	var knife := db.get_def(&"knife")
	t.eq(ItemPainter.variant_file(knife, &"c2"), "", "清单里没有：不取变体")
	if ItemPainter.art_available() and ItemPainter.art_ids().has(&"knife"):
		t.check(ItemPainter.art_of(knife, 60.0, &"c2") == ItemPainter.art_of(knife), "没有变体图：画本图")
	ItemPainter.art_variants()[&"knife"] = {&"c2": true}
	t.eq(ItemPainter.variant_file(knife, &"c2"), "knife@c2", "清单里有：取 knife@c2")
	t.eq(ItemPainter.variant_file(knife, &"c1"), "", "别的档没有：空")
	var blessed: ItemDef = null
	for id in db.ids(true):
		var d := db.get_def(id)
		if d.is_blessed() and d.blessed_of == &"knife":
			blessed = d
			break
	if blessed != null:
		t.eq(ItemPainter.variant_file(blessed, &"c2"), "knife@c2", "赐福版回落原件的变体")
	ItemPainter.clear_art_cache()


static func run_charge_dots(t: TestCase) -> void:
	t.begin("208 · 次数角标：满的不画；没满画 max 个点、亮的 = 剩的；落在当前朝向最靠左下那一格；有这一档的变体图就不画")
	var db := _db()
	ItemPainter.clear_art_cache()
	ItemPainter.art_variants().erase(&"fire_crystal")     # 先当作还没交变体图（交了的另在下面验）
	var cell := 60.0
	t.eq(ItemPainter.charge_dots(ItemInstance.create(db.get_def(&"fire_crystal")), 0, Vector2.ZERO, cell).size(), 0, "满的：不画")
	t.eq(ItemPainter.charge_dots(ItemInstance.create(db.get_def(&"knife")), 0, Vector2.ZERO, cell).size(), 0, "没耐久：不画")
	var two := _with_charges(db, &"fire_crystal", 4)
	var full := two.def.wear.max_charges / two.def.wear.charge_band
	var dots := ItemPainter.charge_dots(two, 0, Vector2(10, 20), cell)
	t.eq(dots.size(), full, "246 乙：一档一个点，%d 个点" % full)
	t.eq(dots.filter(func(d): return bool(d["lit"])).size(), 2, "剩 4 次 = 第二档：亮两个")
	# 1×2 横放（rot 0）：左下那一格 = (0, 0)；竖放（rot 1）：(0, 1)
	var y0: float = (dots[0]["at"] as Vector2).y
	t.check(y0 > 20 + cell * 0.5 and y0 < 20 + cell, "横放：点在第一行的下半")
	t.check((dots[0]["at"] as Vector2).x < 10 + cell * 0.5, "横放：从左边起")
	var up := ItemPainter.charge_dots(two, 1, Vector2.ZERO, cell)
	t.check((up[0]["at"] as Vector2).y > cell * 1.5, "竖放：点在下面那一格")
	var amber := ItemPainter.charge_dots(_with_charges(db, &"raw_amber", 3), 0, Vector2.ZERO, cell)
	t.check(amber.all(func(d): return (d["at"] as Vector2).x < cell), "246：一格宽的件九个点折成几排，不出格")
	ItemPainter.art_variants()[&"fire_crystal"] = {&"c1": true}
	t.eq(ItemPainter.charge_dots(two, 0, Vector2.ZERO, cell).size(), 0, "有 c1 的图（剩 4 次）：不画角标")
	t.eq(ItemPainter.charge_dots(_with_charges(db, &"fire_crystal", 12), 0, Vector2.ZERO, cell).size(), full, "c2 没图：照画")
	ItemPainter.clear_art_cache()


static func run_shatter(t: TestCase) -> void:
	t.begin("208 · 碎成碎晶：打到归零就地换成 crystal_shards（原点那一格），装载格空出来、法杖不再带它；没写 broken_into 的留着原件")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var shards := c.items.get_def(&"crystal_shards")
	t.not_null(shards, "有碎晶")
	if shards == null:
		return
	t.eq(shards.cell_count(), 1, "碎晶 1 格")
	t.check(shards.tags.has(&"magic") and shards.material == "gem" and shards.tags.has(&"material"), "碎晶：素材、魔法、材质宝石")
	t.eq(shards.value, 30, "碎晶的价 30（244 补充一；晶石涨到 150 后不再按 × 0.25 跟着）")
	for id in [&"fire_crystal", &"ice_crystal", &"lightning_crystal", &"quartz_cluster", &"raw_amber"]:
		t.eq(c.items.get_def(id).wear.broken_into, &"", "246：%s 碎了不再变碎晶" % id)
	var wear := c.items.get_def(&"fire_crystal").wear
	wear.broken_into = &"crystal_shards"     # 换件这条路照旧在：临时写上验，末尾还原（定义是共享的）
	var b := C148._staff_board(c.items, &"fire_crystal", &"")
	var lit := b["left"] as ItemInstance
	var at := lit.origin
	lit.state[WearProfile.CHARGES_KEY] = 1
	s.board = b["board"]
	var placed_before := s.placed_ids.duplicate()
	var node := CS._battle_node(s)
	s.events.last_battle = {"player": s.compile_player(), "node": node.id}
	s.events.battle_finished.emit(node, BattleResult.new(), true)
	t.check(s.board.get_item(lit.uid) == null, "碎了的晶石不在棋盘上了")
	var shard: ItemInstance = null
	for inst in s.board.items():
		if (inst as ItemInstance).def.id == &"crystal_shards":
			shard = inst
	t.not_null(shard, "棋盘上多了一堆碎晶")
	if shard != null:
		t.eq(shard.origin, at, "碎晶在原点那一格")
	t.eq(s.placed_ids, placed_before, "原地换件不算置入（信力不记）")
	var spec := s.compile_player()
	t.eq(spec.fed_uids.size(), 0, "法杖的装载格空了：没有供给")
	t.eq(spec.item_of((b["staff"] as ItemInstance).uid).loaded.size(), 0, "轮读表空了")
	wear.broken_into = &""

	# 没写换成什么：原件留着（148 的老样子）
	var plain := (c.items.get_def(&"fire_crystal").duplicate(true)) as ItemDef
	plain.wear.broken_into = &""
	var g := GridInventory.new(Vector2i(3, 2), 1, false)
	var keep := ItemInstance.create(plain)
	g.place(keep, Vector2i(0, 0), 0)
	keep.state[WearProfile.CHARGES_KEY] = 0
	t.check(WearModule.shatter(g, keep, c.items) == null and g.get_item(keep.uid) == keep, "没写 broken_into：不换")
	var whole := ItemInstance.create(c.items.get_def(&"fire_crystal"))
	g.place(whole, Vector2i(0, 1), 0)
	t.check(WearModule.shatter(g, whole, c.items) == null and g.get_item(whole.uid) == whole, "没碎：不换")


static func run_reconcile(t: TestCase) -> void:
	t.begin("208 · 读档：老档里 charges 0、定义写了 broken_into 的换成碎晶（原点不动、朝向 0、状态清空），报告记一条；没碎的不动；246：没写的留着")
	var db := _db()
	var stays := _with_charges(db, &"ice_crystal", 0)
	var kept := {"board": {"items": [stays.to_dict()]}}
	var quiet := SaveReport.new()
	SaveReconcile.items(kept, db, quiet, [["board"]])
	t.eq(String(kept["board"]["items"][0]["def"]), "ice_crystal", "246：没写 broken_into：碎了的留着原件")
	db.get_def(&"ice_crystal").wear.broken_into = &"crystal_shards"     # 临时写上验换件那条路，末尾还原（定义是缓存共享的）
	var broken := _with_charges(db, &"ice_crystal", 0)
	broken.rotation = 1
	broken.origin = Vector2i(2, 1)
	var ok := _with_charges(db, &"fire_crystal", 2)
	var d := {"board": {"items": [broken.to_dict(), ok.to_dict()]}}
	var report := SaveReport.new()
	SaveReconcile.items(d, db, report, [["board"]])
	var a: Dictionary = d["board"]["items"][0]
	var b: Dictionary = d["board"]["items"][1]
	t.eq(String(a["def"]), "crystal_shards", "碎了的换成碎晶")
	t.eq(int(a["rot"]), 0, "朝向 0")
	t.eq(a["origin"], [2, 1], "原点不动")
	t.eq((a["state"] as Dictionary).size(), 0, "状态清空")
	t.eq(String(b["def"]), "fire_crystal", "没碎的不动")
	t.eq(int((b["state"] as Dictionary)[WearProfile.CHARGES_KEY]), 2, "次数照旧")
	t.check(not report.is_empty(), "报告记了一条")
	t.not_null(ItemInstance.from_dict(a, db), "换出来的读得回来")
	db.get_def(&"ice_crystal").wear.broken_into = &""     # 定义是缓存共享的：还原


static func run_text(t: TestCase) -> void:
	t.begin("208 · 文字：悬浮窗耐久行写「用完就碎」（写了 broken_into 的写「用完碎成碎晶」）；246：晶石说明写碎了只能卖钱；导入器拦 broken_into 指向不存在或不是 1 格的")
	var db := _db()
	var fire := _with_charges(db, &"fire_crystal", 2)
	var line := TextTemplate.strip_bbcode(ItemTooltip.wear_line(fire))
	t.check(line.contains("用完就碎"), "耐久行：%s" % line)
	var desc := TextTemplate.strip_bbcode(ItemTooltip.describe(fire, null))
	t.check(desc.contains("只能卖钱") and not desc.contains("{item:"), "说明写碎了只能卖钱")
	var into := (db.get_def(&"fire_crystal").duplicate(true)) as ItemDef
	into.wear.broken_into = &"crystal_shards"
	var into_inst := ItemInstance.create(into)
	into_inst.state[WearProfile.CHARGES_KEY] = 2
	var into_line := TextTemplate.strip_bbcode(ItemTooltip.wear_line(into_inst))
	t.check(into_line.contains("用完碎成") and into_line.contains(Names.of(db.get_def(&"crystal_shards"))), "写了换成什么：%s" % into_line)
	var ctx := ContentImporter.Context.new()
	for id in [&"fire_crystal", &"knife"]:
		ctx.items[id] = db.get_def(id).duplicate(true)
	(ctx.items[&"fire_crystal"] as ItemDef).wear.broken_into = &"crystal_shards"
	var bad := ImportReport.new()
	ContentImporter.validate_wear_targets(ctx, bad)
	t.check(not bad.ok(), "找不到 crystal_shards：报错")
	(ctx.items[&"fire_crystal"] as ItemDef).wear.broken_into = &"knife"
	var big := ImportReport.new()
	ContentImporter.validate_wear_targets(ctx, big)
	t.check(db.get_def(&"knife").cell_count() == 1 or not big.ok(), "不是 1 格：报错")
	ctx.items[&"crystal_shards"] = db.get_def(&"crystal_shards")
	(ctx.items[&"fire_crystal"] as ItemDef).wear.broken_into = &"crystal_shards"
	var good := ImportReport.new()
	ContentImporter.validate_wear_targets(ctx, good)
	t.check(good.ok(), "碎晶：通过")
