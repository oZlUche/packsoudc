## 207（作者定，待定按推荐）：自然系专属的【生长】—— 作战棋盘上、整件在包里的种子随全局倒计时长：到茎叶扎根（拖不动、挪不走、不被顶替），
## 到绽放连包扎根；加成取当前阶那一份（不累加）+ 随机抽的额外效果；自然之神不是当前信仰就休眠（不长、加成不算、锁保留）；离开棋盘清零
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _seed_json() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/items/thorn_seed.json"))


## 一局 + 换上一块 6×4 的作战棋盘：包 A（0,0）里放种子与纱布，包 B（2,0）里放自然之神的护符（让自然激活）
static func _setup(c: TestSupport.Content, seed_id: StringName = &"thorn_seed", with_charm: bool = true) -> Dictionary:
	var s := CS._start(c, null)
	if s == null:
		return {}
	var g := GridInventory.new(Vector2i(6, 4), s.board.id, true)
	var bag_a := ItemInstance.create(c.items.get_def(&"bag_small"))
	var bag_b := ItemInstance.create(c.items.get_def(&"bag_small"))
	g.place(bag_a, Vector2i(0, 0), 0)
	g.place(bag_b, Vector2i(2, 0), 0)
	var sd := ItemInstance.create(c.items.get_def(seed_id))
	g.place(sd, Vector2i(0, 0), 0)
	var other := ItemInstance.create(c.items.get_def(&"bandage"))
	g.place(other, Vector2i(1, 1), 0)
	var charm: ItemInstance = null
	if with_charm:
		charm = ItemInstance.create(c.items.get_def(&"charm_nature"))
		g.place(charm, Vector2i(2, 0), 0)
	s.board = g
	GrowthModule.of(s).install(s)     # 换了棋盘：再装一次（幂等），接到新棋盘上
	return {"run": s, "board": g, "seed": sd, "other": other, "charm": charm, "bag": bag_a, "bag_b": bag_b}


static func run_import_rules(t: TestCase) -> void:
	t.begin("207 · 表：生长只许写在自然信仰道具上；每阶至少 1 步；锁只能是三种；额外效果抽不出那么多 → error；导出往返一致")
	var ctx := ContentImporter.Context.new()
	var good := ImportReport.new()
	var def := ContentImporter.import_item(_seed_json(), ctx, good)
	t.check(good.ok(), "荆棘种子导得进来")
	t.not_null(def.growth if def != null else null, "带着生长")
	if def != null:
		t.eq(def.growth.stages.size(), 2, "两阶")
		t.eq(ContentExporter.to_json(ContentExporter.export_item(def)), FileAccess.get_file_as_string("res://data/authoring/items/thorn_seed.json"), "导出往返逐字节一致")
	var cases := {
		"不是自然信仰": func(d: Dictionary): d["tags"] = ["nature", "herb"],
		"别的神": func(d: Dictionary): d["tags"] = ["faith", "faith:sun", "nature"],
		"0 步": func(d: Dictionary): d["growth"]["stages"][1]["after"] = 0,
		"锁写错": func(d: Dictionary): d["growth"]["stages"][0]["lock"] = "pot",
		"抽太多": func(d: Dictionary): d["growth"]["stages"][1]["bonus_count"] = 3,
		"没有阶": func(d: Dictionary): d["growth"]["stages"] = [],
	}
	for label in cases:
		var d := _seed_json()
		(cases[label] as Callable).call(d)
		var r := ImportReport.new()
		ContentImporter.import_item(d, ctx, r)
		t.check(not r.ok(), "%s → error" % label)


static func run_grow_and_lock(t: TestCase) -> void:
	t.begin("207 · 长与锁：走 4 步到茎叶、这件扎根（移不动、搬不走、不被顶替），包和包里别的照旧；再 6 步到绽放、包也扎根；地上的不长；一次走很多步最多升一阶")
	var c := CS._content()
	var f := _setup(c)
	if f.is_empty():
		t.check(false, "开不了局")
		return
	var s: RunState = f["run"]
	var g: GridInventory = f["board"]
	var sd: ItemInstance = f["seed"]
	var other: ItemInstance = f["other"]
	var bag: ItemInstance = f["bag"]
	var mod := GrowthModule.of(s)
	t.not_null(mod, "默认装了生长模块")
	t.check(g.growth_locks, "作战棋盘开着扎根")
	var on_ground := ItemInstance.create(c.items.get_def(&"thorn_seed"))
	s.storage.admit(on_ground)
	var grown: Array = []
	mod.grown.connect(func(uid: int, stage: int): grown.append([uid, stage]))

	s.travel.clock.spend(3)
	t.eq(GrowthProfile.stage_of(sd), 0, "3 步：还是种子")
	t.eq(GrowthProfile.ticks_of(sd), 3, "记了 3 步")
	t.check(not g.is_locked(sd.uid), "种子：没扎根")
	t.check(InventoryService.move(g, sd.uid, g, Vector2i(0, 1), 0), "种子：能在包里挪")
	t.eq(GrowthProfile.ticks_of(sd), 3, "包里挪个位置不算离开（计数还在）")
	t.check(InventoryService.move(g, sd.uid, g, Vector2i(0, 0), 0), "挪回去")
	s.travel.clock.spend(1)
	t.eq(GrowthProfile.stage_of(sd), 1, "第 4 步：茎叶")
	t.eq(grown, [[sd.uid, 1]], "发了 grown")
	t.check(g.is_locked(sd.uid), "茎叶：扎根")
	t.check(not g.is_locked(bag.uid), "茎叶：包还能动")
	t.check(not g.is_locked(other.uid), "包里别的没扎根")
	t.check(not InventoryService.move(g, sd.uid, g, Vector2i(0, 1), 0), "扎了根的包里挪不动")
	t.check(not InventoryService.transfer_auto(g, sd.uid, s.storage), "扎了根的搬不到地上（双击）")
	t.check(g.has_item(sd.uid) and sd.origin == Vector2i(0, 0), "原地不动")
	t.check(g.place_displacing(ItemInstance.create(c.items.get_def(&"bandage")), Vector2i(0, 0), 0) == null, "顶不掉扎了根的")
	t.check(InventoryService.transfer_auto(g, other.uid, s.storage), "包里别的照旧能拿走")
	t.eq(GrowthProfile.stage_of(on_ground), 0, "地上的一颗不长")
	t.eq(GrowthProfile.ticks_of(on_ground), 0, "地上的不计步")

	s.travel.clock.spend(5)
	t.eq(GrowthProfile.stage_of(sd), 1, "再 5 步：还是茎叶")
	s.travel.clock.spend(1)
	t.eq(GrowthProfile.stage_of(sd), 2, "再 1 步（共 6）：绽放")
	t.check(g.bag_locked(bag.uid) and g.is_locked(bag.uid), "绽放：包也扎根")
	t.check(not g.is_locked((f["bag_b"] as ItemInstance).uid), "别的包不受影响")
	var dest := GridInventory.new(Vector2i(6, 4), 99, false)
	t.check(not InventoryService.move(g, bag.uid, dest, Vector2i(0, 0), 0), "钉住的包挪不走")
	t.check(not InventoryService.transfer_auto(g, bag.uid, s.storage), "钉住的包搬不走")
	var took := InventoryService.transfer_all(g, s.storage)
	t.check(g.has_item(sd.uid) and g.has_item(bag.uid), "全部搬走：扎了根的和钉住的包留下（搬走 %d 件）" % took)
	t.check(Names.of_item(sd, "zh") == "盛放的荆棘种子", "名字：盛放的荆棘种子（%s）" % Names.of_item(sd, "zh"))
	t.eq(Names.of_item(sd, "en"), "Blooming Thorn Seed", "英文前缀")
	t.check(ItemTooltip.describe(sd, g).contains("生长：绽放"), "悬浮窗写生长那一行")

	# 一次走很多步最多升一阶（剩下的不结转）
	var big := _setup(c, &"moonherb_seed")
	(big["run"] as RunState).travel.clock.spend(50)
	t.eq(GrowthProfile.stage_of(big["seed"]), 1, "一下 50 步：只升一阶")
	t.eq(GrowthProfile.ticks_of(big["seed"]), 0, "剩下的不结转")

	# 扎根只在一局的作战棋盘上：别的棋盘（基地带回来的）不锁
	var home := GridInventory.new(Vector2i(6, 4), 5, true)
	t.check(not home.growth_locks and not home.is_locked(sd.uid), "没开扎根的棋盘不锁")


static func run_dormant_and_bonus(t: TestCase) -> void:
	t.begin("207 · 休眠与加成：没有自然信物 = 休眠：不长、编译不带阶段加成、锁保留；放回信物接着长；加成取当前阶（不累加）；额外效果同种子同 uid 抽到同一条")
	var c := CS._content()
	var f := _setup(c, &"ironwood_sapling")
	if f.is_empty():
		t.check(false, "开不了局")
		return
	var s: RunState = f["run"]
	var g: GridInventory = f["board"]
	var sd: ItemInstance = f["seed"]
	var stages := sd.def.growth.stages
	var base_armor := StatMath.to_float(BattleCompiler.compile_board(g).item_of(sd.uid).stats.total_of(&"max_armor"))
	t.eq(base_armor, 0.0, "树苗：没有护甲")
	s.travel.clock.spend(4)
	var a1 := StatMath.to_float(BattleCompiler.compile_board(g).item_of(sd.uid).stats.total_of(&"max_armor"))
	t.eq(a1, (stages[0].mods[0] as StatModifier).amount, "小树：护甲 +%s" % a1)
	s.travel.clock.spend(6)
	var picked: Array = sd.state.get(GrowthProfile.BONUS_KEY, [])
	t.eq(picked.size(), 1, "大树：抽了一条额外效果")
	var want := (stages[1].mods[0] as StatModifier).amount
	if not picked.is_empty() and int(picked[0]) == 0:
		want += ((stages[1].bonus_pool[0] as GrowthBonus).mods[0] as StatModifier).amount
	var a2 := StatMath.to_float(BattleCompiler.compile_board(g).item_of(sd.uid).stats.total_of(&"max_armor"))
	t.eq(a2, want, "大树：取这一阶的终值（不累加小树那份）+ 额外效果")
	t.eq(GrowthProfile.pick_bonuses(stages[1], s.run_seed, sd.uid, 2), GrowthProfile.pick_bonuses(stages[1], s.run_seed, sd.uid, 2), "同种子同 uid 抽到的一样")

	var f2 := _setup(c, &"thorn_seed")
	var s2: RunState = f2["run"]
	var g2: GridInventory = f2["board"]
	var sd2: ItemInstance = f2["seed"]
	s2.travel.clock.spend(4)
	t.check(g2.is_locked(sd2.uid), "茎叶：扎根")
	var rules_lit := BattleCompiler.compile_board(g2).item_of(sd2.uid).rules.size()
	t.check(rules_lit >= 1, "茎叶：有荆棘规则（%d 条）" % rules_lit)
	g2.remove((f2["charm"] as ItemInstance).uid)     # 没有信物：自然不再激活，种子休眠
	s2.travel.clock.spend(10)
	t.eq(GrowthProfile.stage_of(sd2), 1, "休眠：不长")
	t.eq(GrowthProfile.ticks_of(sd2), 0, "休眠：不计步")
	t.check(g2.is_locked(sd2.uid), "休眠：锁保留")
	var dormant_spec := BattleCompiler.compile_board(g2)
	t.check(dormant_spec.item_of(sd2.uid) == null or dormant_spec.item_of(sd2.uid).rules.is_empty(), "休眠：编译不带阶段加成")
	g2.place(ItemInstance.create(c.items.get_def(&"charm_nature")), Vector2i(2, 0), 0)
	s2.travel.clock.spend(6)
	t.eq(GrowthProfile.stage_of(sd2), 2, "放回信物：接着长到绽放")


static func run_reset_and_save(t: TestCase) -> void:
	t.begin("207 · 清零与存档：长了几步的种子挪到地上再放回 → 清零；带回基地清零；生长计数 / 阶 / 额外效果存档往返逐字节一致，老档没记 = 种子")
	var c := CS._content()
	var f := _setup(c)
	if f.is_empty():
		t.check(false, "开不了局")
		return
	var s: RunState = f["run"]
	var g: GridInventory = f["board"]
	var sd: ItemInstance = f["seed"]
	s.travel.clock.spend(3)
	t.eq(GrowthProfile.ticks_of(sd), 3, "长了 3 步")
	t.check(InventoryService.transfer_auto(g, sd.uid, s.storage), "还没扎根：能拿到地上")
	t.eq(GrowthProfile.ticks_of(sd), 0, "离开棋盘：清零")
	t.check(InventoryService.transfer_auto(s.storage, sd.uid, g), "放回棋盘")
	s.travel.clock.spend(3)
	t.eq(GrowthProfile.ticks_of(sd), 3, "从头数")

	s.travel.clock.spend(1)     # 第 4 步：茎叶
	s.travel.clock.spend(6)     # 再 6 步：绽放
	t.eq(GrowthProfile.stage_of(sd), 2, "长到绽放")
	var back := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(sd.to_dict())), c.items)
	t.eq(GrowthProfile.stage_of(back), 2, "存档往返：还是绽放")
	t.eq(JSON.stringify(back.to_dict()), JSON.stringify(sd.to_dict()), "再存一次逐字节相同")
	var old := sd.to_dict()
	(old["state"] as Dictionary).clear()
	t.eq(GrowthProfile.stage_of(ItemInstance.from_dict(old, c.items)), 0, "老档没记：种子")

	# 读档：还在棋盘上的不当成「刚放上来」
	var saved := s.to_dict()
	var again := RunState.from_dict(saved, c.chapter, c.items, c.enemies, c.sets)
	t.not_null(again, "读得回来")
	t.check((saved["modules"] as Dictionary).has("growth"), "存档里有生长模块那一份")

	# 带回基地：清零
	var meta := MetaState.new()
	if meta._adopt(sd):
		t.eq(GrowthProfile.stage_of(sd), 0, "带回基地：清零")
	else:
		t.check(false, "基地不收种子")
