## 信仰体系（第 8 阶段 8-4，报告 081；作者定）：信仰道具带 faith + faith:<id>；任何时刻只激活最后置入棋盘的信仰道具所属的信仰；
## 别的信仰的道具休眠（不参战、不给邻接、不计套装，占格照占）；无信仰之物随便用；一件信仰道具都没有 = 没激活（不信者）；
## 挪到暂存区再挪回 = 切换；同容器内挪位置、原样放回、同容器里挪包都不算重新置入；存档带着置入序号；
## 定义走管线、导入器校验标签；敌人按信仰组装备。期望从数据推：哪些道具有信仰、各归哪个都读标签。
extends RefCounted

const SAVE := "user://test_faith_run.json"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _board(db: ItemDatabase) -> GridInventory:
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	return b


static func _put(b: GridInventory, db: ItemDatabase, id: StringName, at: Vector2i) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id), 0)
	assert(b.place(inst, at, 0), "放不下 %s" % id)
	return inst


static func run_tags_and_defs(t: TestCase) -> void:
	t.begin("信仰 · 定义走管线（六个，含新教占位）；信仰道具带 faith + 恰好一个 faith:<id>，对象是登记过的；导入器拦错的标签")
	var defs := FaithDef.load_all()
	for id in [&"violence", &"war", &"sunfire", &"skill", &"hunt", &"church"]:
		t.check(defs.has(id), "装回了 %s" % id)
	t.eq((defs[&"church"] as FaithDef).camp, FaithDef.Camp.CHURCH, "新教的阵营是 CHURCH")
	t.eq((defs[&"violence"] as FaithDef).tag(), &"faith:violence", "标签 = faith:<id>")
	t.eq(FaithDef.id_of_tag(&"faith:war"), &"war", "从标签反推 id")
	t.eq(FaithDef.id_of_tag(&"weapon"), &"", "不是信仰标签返回空")
	var db := _db()
	var faithful := 0
	for id in db.ids():
		var d := db.get_def(id)
		var objects := 0
		for tag in d.tags:
			if String(tag).begins_with(FaithDef.TAG_PREFIX):
				objects += 1
		if d.has_faith():
			faithful += 1
			t.check(objects == 1 and defs.has(FaithDef.id_of_tag(d.faith_tag())), "%s：faith + 一个登记过的对象标签（%s）" % [id, d.faith_tag()])
		else:
			t.eq(objects, 0, "%s 没有 faith 就没有对象标签" % id)
	t.check(faithful >= 8, "第一批里有 %d 件信仰道具" % faithful)
	t.check((defs[&"war"] as FaithDef).matches(db.get_def(&"shortsword")), "制式短剑归战争之神")
	t.check((defs[&"violence"] as FaithDef).matches(db.get_def(&"scimitar")), "弯刀归暴力之神")
	t.check(not db.get_def(&"salve").has_faith() and not db.get_def(&"knife").has_faith(), "伤药、匕首是无信仰之物")
	# 导入器
	var ctx := ContentImporter.Context.new()
	for id in defs:
		ctx.register_faith(defs[id])
	var base := {"id": "x", "display_name": "x", "shape": ["1"]}
	var cases := {
		"faith 没对象": {"tags": ["faith"]},
		"对象没 faith": {"tags": ["faith:war"]},
		"两个对象": {"tags": ["faith", "faith:war", "faith:violence"]},
		"没登记的信仰": {"tags": ["faith", "faith:moon"]},
	}
	for name in cases:
		var data := base.duplicate()
		data.merge(cases[name])
		var rep := ImportReport.new()
		ContentImporter.import_item(data, ctx, rep)
		t.check(not rep.ok(), "导入器拦「%s」：%s" % [name, rep.to_text().strip_edges().left(60)])
	var good := base.duplicate()
	good["tags"] = ["faith", "faith:war"]
	var rep_ok := ImportReport.new()
	ContentImporter.import_item(good, ctx, rep_ok)
	t.check(rep_ok.ok(), "合法的过：%s" % rep_ok.to_text())
	var bad_id := ImportReport.new()
	ContentImporter.import_faith({"id": "faith:x", "display_name": "x"}, ctx, bad_id)
	t.check(not bad_id.ok(), "信仰 id 里带前缀：拦")


static func run_activation(t: TestCase) -> void:
	t.begin("信仰 · 最后置入的信仰道具决定激活；挪到暂存区再挪回 = 切换；同容器挪位置 / 原样放回 / 挪包不算；没有信仰道具 = 无；无信仰之物不受影响")
	var db := _db()
	var b := _board(db)
	t.eq(FaithState.active_tag(b), &"", "空棋盘：没激活")
	var sword := _put(b, db, &"shortsword", Vector2i(0, 0))     # war
	t.eq(FaithState.active_id(b), &"war", "放了制式短剑：战争之神")
	var scim := _put(b, db, &"scimitar", Vector2i(2, 0))        # violence
	t.eq(FaithState.active_id(b), &"violence", "再放弯刀：最后置入的是它 → 暴力之神")
	t.check(sword.placed_seq < scim.placed_seq, "置入序号递增")
	t.eq(FaithState.dormant_uids(b), [sword.uid] as Array[int], "短剑休眠")
	var salve := _put(b, db, &"salve", Vector2i(4, 0))
	t.eq(FaithState.active_id(b), &"violence", "无信仰之物不改变激活")
	t.check(not FaithState.is_dormant(salve.def, FaithState.active_tag(b)), "无信仰之物不休眠")
	# 同容器挪位置：不算重新置入
	t.check(InventoryService.move_within(b, sword.uid, Vector2i(6, 0), 0), "把短剑挪个位置")
	t.eq(FaithState.active_id(b), &"violence", "同容器挪位置不换信仰")
	# 挪到暂存区再挪回：切换
	var stash := ItemStash.new(2, 0)
	t.check(InventoryService.transfer_auto(b, sword.uid, stash), "短剑挪到暂存区")
	t.eq(FaithState.active_id(b), &"violence", "还是暴力之神")
	t.check(InventoryService.transfer_auto(stash, sword.uid, b), "再挪回棋盘")
	t.eq(FaithState.active_id(b), &"war", "切换成战争之神：短剑成了最后置入的")
	t.eq(FaithState.dormant_uids(b), [scim.uid] as Array[int], "弯刀休眠")
	# 顶替式放置：被顶出去再放回的不算
	var victims = b.place_displacing(ItemInstance.create(db.get_def(&"leather_armor"), 0), Vector2i(0, 0), 0)
	t.check(victims != null, "皮甲顶进来（暴力之神）")
	t.eq(FaithState.active_id(b), &"violence", "顶进来的皮甲是最后置入的")
	# 全拿走：无
	for inst in b.items().duplicate():
		b.remove((inst as ItemInstance).uid)
	t.eq(FaithState.active_tag(b), &"", "棋盘空了：没激活（不信者）")
	# 同容器里挪包：包和内容物都不算
	var bag := ItemInstance.create(db.get_def(&"bag_leather"), 0)
	var b2 := GridInventory.new(Vector2i(8, 6), 1, true)
	t.check(b2.place(bag, Vector2i(0, 0), 0), "放包")
	var s2 := _put(b2, db, &"shortsword", Vector2i(0, 0))
	var c2 := _put(b2, db, &"scimitar", Vector2i(1, 0))
	t.eq(FaithState.active_id(b2), &"violence", "弯刀后放")
	var payload := b2.detach_bag(bag.uid)
	t.check(not payload.is_empty() and int(payload["from"]) == b2.id, "摘下包，载荷记着来自哪个容器")
	t.check(b2.attach_bag(payload, Vector2i(3, 0), 0), "整包挪到别处")
	t.eq(FaithState.active_id(b2), &"violence", "同容器里挪包：置入顺序不变")
	t.check(s2.placed_seq < c2.placed_seq, "序号也没变")


static func run_compile_and_sets(t: TestCase) -> void:
	t.begin("信仰 · 编译战斗单位跳过休眠的（不参战、不给邻接）；套装不计休眠的；切换之后另一边活过来")
	var db := _db()
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	var sword := _put(b, db, &"shortsword", Vector2i(0, 0))
	var scim := _put(b, db, &"scimitar", Vector2i(2, 0))
	var spec := BattleCompiler.compile(b)
	var uids: Array = []
	for item in spec.items:
		uids.append((item as CompiledItem).source_uid)
	t.check(uids.has(scim.uid) and not uids.has(sword.uid), "只编译了激活信仰的弯刀（%s）" % str(uids))
	# 邻接：力量的符号（暴力之神）贴着短剑（战争之神，休眠）不给增益；贴着弯刀给
	var sigil := _put(b, db, &"strength_sigil", Vector2i(2, 3))     # 弯刀 1x3 占 (2,0)(2,1)(2,2)，符号在 (2,3) 正下方
	var spec2 := BattleCompiler.compile(b)
	var scim_item: CompiledItem = null
	for item in spec2.items:
		if (item as CompiledItem).source_uid == scim.uid:
			scim_item = item
	t.not_null(scim_item, "弯刀在")
	t.check(FaithState.active_id(b) == &"violence" and spec2.items.size() == 2, "符号（暴力之神）也参战，短剑还休眠")
	# 切换：短剑挪出再挪回 → 战争之神，弯刀与符号休眠
	var stash := ItemStash.new(2, 0)
	InventoryService.transfer_auto(b, sword.uid, stash)
	InventoryService.transfer_auto(stash, sword.uid, b)
	var spec3 := BattleCompiler.compile(b)
	t.eq(spec3.items.size(), 1, "切成战争之神：只剩短剑参战")
	t.eq((spec3.items[0] as CompiledItem).source_uid, sword.uid, "是短剑")
	# 套装：用一个假套装数据库验证休眠的不计数
	var sets := SetDatabase.new()
	sets.load_dir()
	var tracker := SetTracker.create(sets)
	tracker.bind(b)
	var counted := 0
	for sid in tracker.tracked_ids():
		counted += tracker.count_of(sid)
	var expected := 0
	var active := FaithState.active_tag(b)
	for inst in b.items():
		var d := (inst as ItemInstance).def
		if d.set_id != &"" and not FaithState.is_dormant(d, active):
			expected += 1
	t.eq(counted, expected, "套装只数没休眠的（%d）" % expected)


static func run_run_and_save(t: TestCase) -> void:
	t.begin("信仰 · 一局里：开局按带进去的顺序定信仰、HUD 一句、存档往返序号与激活都在；敌人按信仰组装备（招牌与流派池）")
	var db := _db()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "chapter_01"))
	var faiths := FaithDef.load_all()
	var s := RunState.start(chapter, 5, db, enemies, sets, [&"bag_leather", &"bag_leather", &"shortsword", &"scimitar", &"salve"] as Array[StringName])
	t.not_null(s, "开得起来")
	if s == null:
		return
	s.faith_defs = faiths
	t.eq(s.active_faith_id(), &"violence", "开局清单里弯刀在短剑之后：暴力之神")
	t.eq(s.faith_line(), "信仰：暴力之神", "HUD 的那一句")
	t.check(s.compile_player().items.size() >= 1, "编译得出来")
	var seqs := {}
	for inst in s.board.items():
		seqs[(inst as ItemInstance).uid] = (inst as ItemInstance).placed_seq
	RunSave.remove(SAVE)
	t.eq(RunSave.write(s, SAVE), OK, "存")
	var back := RunSave.read(db, enemies, sets, SAVE)
	back.faith_defs = faiths
	t.eq(back.active_faith_id(), &"violence", "读回来激活的还是暴力之神")
	for inst in back.board.items():
		t.eq((inst as ItemInstance).placed_seq, int(seqs.get((inst as ItemInstance).uid, -1)), "uid %d 的置入序号原样" % (inst as ItemInstance).uid)
	t.eq(back.board.place_seq, s.board.place_seq, "计数原样")
	RunSave.remove(SAVE)
	var empty := RunState.start(chapter, 5, db, enemies, sets, [&"bag_leather", &"salve"] as Array[StringName])
	if empty != null:
		t.eq(empty.faith_line(), "信仰：无", "没带信仰道具：无")

	# 敌人：蛮兵的装备偏好是 faith:violence → 流派池里只有暴力之神的东西
	var pool_items := EnemyPlacer.school_items([&"faith:violence"] as Array[StringName], db, -1)
	t.check(not pool_items.is_empty(), "暴力之神的道具池非空（%d）" % pool_items.size())
	for id in pool_items:
		t.eq(db.get_def(id).faith_tag(), &"faith:violence", "%s 归暴力之神" % id)
	var brute := enemies.enemy(&"brute")
	t.check(brute != null and brute.schools.has(&"faith:violence"), "蛮兵按暴力之神组装备")
