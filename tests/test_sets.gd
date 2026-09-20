## 套装系统：背包层的计数与激活、按作用域取效果、编译期并入战斗（架构文档第 9 节）。
extends RefCounted


static func _mod(stat: StringName, category: int, percent: int, flat: float = 0.0) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.mult_category = category
	m.mult_percent = percent
	m.flat = flat
	return m


static func _item(id: String, set_id: String = "", damage: float = 10.0) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(["#"])
	d.set_id = StringName(set_id)
	var c := CombatProfile.new()
	c.base_stats = {"damage": damage}
	d.combat = c
	return d


static func _bag(id: String) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.shape = ItemShape.from_ascii(["####", "####"])
	d.is_bag = true
	return d


static func _combat_effect(percent: int, target: int = CombatSetEffect.Target.SET_PIECES) -> CombatSetEffect:
	var e := CombatSetEffect.new()
	e.target = target
	e.mods = [_mod(BattleStats.DAMAGE, StatMath.Buff.EMPOWER, percent)] as Array[StatModifier]
	return e


static func _tier(pieces: int, effects: Array) -> SetTier:
	var t := SetTier.new()
	t.pieces = pieces
	var typed: Array[SetEffect] = []
	for e in effects:
		typed.append(e)
	t.effects = typed
	return t


static func _set_def(id: String, tiers: Array, mode: int = ItemSetDef.CountMode.DISTINCT_DEFS) -> ItemSetDef:
	var s := ItemSetDef.new()
	s.id = StringName(id)
	s.display_name = id
	s.count_mode = mode
	var typed: Array[SetTier] = []
	for t in tiers:
		typed.append(t)
	s.tiers = typed
	return s


static func run(t: TestCase) -> void:
	t.begin("套装 · 背包层计数与激活")

	ItemInstance.reset_uid_counter()
	var scav := _set_def("scavenger", [
		_tier(2, [_combat_effect(20)]),
		_tier(4, [_combat_effect(30)]),
	])
	var db := SetDatabase.new()
	t.check(db.register(scav), "登记套装")
	t.check(not db.register(scav), "重复 id 被拒")

	var bag := _bag("bag")
	var a := _item("helm", "scavenger")
	var b := _item("boots", "scavenger")
	var c := _item("cloak", "scavenger")
	var d := _item("gloves", "scavenger")
	var loner := _item("rock", "")

	var board := GridInventory.new(Vector2i(8, 6), 1, true)
	board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)

	var tracker := SetTracker.create(db)
	var changes := {"n": 0}
	tracker.activation_changed.connect(func(): changes["n"] += 1)
	tracker.bind(board)

	t.eq(tracker.count_of(&"scavenger"), 0, "空棋盘 0 件")
	t.check(not tracker.is_active(&"scavenger"), "未激活")

	# --- 拖入即记，不必等到战斗 ---
	changes["n"] = 0
	board.place(ItemInstance.create(a), Vector2i(0, 0), 0)
	t.eq(tracker.count_of(&"scavenger"), 1, "放入 1 件立刻计入")
	t.eq(changes["n"], 1, "件数变化即发信号，UI 靠它做暗／亮切换")
	t.check(not tracker.is_active(&"scavenger"), "1 件还不够 2 件档")

	board.place(ItemInstance.create(b), Vector2i(1, 0), 0)
	t.eq(tracker.count_of(&"scavenger"), 2, "2 件")
	t.check(tracker.is_active(&"scavenger"), "达到 2 件档，激活")
	t.eq(tracker.active_tiers(&"scavenger").size(), 1, "只激活了 2 件档")

	# --- 档位累加而非互斥 ---
	board.place(ItemInstance.create(c), Vector2i(2, 0), 0)
	board.place(ItemInstance.create(d), Vector2i(3, 0), 0)
	t.eq(tracker.count_of(&"scavenger"), 4, "4 件")
	t.eq(tracker.active_tiers(&"scavenger").size(), 2, "2 件档与 4 件档同时生效")

	# --- 无关物品不计入 ---
	board.place(ItemInstance.create(loner), Vector2i(4, 0), 0)
	t.eq(tracker.count_of(&"scavenger"), 4, "无 set_id 的物品不计入")

	# --- 包是承载物，不算部件 ---
	var set_bag := _bag("set_bag")
	set_bag.set_id = &"scavenger"
	board.place(ItemInstance.create(set_bag), Vector2i(4, 2), 0)
	t.eq(tracker.count_of(&"scavenger"), 4, "作为包生效的物品不算套装部件")

	# --- 取走即失活 ---
	var removed_uid := board.cell_uid(Vector2i(3, 0))
	board.remove(removed_uid)
	t.eq(tracker.count_of(&"scavenger"), 3, "取走一件掉到 3")
	t.eq(tracker.active_tiers(&"scavenger").size(), 1, "4 件档失活，2 件档仍在")

	# --- UI 进度 ---
	var p := tracker.progress_of(&"scavenger")
	t.eq(p["count"], 3, "进度件数")
	t.eq(p["next"], 4, "下一档需要 4 件")
	t.check(p["active"], "当前已激活")


static func run_count_mode(t: TestCase) -> void:
	t.begin("套装 · 计数方式")

	ItemInstance.reset_uid_counter()
	var bag := _bag("bag")
	var sword := _item("sword", "twins")

	# DISTINCT_DEFS：同一定义只算一次
	var distinct := _set_def("twins", [_tier(2, [_combat_effect(10)])],
		ItemSetDef.CountMode.DISTINCT_DEFS)
	var db1 := SetDatabase.new()
	db1.register(distinct)
	var board1 := GridInventory.new(Vector2i(8, 6), 1, true)
	board1.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var tr1 := SetTracker.create(db1)
	tr1.bind(board1)
	board1.place(ItemInstance.create(sword), Vector2i(0, 0), 0)
	board1.place(ItemInstance.create(sword), Vector2i(1, 0), 0)
	t.eq(tr1.count_of(&"twins"), 1, "DISTINCT_DEFS：两把同样的剑只算 1 件")

	# INSTANCES：每件实例算一件
	var instances := _set_def("twins", [_tier(2, [_combat_effect(10)])],
		ItemSetDef.CountMode.INSTANCES)
	var db2 := SetDatabase.new()
	db2.register(instances)
	var board2 := GridInventory.new(Vector2i(8, 6), 2, true)
	board2.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var tr2 := SetTracker.create(db2)
	tr2.bind(board2)
	board2.place(ItemInstance.create(sword), Vector2i(0, 0), 0)
	board2.place(ItemInstance.create(sword), Vector2i(1, 0), 0)
	t.eq(tr2.count_of(&"twins"), 2, "INSTANCES：两把同样的剑算 2 件")
	t.check(tr2.is_active(&"twins"), "因此达到 2 件档")


static func run_scopes(t: TestCase) -> void:
	t.begin("套装 · 作用域隔离")

	var combat := _combat_effect(25)
	var loot := LootSetEffect.new()
	loot.extra_rolls = 1
	loot.rarity_bonus = 5

	t.eq(combat.scope(), SetScope.COMBAT, "战斗效果的作用域")
	t.eq(loot.scope(), SetScope.LOOT, "掉落效果的作用域")

	# 同一档里混放两种作用域
	var mixed := _set_def("mixed", [_tier(2, [combat, loot])])
	var db := SetDatabase.new()
	db.register(mixed)

	var bag := _bag("bag")
	var board := GridInventory.new(Vector2i(8, 6), 1, true)
	board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var tracker := SetTracker.create(db)
	tracker.bind(board)
	board.place(ItemInstance.create(_item("x", "mixed")), Vector2i(0, 0), 0)
	board.place(ItemInstance.create(_item("y", "mixed")), Vector2i(1, 0), 0)
	t.check(tracker.is_active(&"mixed"), "已激活")

	# 各系统只取自己那一档，互不干扰
	var combat_side := tracker.effects_in_scope(SetScope.COMBAT)
	var loot_side := tracker.effects_in_scope(SetScope.LOOT)
	t.eq(combat_side.size(), 1, "战斗作用域只拿到 1 条")
	t.eq(loot_side.size(), 1, "掉落作用域只拿到 1 条")
	t.check(combat_side[0] is CombatSetEffect, "编译器拿到的是战斗效果")
	t.check(loot_side[0] is LootSetEffect, "掉落系统拿到的是掉落效果")
	t.eq(tracker.effects_in_scope(&"nonexistent").size(), 0, "未知作用域返回空")

	# 未激活时任何作用域都取不到
	board.remove(board.cell_uid(Vector2i(1, 0)))
	t.check(not tracker.is_active(&"mixed"), "掉到 1 件，失活")
	t.eq(tracker.effects_in_scope(SetScope.COMBAT).size(), 0, "失活后战斗侧取不到")
	t.eq(tracker.effects_in_scope(SetScope.LOOT).size(), 0, "失活后掉落侧也取不到")


static func run_compile_integration(t: TestCase) -> void:
	t.begin("套装 · 编译期并入战斗")

	ItemInstance.reset_uid_counter()
	var scav := _set_def("scavenger", [_tier(2, [_combat_effect(50)])])
	var db := SetDatabase.new()
	db.register(scav)

	var bag := _bag("bag")
	var board := GridInventory.new(Vector2i(8, 6), 1, true)
	board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var tracker := SetTracker.create(db)
	tracker.bind(board)

	var piece_a := ItemInstance.create(_item("helm", "scavenger", 10.0))
	var piece_b := ItemInstance.create(_item("boots", "scavenger", 10.0))
	var outsider := ItemInstance.create(_item("rock", "", 10.0))
	board.place(piece_a, Vector2i(0, 0), 0)
	board.place(outsider, Vector2i(2, 0), 0)

	# 只有 1 件，未激活
	var spec := BattleCompiler.compile(board, 25.0, tracker.effects_in_scope(SetScope.COMBAT))
	t.eq(spec.stats_of(piece_a.uid).total_int_of(BattleStats.DAMAGE), 10, "未激活时无加成")

	# 凑齐 2 件
	board.place(piece_b, Vector2i(1, 0), 0)
	t.check(tracker.is_active(&"scavenger"), "已激活")
	spec = BattleCompiler.compile(board, 25.0, tracker.effects_in_scope(SetScope.COMBAT))
	t.eq(spec.stats_of(piece_a.uid).total_int_of(BattleStats.DAMAGE), 15, "套装部件 +50%")
	t.eq(spec.stats_of(piece_b.uid).total_int_of(BattleStats.DAMAGE), 15, "另一件部件同样")
	t.eq(spec.stats_of(outsider.uid).total_int_of(BattleStats.DAMAGE), 10,
		"SET_PIECES 目标：非部件不吃加成")

	# ALL_ITEMS 目标
	var global_set := _set_def("global", [_tier(1, [_combat_effect(50, CombatSetEffect.Target.ALL_ITEMS)])])
	var db2 := SetDatabase.new()
	db2.register(global_set)
	var board2 := GridInventory.new(Vector2i(8, 6), 2, true)
	board2.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var tr2 := SetTracker.create(db2)
	tr2.bind(board2)
	var member := ItemInstance.create(_item("banner", "global", 10.0))
	var bystander := ItemInstance.create(_item("stone", "", 10.0))
	board2.place(member, Vector2i(0, 0), 0)
	board2.place(bystander, Vector2i(1, 0), 0)
	var spec2 := BattleCompiler.compile(board2, 25.0, tr2.effects_in_scope(SetScope.COMBAT))
	t.eq(spec2.stats_of(bystander.uid).total_int_of(BattleStats.DAMAGE), 15,
		"ALL_ITEMS 目标：非部件也吃加成")

	# --- 套装自带的规则会真的出手 ---
	var pulse := CombatSetEffect.new()
	var rule := AbilityRule.new()
	rule.trigger = OnSchedule.new()
	var cd := CooldownCadence.new()
	cd.seconds = 1.0
	rule.cadence = cd
	var dmg := DealDamage.new()
	dmg.damage_stat = &""
	dmg.amount = 7.0
	rule.effects = [dmg] as Array[Effect]
	pulse.rules = [rule] as Array[AbilityRule]

	var pulse_set := _set_def("pulse", [_tier(1, [pulse])])
	var db3 := SetDatabase.new()
	db3.register(pulse_set)
	var board3 := GridInventory.new(Vector2i(8, 6), 3, true)
	board3.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var tr3 := SetTracker.create(db3)
	tr3.bind(board3)
	board3.place(ItemInstance.create(_item("totem", "pulse", 0.0)), Vector2i(0, 0), 0)

	var spec3 := BattleCompiler.compile(board3, 100.0, tr3.effects_in_scope(SetScope.COMBAT))
	t.eq(spec3.set_rules.size(), 1, "套装规则挂在 spec 上，不属于任何物品")

	var foe := CombatantSpec.new()
	foe.max_hp = StatMath.from_float(100.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := BattleSim.run(spec3, foe, rng, 3.5)
	t.check(result.winner == -1 or result.winner == 0, "打得动")
	# 1 / 2 / 3 秒各一次，共 21 点
	# snapshot() 返回的已是取整后的整数，不要再 to_int 一次
	t.eq(int(result.final["sides"][1]["resources"][&"hp"][0]), 79,
		"套装的周期性规则确实在战斗中生效（1/2/3 秒各 7 点）")
