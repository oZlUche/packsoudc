## 246（含补充一、二）：魔晶石按剩余次数起名（作者的十级词表，一档一次、满九次，次数和品质不挂钩）；变体图按张数折算；
## 三品（晶石 / 魔晶石 / 魔晶核 = 蓝 / 紫 / 金）；果果之心 = 永不消耗的中品；掉落换品、抽次数、不出碎裂；碎了留在原格、低两档、只能卖
extends RefCounted

const C148 := preload("res://tests/run/test_crystal_148.gd")
const Economy := preload("res://tests/run/test_economy.gd")

const ELEMS := [&"fire", &"ice", &"lightning"]
const ALL_WORN := [&"fire_crystal_low", &"fire_crystal", &"fire_crystal_high", &"ice_crystal_low", &"ice_crystal", &"ice_crystal_high",
	&"lightning_crystal_low", &"lightning_crystal", &"lightning_crystal_high", &"quartz_cluster", &"raw_amber"]


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _with(db: ItemDatabase, id: StringName, left: int) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id))
	inst.state[WearProfile.CHARGES_KEY] = left
	return inst


static func run_names(t: TestCase) -> void:
	t.begin("246 §一 / §二：十级词表（中英）、一档一次满九次；charge_band 3 时三次一档")
	var db := _db()
	var w := db.get_def(&"fire_crystal").wear
	t.eq(w.max_charges, 9, "满九次")
	var zh: Array[String] = []
	var en: Array[String] = []
	for n in [0, 1, 5, 9]:
		zh.append(w.prefix_for(n, "zh"))
		en.append(w.prefix_for(n, "en"))
	t.eq(zh, ["破碎的", "熄灭的", "显眼的", "完美的"] as Array[String], "中文 0 / 1 / 5 / 9")
	t.eq(en, ["Shattered ", "Extinguished ", "Vivid ", "Flawless "] as Array[String], "英文自带空格")
	var all_zh: Array[String] = []
	for n in range(0, 10):
		all_zh.append(w.prefix_for(n, "zh"))
	t.eq(all_zh, ["破碎的", "熄灭的", "黯淡的", "闪烁的", "微光的", "显眼的", "明亮的", "光耀的", "夺目的", "完美的"] as Array[String], "十级全对")
	t.eq(Names.of_item(_with(db, &"ice_crystal_high", 7), "zh"), "光耀的冰霜魔晶核", "名字只多一个形容词")
	var band := w.duplicate(true) as WearProfile
	band.charge_band = 3
	band.max_charges = 27
	t.check(band.prefix_for(1, "zh") == band.prefix_for(3, "zh") and band.prefix_for(1, "zh") == "熄灭的", "三次一档：1～3 同词")
	t.eq(band.prefix_for(4, "zh"), "黯淡的", "第 4 次换词")
	t.eq(band.prefix_for(27, "zh"), "完美的", "满 27：完美的")
	var maxes := {}
	for id in ALL_WORN:
		maxes[db.get_def(id).wear.max_charges] = true
	t.eq(maxes.keys(), [9], "十一件魔晶石次数都一样（和品质不挂钩）")
	for c in "熄黯耀夺":
		t.check(FileAccess.get_file_as_string("res://assets/fonts/charset.txt").contains(c), "字集有「%s」" % c)


static func run_art(t: TestCase) -> void:
	t.begin("246 §三：变体图按张数折算 —— 满的本图、碎了 c0、其余均分到 c1～c3；张数改了跟着折")
	var w := _db().get_def(&"fire_crystal").wear
	t.eq(w.art_levels, 4, "默认四张")
	var got: Array[int] = []
	for n in range(0, 10):
		got.append(w.art_variant(n))
	t.eq(got, [0, 1, 1, 1, 2, 2, 2, 3, 3, -1] as Array[int], "0～9 → c0 / c1×3 / c2×3 / c3×2 / 本图")
	var more := w.duplicate(true) as WearProfile
	more.art_levels = 10
	t.eq(more.art_variant(5), 5, "补到十张：一次一张")


static func run_tiers(t: TestCase) -> void:
	t.begin("246 §6.1 / §7.1：三品 = 蓝 / 紫 / 金，面值 150 / 320 / 650，供给 +6 / +9 / +13，每击一 / 一 / 两层；同元素同家族；清明、琥珀是通用中品")
	var db := _db()
	var shape := {}
	for e in ELEMS:
		var ids := [StringName("%s_crystal_low" % e), StringName("%s_crystal" % e), StringName("%s_crystal_high" % e)]
		var rar: Array[int] = []
		var val: Array[int] = []
		var feed: Array[float] = []
		var stacks: Array[int] = []
		var fam := {}
		for id in ids:
			var d := db.get_def(id)
			t.not_null(d, "%s 在库里" % id)
			if d == null:
				return
			rar.append(d.rarity)
			val.append(ItemValue.of(d))
			feed.append((d.adjacency.feed_mods[0] as StatModifier).amount)
			var app := {}
			for r in d.adjacency.feed_rules:
				var a := BattleCompiler.applies_of(r)
				if not a.is_empty():
					app = a
			stacks.append(int(app.get("stacks", 0)))
			fam[d.crystal_family] = true
			shape[d.shape.cells_rotated(0)] = true
		t.eq(rar, [2, 3, 4] as Array[int], "%s：稀有度" % e)
		t.eq(val, [150, 320, 650] as Array[int], "%s：面值" % e)
		t.eq(feed, [6.0, 9.0, 13.0] as Array[float], "%s：供给" % e)
		t.eq(stacks, [1, 1, 2] as Array[int], "%s：每击层数" % e)
		t.eq(fam.size(), 1, "%s：三品一个家族" % e)
		t.eq(shape.size(), 1, "三品一样的形状（敌人身上换品不挪位置）")
		shape.clear()
	t.eq(CrystalRoll.family(db, &"frost"), [&"ice_crystal", &"ice_crystal_high", &"ice_crystal_low"] as Array[StringName], "冰的家族三件")
	for id in [&"quartz_cluster", &"raw_amber"]:
		var g := db.get_def(id)
		t.check(g.rarity == 3 and g.crystal_family == &"" and g.adjacency.feed_rules.is_empty(), "%s：稀有度 3、无家族、不带属性" % id)
	t.eq(ItemValue.of(db.get_def(&"quartz_cluster")), 320, "清明面值不动")
	t.eq(ItemValue.of(db.get_def(&"raw_amber")), 150, "琥珀面值不动")


static func run_high_opener(t: TestCase) -> void:
	t.begin("246 §6.1：上品开场先施 —— 装着火焰魔晶核的法杖，开战时对手身上两层灼伤；中品没有")
	var db := _db()
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(4000.0)
	var foe := BattleCompiler.compile(null, foe_in)
	for pair in [[&"fire_crystal_high", 2], [&"fire_crystal", 0]]:
		var b := C148._staff_board(db, pair[0], &"")
		var me := BattleCompiler.compile_board(b["board"], CombatantBaseline.with_hp(4000.0))
		var res := BattleSim.run(me, foe, _rng(5), 0.5)
		var opened := 0
		for ev in res.log:
			var e := ev as BattleEvent
			if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and e.time == 0 and e.get_name(&"buff") == &"scorch":
				opened = maxi(opened, e.get_int(&"stacks"))
		t.eq(opened, pair[1], "%s：开场对手灼伤 %d 层" % [pair[0], pair[1]])


static func run_heart(t: TestCase) -> void:
	t.begin("246 §6.2：果果之心 —— 魔法 + 魔晶石 + 贵重品，稀有度 5、面值十万；供给 +9 不带属性；没有耐久、名字无前缀、不滚品")
	var db := _db()
	var h := db.get_def(&"heart_of_guoguo")
	for tag in [&"magic", &"crystal", &"valuable", &"gem", &"treasure"]:
		t.check(h.tags.has(tag), "标签 %s" % tag)
	t.check(h.rarity == 5 and ItemValue.of(h) == 100000, "稀有度 5、面值十万")
	t.check(h.wear == null, "没有耐久：永不消耗")
	t.eq(Names.of_item(ItemInstance.create(h), "zh"), "果果之心", "名字无前缀")
	t.eq((h.adjacency.feed_mods[0] as StatModifier).amount, 9.0, "供给 +9（= 中品）")
	t.check(h.adjacency.feed_rules.is_empty(), "不带属性")
	t.check(not CrystalRoll.is_rolled(h), "掉落不滚它")
	var b := GridInventory.new(Vector2i(5, 3), 1, false)
	var staff := ItemInstance.create(db.get_def(&"magic_staff"))
	b.place(staff, Vector2i(2, 0), 0)
	var heart := ItemInstance.create(h)
	b.place(heart, Vector2i(1, 0), 0)
	var spec := BattleCompiler.compile_board(b)
	t.eq(spec.item_of(staff.uid).loaded.size(), 1, "装进法杖")


static func run_broken(t: TestCase) -> void:
	t.begin("246 §7.3：碎了留在原格 —— 不再变碎晶；名字「破碎的」、稀有度低两档（金 → 蓝）、卖价按低两档、商店与基地都按它；碎晶照旧在")
	var db := _db()
	var core := _with(db, &"lightning_crystal_high", 0)
	t.check(core.is_broken(), "归零 = 碎了")
	t.eq(core.def.wear.broken_into, &"", "不变碎晶")
	t.eq(core.rarity(), 2, "传说低两档 → 稀有")
	t.eq(_with(db, &"lightning_crystal_high", 1).rarity(), 4, "剩一次：稀有度不动")
	t.eq(_with(db, &"fire_crystal_low", 0).rarity(), 0, "蓝 → 普通")
	t.eq(Names.of_item(core, "zh"), "破碎的闪电魔晶核", "名字")
	t.eq(ItemValue.of_instance(core), roundi(650 * 0.16), "卖价 × 0.16")
	t.eq(MetaState.sell_price_of(core, 0.5), ItemValue.of_instance(core), "基地：贵重品按（打折后的）面值")
	t.eq(MetaState.sell_price_of(_with(db, &"lightning_crystal_high", 3), 0.5), 650, "基地：没碎按面值")
	var shop := ShopSession.new(Economy._shop_node(), Economy._rules(), db, Wallet.new(0))
	t.check(shop.sell_price_of(core.def, core) < shop.sell_price_of(core.def), "商店回购：碎了的少")
	t.check(ItemPainter.rarity_color(core.def, core.rarity()) == ItemPainter.rarity_color(db.get_def(&"fire_crystal_low")), "框色按低两档（= 蓝）")
	t.not_null(db.get_def(&"crystal_shards"), "碎晶还在（普通材料）")
	# 打一场碎在原格
	var c := TestSupport.load_content("free_mode")
	var g := GridInventory.new(Vector2i(3, 2), 1, false)
	var one := _with(c.items, &"fire_crystal", 0)
	g.place(one, Vector2i(0, 0), 0)
	t.check(WearModule.shatter(g, one, c.items) == null and g.get_item(one.uid) == one, "碎了的就留在格里")


static func run_roll(t: TestCase) -> void:
	t.begin("246 §7.2：掉落滚品 —— 同家族三品等概率、次数 1～满（满的也出、不出 0）；清明不换品；赐福版不换品；不是魔晶石的原样")
	var db := _db()
	var rng := _rng(246)
	var seen := {}
	var charges := {}
	var fire := db.get_def(&"fire_crystal")
	for i in 600:
		var x := CrystalRoll.reroll_id(fire, db, rng)
		seen[x] = int(seen.get(x, 0)) + 1
		charges[CrystalRoll.roll_charges(fire, rng)] = true
	t.eq(seen.size(), 3, "三品都出")
	t.check(seen.values().all(func(n: int) -> bool: return n > 120), "大致等概率：%s" % [seen])
	var ks := charges.keys()
	ks.sort()
	t.eq(ks, [1, 2, 3, 4, 5, 6, 7, 8, 9], "次数 1～9 都出、没有 0")
	t.eq(CrystalRoll.reroll_id(db.get_def(&"quartz_cluster"), db, rng), &"quartz_cluster", "清明不换品")
	var ids: Array[StringName] = [&"knife", &"raw_amber"]
	t.eq(CrystalRoll.reroll_ids(ids, db, rng), ids, "不是魔晶石 / 没家族：原样")
	for id in db.ids(true):
		var d := db.get_def(id)
		if d.is_blessed() and CrystalRoll.is_rolled(d):
			t.eq(CrystalRoll.reroll_id(d, db, rng), d.id, "赐福版不换品（%s）" % d.id)
			break
	var insts: Array = [ItemInstance.create(fire), ItemInstance.create(db.get_def(&"knife"))]
	CrystalRoll.roll_charges_of(insts, _rng(7))
	t.check((insts[0] as ItemInstance).charges() >= 1, "实例抽了次数")
	t.eq((insts[1] as ItemInstance).charges(), -1, "没耐久的不动")


static func run_enemy_drop(t: TestCase) -> void:
	t.begin("246 §7.2：敌人身上的魔晶石 —— 套路写的不换品、次数照抽；内容记 charges，开战的棋盘与尸体都照它恢复（掉下来就是那一颗）")
	var c := TestSupport.load_content("free_mode")
	var placed := [{"id": "fire_crystal", "at": [0, 0], "rot": 0}, {"id": "ice_crystal", "at": [0, 1], "rot": 0}, {"id": "knife", "at": [2, 0], "rot": 0}]
	EnemyPlacer.roll_crystals(placed, c.items, _rng(11), [&"fire_crystal"] as Array[StringName])
	t.eq(String(placed[0]["id"]), "fire_crystal", "写死的不换品")
	t.check(int(placed[0].get("charges", 0)) >= 1 and int(placed[1].get("charges", 0)) >= 1, "两颗都记了次数")
	t.check(String(placed[1]["id"]).begins_with("ice_crystal"), "没写死的在冰的家族里换")
	t.check(not placed[2].has("charges"), "小刀不记")
	var content := {"board": [4, 3], "items": placed}
	var board := EnemyKit.board_of(content, c.items)
	for inst in board.items():
		var it := inst as ItemInstance
		if it.def.wear != null:
			var want := int(placed[0]["charges"]) if it.def.id == &"fire_crystal" else int(placed[1]["charges"])
			t.eq(it.charges(), want, "开战棋盘：%s 剩 %d" % [it.def.id, want])
	var dropped: Array[StringName] = [StringName(String(placed[0]["id"])), StringName(String(placed[1]["id"]))]
	var corpse := DropResolver.corpse_of(content, {"dropped": dropped, "treasure": [] as Array[StringName]}, c.items)
	var got := {}
	for inst in corpse.items():
		got[String((inst as ItemInstance).def.id)] = (inst as ItemInstance).charges()
	t.eq(int(got.get("fire_crystal", -1)), int(placed[0]["charges"]), "尸体里那颗就是它")
	# 真摆一个学徒：身上的下品都记了次数
	var mage := c.enemies.enemy(&"apprentice_mage")
	var built := EnemyPlacer.build_content(mage, c.pool, c.items, 2, _rng(3))
	var crystals := (built["content"]["items"] as Array).filter(func(e: Dictionary) -> bool: return CrystalRoll.is_rolled(c.items.get_def(StringName(String(e["id"])))))
	t.check(not crystals.is_empty() and crystals.all(func(e: Dictionary) -> bool: return int(e.get("charges", 0)) >= 1), "学徒身上的晶石都记了次数（%d 颗）" % crystals.size())
