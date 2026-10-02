## 信仰体系（第 8 阶段 8-4，报告 081；作者定）：信仰道具带 faith + faith:<id>；**现实里也能存在的东西（皮甲、短刀……）不归任何信仰**；
## 任何时刻只激活最后置入棋盘的信仰道具所属的信仰；别的信仰的道具休眠（不参战、不给邻接、不计套装，占格照占）；无信仰之物随便用；
## 一件信仰道具都没有 = 没激活（不信者）；挪到暂存区再挪回 = 切换；同容器内挪位置、原样放回、同容器里挪包都不算重新置入；存档带着置入序号；
## 定义走管线、导入器校验标签；敌人只信一个神、至少一件武器。期望从数据推：哪些道具有信仰、各归哪个都读标签。
extends RefCounted

const SAVE := "user://test_faith_run.json"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _put(b: GridInventory, db: ItemDatabase, id: StringName, at: Vector2i) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id), 0)
	assert(b.place(inst, at, 0), "放不下 %s" % id)
	return inst


static func run_tags_and_defs(t: TestCase) -> void:
	t.begin("信仰 · 定义走管线（六个，含新教占位）；信仰道具带 faith + 恰好一个 faith:<id>，对象是登记过的；凡物不归信仰；导入器拦错的标签")
	var defs := FaithDef.load_all()
	for id in [&"brute", &"sun", &"skill", &"hunt", &"church"]:
		t.check(defs.has(id), "装回了 %s" % id)
	t.check(not defs.has(&"war"), "战争之神删了（104）")
	t.eq((defs[&"church"] as FaithDef).camp, FaithDef.Camp.CHURCH, "新教的阵营是 CHURCH")
	t.eq((defs[&"brute"] as FaithDef).tag(), &"faith:brute", "标签 = faith:<id>")
	t.eq(FaithDef.id_of_tag(&"faith:skill"), &"skill", "从标签反推 id")
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
	t.check(faithful >= 3, "第一批里有 %d 件信仰道具（赐福之物、符号）" % faithful)
	t.check((defs[&"skill"] as FaithDef).matches(db.get_def(&"blessed_shield")), "技巧之神赐福的盾归技巧之神")
	t.check((defs[&"hunt"] as FaithDef).matches(db.get_def(&"blessed_longbow")), "狩猎之神赐福的长弓归狩猎之神")
	t.check((defs[&"brute"] as FaithDef).matches(db.get_def(&"strength_sigil")), "力量的符号归暴力之神")
	# 作者定：现实里也能存在的东西不归任何信仰
	for id in [&"shortsword", &"longsword", &"scimitar", &"longbow", &"shortbow", &"arrows", &"round_shield", &"leather_armor", &"gambeson", &"knife", &"cleaver", &"salve", &"ration"]:
		t.check(not db.get_def(id).has_faith(), "%s 是凡物，不归信仰" % id)
	# 导入器
	var ctx := ContentImporter.Context.new()
	for id in defs:
		ctx.register_faith(defs[id])
	var base := {"id": "x", "display_name": "x", "shape": ["1"]}
	var cases := {
		"faith 没对象": {"tags": ["faith"]},
		"对象没 faith": {"tags": ["faith:skill"]},
		"两个对象": {"tags": ["faith", "faith:skill", "faith:brute"]},
		"没登记的信仰": {"tags": ["faith", "faith:moon"]},
	}
	for name in cases:
		var data := base.duplicate()
		data.merge(cases[name])
		var rep := ImportReport.new()
		ContentImporter.import_item(data, ctx, rep)
		t.check(not rep.ok(), "导入器拦「%s」：%s" % [name, rep.to_text().strip_edges().left(60)])
	var good := base.duplicate()
	good["tags"] = ["faith", "faith:skill"]
	var rep_ok := ImportReport.new()
	ContentImporter.import_item(good, ctx, rep_ok)
	t.check(rep_ok.ok(), "合法的过：%s" % rep_ok.to_text())
	var bad_id := ImportReport.new()
	ContentImporter.import_faith({"id": "faith:x", "display_name": "x"}, ctx, bad_id)
	t.check(not bad_id.ok(), "信仰 id 里带前缀：拦")


static func run_activation(t: TestCase) -> void:
	t.begin("信仰 · 最后置入的信仰道具决定激活；挪到暂存区再挪回 = 切换；同容器挪位置 / 原样放回 / 挪包不算；没有信仰道具 = 无；凡物不受影响")
	var db := _db()
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	t.eq(FaithState.active_tag(b), &"", "空棋盘：没激活")
	var shield := _put(b, db, &"blessed_shield", Vector2i(0, 0))     # skill，2×2
	t.eq(FaithState.active_id(b), &"skill", "放了技巧之神的盾：技巧之神")
	var sigil := _put(b, db, &"strength_sigil", Vector2i(3, 0))      # violence，1×1
	t.eq(FaithState.active_id(b), &"brute", "再放力量的符号：最后置入的是它 → 暴力之神")
	t.check(shield.placed_seq < sigil.placed_seq, "置入序号递增")
	t.eq(FaithState.dormant_uids(b), [shield.uid] as Array[int], "盾休眠")
	var sword := _put(b, db, &"shortsword", Vector2i(5, 0))
	t.eq(FaithState.active_id(b), &"brute", "凡物（短剑）不改变激活")
	t.check(not FaithState.is_dormant(sword.def, FaithState.active_tag(b)), "凡物不休眠")
	# 同容器挪位置：不算重新置入
	t.check(InventoryService.move_within(b, shield.uid, Vector2i(0, 3), 0), "把盾挪个位置")
	t.eq(FaithState.active_id(b), &"brute", "同容器挪位置不换信仰")
	# 挪到暂存区再挪回：切换
	var stash := ItemStash.new(2, 0)
	t.check(InventoryService.transfer_auto(b, shield.uid, stash), "盾挪到暂存区")
	t.eq(FaithState.active_id(b), &"brute", "还是暴力之神")
	t.check(InventoryService.transfer_auto(stash, shield.uid, b), "再挪回棋盘")
	t.eq(FaithState.active_id(b), &"skill", "切换成技巧之神：盾成了最后置入的")
	t.eq(FaithState.dormant_uids(b), [sigil.uid] as Array[int], "符号休眠")
	# 顶替式放置：顶进来的算最后置入
	var bow := ItemInstance.create(db.get_def(&"blessed_longbow"), 0)     # hunt，1×4
	var victims = b.place_displacing(bow, Vector2i(3, 0), 0)
	t.check(victims != null, "赐福的长弓顶进来（狩猎之神）")
	t.eq(FaithState.active_id(b), &"hunt", "顶进来的长弓是最后置入的")
	# 全拿走：无
	for inst in b.items().duplicate():
		b.remove((inst as ItemInstance).uid)
	t.eq(FaithState.active_tag(b), &"", "棋盘空了：没激活（不信者）")
	# 同容器里挪包：包和内容物都不算
	var bag := ItemInstance.create(db.get_def(&"bag_leather"), 0)     # 2×3
	var b2 := GridInventory.new(Vector2i(8, 6), 1, true)
	t.check(b2.place(bag, Vector2i(0, 0), 0), "放包")
	var s2 := _put(b2, db, &"blessed_shield", Vector2i(0, 0))
	var c2 := _put(b2, db, &"strength_sigil", Vector2i(0, 2))
	t.eq(FaithState.active_id(b2), &"brute", "符号后放")
	var payload := b2.detach_bag(bag.uid)
	t.check(not payload.is_empty() and int(payload["from"]) == b2.id, "摘下包，载荷记着来自哪个容器")
	t.check(b2.attach_bag(payload, Vector2i(3, 0), 0), "整包挪到别处")
	t.eq(FaithState.active_id(b2), &"brute", "同容器里挪包：置入顺序不变")
	t.check(s2.placed_seq < c2.placed_seq, "序号也没变")


static func run_compile_and_sets(t: TestCase) -> void:
	t.begin("信仰 · 编译战斗单位：休眠的只留通用效果（087：长弓本身的攻击力照在、信力加成与邻接不给）；套装不计休眠的；切换之后另一边活过来")
	var db := _db()
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	var bow := _put(b, db, &"blessed_longbow", Vector2i(0, 0))      # hunt，会打
	var sigil := _put(b, db, &"strength_sigil", Vector2i(2, 0))     # violence
	var spec := BattleCompiler.compile(b, null, [] as Array[StatModifier], [] as Array[AbilityRule], {&"faith:hunt": 2})
	var uids: Array = []
	for item in spec.items:
		uids.append((item as CompiledItem).source_uid)
	t.check(uids.has(sigil.uid) and uids.has(bow.uid), "激活信仰（暴力之神）的符号与休眠的长弓都在（长弓留着通用效果：%s）" % str(uids))
	var bow_item := spec.item_of(bow.uid)
	t.check(bow_item != null and spec.rough_dps() > 0.0, "长弓休眠仍出手：武器本身的攻击力是通用效果")
	if bow_item != null:
		t.check(is_equal_approx(StatMath.to_float(bow_item.stats.total_of(BattleStats.DAMAGE)), float(bow.def.combat.base_stats["damage"])), "但信力加成（+4、+15%）没给")
	# 切换：长弓挪出再挪回 → 狩猎之神，符号休眠
	var stash := ItemStash.new(2, 0)
	InventoryService.transfer_auto(b, bow.uid, stash)
	InventoryService.transfer_auto(stash, bow.uid, b)
	var spec2 := BattleCompiler.compile(b, null, [] as Array[StatModifier], [] as Array[AbilityRule], {&"faith:hunt": 2})
	t.eq(spec2.items.size(), 1, "切成狩猎之神：只剩长弓参战（符号没有 combat，休眠就彻底失效）")
	t.eq((spec2.items[0] as CompiledItem).source_uid, bow.uid, "是长弓")
	t.check(spec2.rough_dps() > spec.rough_dps(), "长弓活了：吃到信力加成，输出比休眠时高")
	# 凡物照常参战
	var sword := _put(b, db, &"shortsword", Vector2i(4, 0))
	var spec3 := BattleCompiler.compile(b)
	t.eq(spec3.items.size(), 2, "凡物短剑也参战")
	# 套装：休眠的不计数
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
	t.begin("信仰 · 一局里：开局按带进去的顺序定信仰、HUD 一句、存档往返序号与激活都在；敌人的组装：只信一个神、至少一件武器")
	var db := _db()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "chapter_01"))
	var faiths := FaithDef.load_all()
	var s := RunState.start(chapter, 5, db, enemies, sets, [&"bag_leather", &"bag_leather", &"blessed_shield", &"strength_sigil", &"salve"] as Array[StringName])
	t.not_null(s, "开得起来")
	if s == null:
		return
	s.faith_defs = faiths
	t.eq(s.active_faith_id(), &"brute", "开局清单里符号在盾之后：暴力之神")
	t.eq(s.faith_line(), "信仰：蛮神", "HUD 的那一句")
	var seqs := {}
	for inst in s.board.items():
		seqs[(inst as ItemInstance).uid] = (inst as ItemInstance).placed_seq
	RunSave.remove(SAVE)
	t.eq(RunSave.write(s, SAVE), OK, "存")
	var back := RunSave.read(db, enemies, sets, SAVE)
	back.faith_defs = faiths
	t.eq(back.active_faith_id(), &"brute", "读回来激活的还是暴力之神")
	for inst in back.board.items():
		t.eq((inst as ItemInstance).placed_seq, int(seqs.get((inst as ItemInstance).uid, -1)), "uid %d 的置入序号原样" % (inst as ItemInstance).uid)
	t.eq(back.board.place_seq, s.board.place_seq, "计数原样")
	RunSave.remove(SAVE)
	var empty := RunState.start(chapter, 5, db, enemies, sets, [&"bag_leather", &"shortsword", &"salve"] as Array[StringName])
	if empty != null:
		t.eq(empty.faith_line(), "信仰：无", "只带凡物：无")

	# 敌人：组装出来的每个敌人至多一个信仰、至少一件武器（EnemyLoadout 的两条数据）
	var pool := enemies.pool(chapter.enemy_pool)
	var rule: EnemyLoadout = pool.loadout
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var checked := 0
	for eid in enemies.enemy_ids():
		var def := enemies.enemy(eid)
		for round in 6:
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
			t.check(ok, "%s 第 %d 次：只信一个神（%s）" % [eid, round, str(picks)])
			t.check(weapons >= rule.min_weapons, "%s 第 %d 次：至少 %d 件武器（%s）" % [eid, round, rule.min_weapons, str(picks)])
	t.check(checked > 0, "检查了 %d 次组装" % checked)
	var pool_items := EnemyPlacer.school_items([&"faith:brute"] as Array[StringName], db, -1)
	for id in pool_items:
		t.eq(db.get_def(id).faith_tag(), &"faith:brute", "%s 归暴力之神" % id)
