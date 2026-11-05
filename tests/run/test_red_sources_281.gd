## 281 §四.4（作者 10:47 改版）：核心 BOSS / 猎手开战前掷红武劣化版持有、打赢了掷掉落
extends RefCounted


static func _run(chapter := "free_mode") -> RunState:
	var c := TestSupport.load_content(chapter, ["buffs"])
	var run := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs)
	run.meta = MetaState.new()
	return run


static func _content() -> Dictionary:
	return {"enemy": "brute", "board": [4, 3], "items": [{"id": "knife", "at": [0, 0], "rot": 0}, {"id": "longsword", "at": [1, 0], "rot": 0}]}


static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	return r


static func run_numbers(t: TestCase) -> void:
	t.begin("281 · 持有 1% × (1 + 进阶级)，上限 5%；掉落 20% + 10% × 进阶级；武器类八种对得上")
	t.check(is_equal_approx(RedSources.hold_chance(0), 0.01), "普通：持有 1%")
	t.check(is_equal_approx(RedSources.hold_chance(3), 0.04), "进阶三：4%")
	t.check(is_equal_approx(RedSources.hold_chance(9), 0.05), "封顶 5%")
	t.check(is_equal_approx(RedSources.drop_chance(0), 0.2), "普通：掉落 20%")
	t.check(is_equal_approx(RedSources.drop_chance(3), 0.5), "进阶三：50%")
	var items := ItemDatabase.new()
	items.load_dir()
	var want := {&"chana": &"dagger", &"duanshui": &"one_hand", &"shuangsheng": &"dual", &"guanri": &"polearm", &"bengshan": &"two_hand",
		&"zhuixing": &"bow", &"poxiao": &"crossbow", &"jimie": &"staff", &"shortbow": &"bow", &"light_crossbow": &"crossbow", &"knife": &"dagger"}
	for id in want:
		t.eq(RedSources.class_of(items.get_def(id)), want[id], "%s 是 %s" % [id, want[id]])
	var lesser := RedSources.lesser_classes(items)
	t.eq(lesser.size(), 8, "劣化版八把")
	for id in lesser:
		var d := items.get_def(id)
		var red := items.get_def(StringName(String(id).trim_suffix("_lesser")))
		t.check(red != null and red.is_unique() and not d.is_unique(), "%s：对应红武，自己不是独一的" % id)
		if red == null:
			continue
		t.eq(d.display_name, red.display_name, "%s：名字同红武" % id)
		t.eq(d.rarity, red.rarity, "%s：同档" % id)
		t.eq(d.cell_count(), red.cell_count(), "%s：同格" % id)
		t.eq(d.combat.base_stats, red.combat.base_stats, "%s：面板同红武" % id)
		t.eq(ItemValue.of(d), ItemValue.BASE_PER_CELL[4] * 2 * d.cell_count(), "%s：价值 = 橙 × 2" % id)
		t.check(not items.ids().has(id) and items.ids(true).has(id), "%s：不进随机池，图鉴照列" % id)
		var inst := ItemInstance.create(d)
		t.check(not Forge.accepts(inst) and not Blessings.eligible(d), "%s：不附魔、不赐福" % id)
		var meta := MetaState.new()
		meta.warehouse.try_add(inst, true)
		t.check(meta.sell_item(inst.uid) > 0, "%s：能卖" % id)
	t.check(RedSources.chapter_ok(load(ContentPaths.asset_file("chapters", "free_mode"))), "自由模式出红武")
	t.check(not RedSources.chapter_ok(load(ContentPaths.asset_file("chapters", "prologue_3"))), "序章不出")


static func run_hold(t: TestCase) -> void:
	t.begin("281 · 持有：掷中就把同类的一件换成劣化版、真的摆在棋盘上；记进内容不再掷；没掷中 / 档不到 3（没有档位时看是不是序章）都不持有；仓库里有也照样持有")
	var run := _run()
	var c := _content()
	t.eq(RedSources.arm(c, run, _rng(), 0.5), &"", "没掷中：不持有")
	t.eq(String(c.get(RedSources.HOLD_KEY, "?")), "", "记下掷过了")
	t.eq(RedSources.arm(c, run, _rng(), 0.0), &"", "掷过了不再掷")

	c = _content()
	var red := RedSources.arm(c, run, _rng(), 0.0)
	t.check(red == &"chana_lesser" or red == &"duanshui_lesser", "掷中：按手里的类配（短兵 / 单手）")
	t.eq(String(c[RedSources.HOLD_KEY]), String(red), "持有记进内容")
	t.check(DropResolver.carried_ids(c).has(red), "劣化版在它身上")
	var board := EnemyKit.board_of(c, run.items, false)
	t.check(board.items().any(func(i: ItemInstance) -> bool: return i.def.id == red), "真的摆在棋盘上")

	c = _content()
	run.meta.warehouse.try_add(ItemInstance.create(run.items.get_def(&"chana")), true)
	run.meta.warehouse.try_add(ItemInstance.create(run.items.get_def(&"duanshui")), true)
	run.meta.warehouse.try_add(ItemInstance.create(run.items.get_def(&"chana_lesser")), true)
	t.check(RedSources.arm(c, run, _rng(), 0.0) != &"", "不互斥：仓库里有红武、劣化版也照样持有")

	var pro := _run("prologue_3")
	c = _content()
	t.eq(RedSources.arm(c, pro, _rng(), 0.0), &"", "序章：不持有")

	t.eq(RedSources.arm(_content_with(2), _run(), _rng(), 0.0), &"", "档 2：不持有")
	t.check(RedSources.arm(_content_with(3), _run(), _rng(), 0.0) != &"", "档 3：持有")
	t.check(RedSources.arm(_content_with(3), pro, _rng(), 0.0) != &"", "有档位就看档位（序章也一样）")


static func _content_with(strength: int) -> Dictionary:
	var c := _content()
	c["strength"] = strength
	return c


static func run_drop(t: TestCase) -> void:
	t.begin("281 · 掉落：常规掉落从不掉劣化版；持有的那把按掉落率掉，掉了进尸体")
	var run := _run()
	var c := _content()
	RedSources.arm(c, run, _rng(), 0.0)
	var red := StringName(String(c[RedSources.HOLD_KEY]))
	var rule: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	var ctx := LootContext.new()
	var ever := false
	for s in 200:
		var r := RandomNumberGenerator.new()
		r.seed = s
		ever = ever or (DropResolver.roll(c, rule, ctx, run.items, r) ["dropped"] as Array).has(red)
	t.check(not ever, "常规掉落 200 次一次都没掉")
	var rolled := {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
	t.check(not RedSources.roll_drop(c, run, _rng(), rolled, 0.99), "没掷中：不掉")
	t.check(RedSources.roll_drop(c, run, _rng(), rolled, 0.0), "掷中：掉")
	var corpse := DropResolver.corpse_of(c, rolled, run.items)
	t.check(corpse.items().any(func(i: ItemInstance) -> bool: return i.def.id == red), "进了尸体")
	t.check(not RedSources.roll_drop(_content(), run, _rng(), rolled, 0.0), "没持有：什么都不掉")
