## 信仰体系（第 8 阶段 8-4，报告 081；作者定）：信仰道具带 faith + faith:<id>；**现实里也能存在的东西（皮甲、短刀……）不归任何信仰**；
## 信仰重构 A（2026-11-19）：玩家显式选择奉哪位神，拾取、挪动、整理都不改信；选的神的信物不在棋盘上 = 联系中断（不自动换神）；
## 别的信仰的道具休眠（不参战、不给邻接、不计套装，占格照占）；无信仰之物随便用；存档带着选择与置入序号；
## 定义走管线、导入器校验标签；敌人只信一个神、至少一件武器。期望从数据推：哪些道具有信仰、各归哪个都读标签。
extends RefCounted

const SAVE := "user://test_faith_run.json"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 找个空位放下（不写死坐标：形状随时会改）。放不下记一条失败、返回 null
static func _put(t: TestCase, b: GridInventory, db: ItemDatabase, id: StringName) -> ItemInstance:
	var inst := TestSupport.put(b, db.get_def(id))
	t.not_null(inst, "放得下 %s" % id)
	return inst


static func run_tags_and_defs(t: TestCase) -> void:
	t.begin("信仰 · 定义走管线（六个，含新教占位）；信仰道具带 faith + 恰好一个 faith:<id>，对象是登记过的；凡物不归信仰；导入器拦错的标签")
	var defs := FaithDef.load_all()
	for id in [&"brute", &"sun", &"skill", &"hunt", &"church"]:
		t.check(defs.has(id), "装回了 %s" % id)
	t.check(not defs.has(&"war"), "战争之神删了（104）")
	t.eq((defs[&"church"] as FaithDef).camp, FaithDef.Camp.CHURCH, "新教的阵营是 CHURCH")
	t.eq((defs[&"brute"] as FaithDef).tag(), &"faith:brute", "标签 = faith:<id>")
	t.eq(FaithTags.id_of_tag(&"faith:skill"), &"skill", "从标签反推 id")
	t.eq(FaithTags.id_of_tag(&"weapon"), &"", "不是信仰标签返回空")
	var db := _db()
	var faithful := 0
	for id in db.ids():
		var d := db.get_def(id)
		var objects := 0
		for tag in d.tags:
			if String(tag).begins_with(FaithTags.PREFIX):
				objects += 1
		if d.has_faith():
			faithful += 1
			t.check(objects == 1 and defs.has(FaithTags.id_of_tag(d.faith_tag())), "%s：恰好一个登记过的 faith:<神>（%s）" % [id, d.faith_tag()])
		else:
			t.eq(objects, 0, "%s 没有 faith 就没有对象标签" % id)
	t.check(faithful >= 3, "第一批里有 %d 件信仰道具（赐福之物、符号）" % faithful)
	t.check((defs[&"skill"] as FaithDef).matches(db.get_def(&"blessed_shield")), "技巧之神赐福的盾归技巧之神")
	t.check((defs[&"hunt"] as FaithDef).matches(db.get_def(&"blessed_longbow")), "狩猎之神赐福的长弓归狩猎之神")
	t.check((defs[&"brute"] as FaithDef).matches(db.get_def(&"charm_brute")), "蛮神的护符归暴力之神")
	# 作者定：现实里也能存在的东西不归任何信仰
	for id in [&"shortsword", &"longsword", &"scimitar", &"longbow", &"shortbow", &"arrows", &"round_shield", &"leather_armor", &"knife", &"cleaver", &"salve", &"ration"]:
		t.check(not db.get_def(id).has_faith(), "%s 是凡物，不归信仰" % id)
	# 导入器
	var ctx := ContentImporter.Context.new()
	for id in defs:
		ctx.register_faith(defs[id])
	var base := {"id": "x", "display_name": "x", "shape": ["1"]}
	var cases := {
		"两个对象": {"tags": ["faith:skill", "faith:brute"]},     # 250：faith 标签删了，faith:<神> 自己就是归属
		"没登记的信仰": {"tags": ["faith:moon"]},
	}
	for name in cases:
		var data := base.duplicate()
		data.merge(cases[name])
		var rep := ImportReport.new()
		ContentImporter.import_item(data, ctx, rep)
		t.check(not rep.ok(), "导入器拦「%s」：%s" % [name, rep.to_text().strip_edges().left(60)])
	var good := base.duplicate()
	good["tags"] = ["faith:skill"]
	var rep_ok := ImportReport.new()
	ContentImporter.import_item(good, ctx, rep_ok)
	t.check(rep_ok.ok(), "合法的过：%s" % rep_ok.to_text())
	var bad_id := ImportReport.new()
	ContentImporter.import_faith({"id": "faith:x", "display_name": "x"}, ctx, bad_id)
	t.check(not bad_id.ok(), "信仰 id 里带前缀：拦")


static func run_activation(t: TestCase) -> void:
	t.begin("信仰重构 A · 显式选择：拾取 / 挪位置 / 挪到地上再挪回 / 顶替 / 挪包都不改信；选了的神信物离开 = 联系中断、不自动换神；回来 = 恢复；凡物不受影响")
	var db := _db()
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	b.select_faith(&"")
	t.eq(FaithState.active_tag(b), &"", "空棋盘：不奉神")
	var shield := _put(t, b, db, &"blessed_shield")     # skill（手写的赐福盾，也是信物）
	var sigil := _put(t, b, db, &"charm_brute")      # brute 信物
	if shield == null or sigil == null:
		return
	t.eq(FaithState.active_id(b), &"", "放了两位神的信物：不自动改信，仍不奉神")
	t.eq(FaithState.anchor_tags(b), [&"faith:brute", &"faith:skill"] as Array[StringName], "可以奉的两位神")
	t.eq(FaithState.dormant_uids(b), [shield.uid, sigil.uid] as Array[int], "不奉神：信仰道具都休眠")
	b.select_faith(&"faith:brute")
	t.eq(FaithState.active_id(b), &"brute", "显式奉蛮神")
	t.eq(FaithState.connection(b, &"faith:brute"), FaithState.OK, "联系正常")
	t.eq(FaithState.dormant_uids(b), [shield.uid] as Array[int], "盾休眠")
	var sword := _put(t, b, db, &"shortsword")
	if sword == null:
		return
	t.check(not FaithState.is_dormant(sword.def, FaithState.active_tag(b)), "凡物不休眠")
	# 另一位神的信物：拾取、挪位置、挪到地上再挪回、顶替都不改信
	var other: ItemInstance = null
	for id in db.ids():
		var d := db.get_def(id)
		if d.is_anchor() and FaithTags.id_of_tag(d.faith_tag()) not in [&"brute", &"skill", &""]:
			other = TestSupport.put(b, d)
			if other != null:
				break
	t.not_null(other, "放下另一位神的信物")
	if other == null:
		return
	t.eq(FaithState.active_id(b), &"brute", "后放的别神信物不抢信仰（不再「最后置入说了算」）")
	var spot := TestSupport.other_spot(b, other)
	t.check(not spot.is_empty() and InventoryService.move(b, other.uid, b, spot["origin"], spot["rotation"]), "挪个位置")
	var stash := ItemStash.new(2, 0)
	t.check(InventoryService.transfer_auto(b, other.uid, stash) and InventoryService.transfer_auto(stash, other.uid, b), "挪到地上再挪回")
	t.eq(FaithState.active_id(b), &"brute", "都不改信")
	# 主信物离开：联系中断，不自动换到另一位神
	t.check(InventoryService.transfer_auto(b, sigil.uid, stash), "蛮神护符挪到地上")
	t.eq(FaithState.selected_tag(b), &"faith:brute", "选择还在")
	t.eq(FaithState.connection(b, &"faith:brute"), FaithState.MISSING, "联系中断：信物不在棋盘上")
	t.eq(FaithState.active_id(b), &"", "有效信仰为空，没有自动换成棋盘上的另一位神")
	t.check(FaithState.is_dormant(other.def, FaithState.active_tag(b)), "另一位神的信物照样休眠")
	t.check(InventoryService.transfer_auto(stash, sigil.uid, b), "护符拿回来")
	t.eq(FaithState.active_id(b), &"brute", "同神信物回到棋盘：联系恢复")
	# 同神两件：留一件就不断
	var sigil2 := _put(t, b, db, &"charm_brute")
	if sigil2 != null:
		b.remove(sigil.uid)
		t.eq(FaithState.active_id(b), &"brute", "同神还有一件：不断联")
	# 旧规则只给迁移：最后置入的是谁
	t.eq(FaithState.legacy_last_placed_tag(b), (sigil2 if sigil2 != null else other).def.faith_tag(), "旧排序只在迁移函数里还算得出来")
	# 全拿走
	for inst in b.items().duplicate():
		b.remove((inst as ItemInstance).uid)
	t.eq(FaithState.active_tag(b), &"", "棋盘空了：联系中断")
	t.eq(FaithState.connection(b, &"faith:brute"), FaithState.MISSING, "选择还在、联系中断")
	# 同容器里挪包
	var bag := ItemInstance.create(db.get_def(&"bag_leather"), 0)     # 2×3
	var b2 := GridInventory.new(Vector2i(8, 6), 1, true)
	b2.select_faith(&"faith:brute")
	t.not_null(TestSupport.put(b2, bag), "放包")
	var c2 := _put(t, b2, db, &"charm_brute")
	if c2 == null:
		return
	var bag_spot := TestSupport.other_spot(b2, bag)
	var payload := b2.detach_bag(bag.uid)
	t.check(not bag_spot.is_empty() and b2.attach_bag(payload, bag_spot["origin"], bag_spot["rotation"]), "整包挪到别处")
	t.eq(FaithState.active_id(b2), &"brute", "同容器里挪包：联系照旧")
	# 组装出来的棋盘（敌人 / 台架）：不看置入先后
	var b3 := GridInventory.new(Vector2i(8, 6), 1, false)
	_put(t, b3, db, &"charm_brute")
	t.eq(FaithState.assembled_tag(b3), &"faith:brute", "组装的棋盘：信物都是蛮神 → 蛮神")
	t.eq(FaithState.board_tag(b3), &"faith:brute", "没记选择的棋盘按组装结果")
	b3.select_faith(&"")
	t.eq(FaithState.board_tag(b3), &"", "记了选择（空）的棋盘按选择：不奉神")


static func run_compile_and_sets(t: TestCase) -> void:
	t.begin("信仰 · 编译战斗单位：有效信仰显式进 CompileInput；休眠的只留通用效果（087）；套装不计休眠的；换神之后另一边活过来")
	var db := _db()
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	var bow := _put(t, b, db, &"blessed_longbow")      # hunt，会打
	if bow == null:
		return
	var sigil := TestSupport.put_apart(b, db.get_def(&"charm_brute"), [bow])     # brute；142：不挨着弓（护符的增益槽给相邻武器 +15%）
	t.not_null(sigil, "护符放在碰不到弓的地方")
	if sigil == null:
		return
	var inp := CompileInput.of(null, [] as Array[StatModifier], [] as Array[AbilityRule], {&"faith:hunt": 2})
	inp.faith = &"faith:brute"
	var spec := BattleCompiler.compile(b, inp)
	t.eq(spec.faith, &"faith:brute", "编译结果记着这一场的信仰快照")
	var uids: Array = []
	for item in spec.items:
		uids.append((item as CompiledItem).source_uid)
	t.check(uids.has(sigil.uid) and uids.has(bow.uid), "有效信仰（蛮神）的护符与休眠的长弓都在（长弓留着通用效果：%s）" % str(uids))
	var bow_item := spec.item_of(bow.uid)
	t.check(bow_item != null and spec.rough_dps() > 0.0, "长弓休眠仍出手：武器本身的攻击力是通用效果")
	if bow_item != null:
		t.check(is_equal_approx(StatMath.to_float(bow_item.stats.total_of(BattleStats.DAMAGE)), float(bow.def.combat.base_stats["damage"])), "但信力加成（+4、+15%）没给")
	# 换神：编译器只认输入的信仰（狩猎之神；长弓是赐福版，可这里只测编译器怎么读输入）
	var inp2 := CompileInput.of(null, [] as Array[StatModifier], [] as Array[AbilityRule], {&"faith:hunt": 2})
	inp2.faith = &"faith:hunt"
	var spec2 := BattleCompiler.compile(b, inp2)
	t.eq(spec2.items.size(), 1, "输入是狩猎之神：只剩长弓参战（符号没有 combat，休眠就彻底失效）")
	t.eq((spec2.items[0] as CompiledItem).source_uid, bow.uid, "是长弓")
	t.check(spec2.rough_dps() > spec.rough_dps(), "长弓活了：吃到信力加成，输出比休眠时高")
	var none := BattleCompiler.compile(b, CompileInput.new())
	t.eq(none.items.size(), 1, "不奉神：护符不参战，长弓只留通用效果")
	# 凡物照常参战
	_put(t, b, db, &"shortsword")
	var spec3 := BattleCompiler.compile_board(b)
	t.eq(spec3.items.size(), 3, "凡物短剑也参战（台架入口按组装结果：标签最小的蛮神 —— 护符、休眠但留通用效果的长弓、短剑）")
	# 套装：休眠的不计数（按棋盘上记着的选择）
	b.select_faith(&"faith:brute")
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
	t.begin("信仰 · 一局里：新局默认不奉神、显式奉神、HUD 一句、存档往返选择与序号都在；旧档按旧规则推一次；敌人的组装：只信一个神、至少一件武器")
	var db := _db()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var faiths := FaithDef.load_all()
	var s := RunState.start(chapter, 5, db, enemies, sets, [&"bag_leather", &"bag_leather", &"blessed_shield", &"charm_brute", &"salve"] as Array[StringName])
	t.not_null(s, "开得起来")
	if s == null:
		return
	s.faith_defs = faiths
	s.pick_spawn(s.map.entry_ids[0])
	t.eq(s.active_faith_id(), &"", "新局默认不奉神（带着护符也不偷选）")
	t.eq(s.faith_line(), "信仰：以人为本", "HUD 的那一句：以人为本（372）")
	t.eq(s.select_faith(&"hunt"), UiText.t("act.faith_no_anchor"), "棋盘上没有狩猎之神的信物：奉不了")
	t.eq(s.select_faith(&"brute"), "", "显式奉蛮神")
	t.eq(s.active_faith_id(), &"brute", "有效信仰：蛮神")
	t.eq(s.faith_line(), "信仰：蛮神", "HUD 的那一句")
	var ctx := s.faith_context()
	t.check(ctx.selected == &"brute" and ctx.effective == &"brute" and ctx.connection == FaithState.OK and not ctx.is_broken(), "快照：选的 = 有效 = 蛮神")
	var seqs := {}
	for inst in s.board.items():
		seqs[(inst as ItemInstance).uid] = (inst as ItemInstance).placed_seq
	RunSave.remove(SAVE)
	t.eq(RunSave.write(s, SAVE), OK, "存")
	var back := RunSave.read(db, enemies, sets, SAVE)
	back.faith_defs = faiths
	t.eq(back.active_faith_id(), &"brute", "读回来有效的还是蛮神（存的是选择）")
	t.eq(back.selected_faith, &"brute", "选择原样")
	for inst in back.board.items():
		t.eq((inst as ItemInstance).placed_seq, int(seqs.get((inst as ItemInstance).uid, -1)), "uid %d 的置入序号原样" % (inst as ItemInstance).uid)
	t.eq(back.board.place_seq, s.board.place_seq, "计数原样")
	# 旧档（v4，没有 faith_selection）：棋盘恢复后按旧规则（最后置入的有效信物）推一次
	var old := s.to_dict()
	old["version"] = 4
	old.erase("faith_selection")
	var migrated := RunSave.from_text(JSON.stringify(old), db, enemies, sets)
	t.not_null(migrated, "v4 的档读得回来")
	if migrated != null:
		t.eq(migrated.selected_faith, &"brute", "旧档：按旧规则推出蛮神（护符是棋盘上唯一的信物）")
		var again := RunSave.from_text(JSON.stringify(migrated.to_dict()), db, enemies, sets)
		t.eq(again.selected_faith if again != null else &"?", &"brute", "重复读写结果一样")
	# 不奉神也往返
	t.eq(s.select_faith(&""), "", "不奉神")
	t.eq(s.active_faith_id(), &"", "有效信仰为空")
	var plain := RunSave.from_text(JSON.stringify(s.to_dict()), db, enemies, sets)
	t.eq(plain.selected_faith if plain != null else &"?", &"", "存的是「不奉神」，读回来不按旧规则猜")
	RunSave.remove(SAVE)
	var empty := RunState.start(chapter, 5, db, enemies, sets, [&"bag_leather", &"shortsword", &"salve"] as Array[StringName])
	if empty != null:
		t.eq(empty.faith_line(), "信仰：以人为本", "只带凡物：以人为本")

	# 敌人：组装出来的每个敌人至多一个信仰、至少一件武器（EnemyLoadout 的两条数据）
	var pool := enemies.pool(chapter.enemy_pool)
	var rule: EnemyLoadout = pool.loadout
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var checked := 0
	for eid in TestSupport.enemy_ids():
		var def := enemies.enemy(eid)
		for round_ in 6:
			var picks := EnemyPlacer.choose_items(def, rule, db, 6, rng, -1)
			var faith := &""
			var weapons := 0
			var ok := true
			for id in picks:
				var d := db.get_def(id)
				if d.tags.has(rule.weapon_tag):
					weapons += 1
				if d.has_faith():
					if faith == &"":
						faith = d.faith_tag()
					elif d.faith_tag() != faith:
						ok = false
			checked += 1
			t.check(ok, "%s 第 %d 次：只信一个神（%s）" % [eid, round_, str(picks)])
			var need := (def.loadout if def.loadout != null else rule).min_weapons     # 212：魔兽自己的组装规则不要武器
			t.check(weapons >= need, "%s 第 %d 次：至少 %d 件武器（%s）" % [eid, round_, need, str(picks)])
	t.check(checked > 0, "检查了 %d 次组装" % checked)
	var pool_items := EnemyPlacer.school_items([&"faith:brute"] as Array[StringName], db, -1)
	for id in pool_items:
		t.eq(db.get_def(id).faith_tag(), &"faith:brute", "%s 归暴力之神" % id)
