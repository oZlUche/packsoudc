## 编译阶段：棋盘 → CombatantSpec（架构文档 4.2）。
extends RefCounted


static func _mod(stat: StringName, category: int, percent: int, flat: float = 0.0) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.mult_category = category
	m.mult_percent = percent
	m.flat = flat
	return m


static func _item(id: String, rows: Array, tags: Array = []) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(rows)
	var t: Array[StringName] = []
	for tag in tags:
		t.append(StringName(tag))
	d.tags = t
	return d


static func _weapon(id: String, rows: Array, damage: float, cd: float, tags: Array = []) -> ItemDef:
	var d := _item(id, rows, tags)
	var c := CombatProfile.new()
	c.is_active = true
	c.cooldown_sec = cd
	c.base_stats = {"damage": damage}
	d.combat = c
	return d


static func _bag(id: String, rows: Array, mods: Array[StatModifier] = []) -> ItemDef:
	var d := _item(id, rows)
	d.is_bag = true
	d.bag_mods = mods
	return d


static func _board(size: Vector2i = Vector2i(6, 6)) -> GridInventory:
	return GridInventory.new(size, 1, true)


## item_stats 是 Dictionary，取出来是 Variant，推不出类型；这里显式标注一次
static func _dmg(spec: CombatantSpec, uid: int) -> int:
	var set: StatSet = spec.item_stats[uid]
	return set.total_int_of(BattleStats.DAMAGE)


static func run(t: TestCase) -> void:
	t.begin("编译阶段")

	var B := StatMath.Buff
	ItemInstance.reset_uid_counter()

	var plain_bag := _bag("bag", ["###", "###"])
	var sword := _weapon("sword", ["#", "#"], 10.0, 2.0, ["weapon"])
	var rock := _item("rock", ["#"], ["material"])

	# --- 空棋盘 ---
	var empty := BattleCompiler.compile(_board(), 25.0)
	t.eq(empty.max_hp_int(), 25, "空棋盘只有基础生命值")
	t.eq(empty.abilities.size(), 0, "空棋盘没有任何能力")
	t.eq(empty.rough_dps(), 0.0, "空棋盘 DPS 为 0")

	# --- 单件主动物品 ---
	var board := _board()
	board.place(ItemInstance.create(plain_bag), Vector2i(0, 0), 0)
	var s1 := ItemInstance.create(sword)
	board.place(s1, Vector2i(0, 0), 0)

	var spec := BattleCompiler.compile(board, 25.0)
	t.eq(spec.abilities.size(), 1, "一件主动物品产出一个能力")
	t.eq(spec.abilities[0].source_uid, s1.uid, "能力记录来源 uid")
	t.eq(spec.abilities[0].def_id, &"sword", "能力记录定义 id")
	t.eq(StatMath.to_int(spec.abilities[0].damage()), 10, "伤害取基础值")
	t.eq(spec.abilities[0].cooldown(), StatMath.from_float(2.0), "冷却取基础值")
	t.eq(spec.abilities[0].haste(), StatMath.ONE, "速度默认 1.0")

	# --- 包不产出能力 ---
	t.check(board.acts_as_bag(plain_bag), "包在棋盘上作为包生效")
	for ability in spec.abilities:
		t.ne(ability.def_id, &"bag", "包本身不应产出能力")

	# --- 非主动物品贡献属性但不出手 ---
	var charm := _item("charm", ["#"])
	var charm_combat := CombatProfile.new()
	charm_combat.is_active = false
	charm_combat.base_stats = {"max_hp": 30.0}
	charm.combat = charm_combat
	board.place(ItemInstance.create(charm), Vector2i(1, 0), 0)

	spec = BattleCompiler.compile(board, 25.0)
	t.eq(spec.abilities.size(), 1, "被动物品不产出能力")
	t.eq(spec.max_hp_int(), 55, "被动物品的 max_hp 叠加到基础 25 上")

	# --- 暂存区不参战 ---
	var storage := GridInventory.new(Vector2i(4, 4), 2)
	storage.place(ItemInstance.create(sword), Vector2i(0, 0), 0)
	var spec_board_only := BattleCompiler.compile(board, 25.0)
	t.eq(spec_board_only.abilities.size(), 1, "暂存区里的武器不参战")

	# --- 纯素材不产出能力 ---
	var mat_board := _board()
	mat_board.place(ItemInstance.create(plain_bag), Vector2i(0, 0), 0)
	mat_board.place(ItemInstance.create(rock), Vector2i(0, 0), 0)
	t.eq(BattleCompiler.compile(mat_board).abilities.size(), 0, "没有 CombatProfile 的物品不参战")


static func run_bag_effects(t: TestCase) -> void:
	t.begin("编译阶段 · 包体效果")

	var B := StatMath.Buff
	ItemInstance.reset_uid_counter()

	var haste_bag := _bag("fanny", ["###", "###"], [_mod(BattleStats.HASTE, B.HASTE, 10)])
	var plain_bag := _bag("plain", ["###", "###"])
	var sword := _weapon("sword", ["#"], 10.0, 2.0, ["weapon"])

	# --- 包内物品吃到包的效果 ---
	var board := _board(Vector2i(8, 6))
	board.place(ItemInstance.create(haste_bag), Vector2i(0, 0), 0)
	var inside := ItemInstance.create(sword)
	board.place(inside, Vector2i(0, 0), 0)

	var spec := BattleCompiler.compile(board)
	t.eq(spec.abilities.size(), 1, "一个能力")
	t.eq(
		spec.abilities[0].haste(),
		StatMath.mul(StatMath.ONE, StatMath.ONE + StatMath.from_percent(10)),
		"包内物品触发速度 ×1.1"
	)

	# --- 另一个包里的物品不吃这个包的效果 ---
	board.place(ItemInstance.create(plain_bag), Vector2i(3, 0), 0)
	var outside := ItemInstance.create(sword)
	board.place(outside, Vector2i(3, 0), 0)

	spec = BattleCompiler.compile(board)
	var by_uid := {}
	for ability in spec.abilities:
		by_uid[ability.source_uid] = ability
	t.eq(by_uid.size(), 2, "两个能力")
	t.ne(by_uid[inside.uid].haste(), StatMath.ONE, "急速包里的仍有加成")
	t.eq(by_uid[outside.uid].haste(), StatMath.ONE, "普通包里的没有加成")

	# --- 把物品挪进急速包，加成随之生效 ---
	InventoryService.move(board, outside.uid, board, Vector2i(1, 0), 0)
	t.eq(board.bag_of(outside.uid), board.bag_at(Vector2i(1, 0)), "已挪进急速包")
	spec = BattleCompiler.compile(board)
	for ability in spec.abilities:
		t.ne(ability.haste(), StatMath.ONE, "两件都在急速包里，都应有加成")


static func run_sockets(t: TestCase) -> void:
	t.begin("编译阶段 · 插槽")

	var B := StatMath.Buff
	ItemInstance.reset_uid_counter()

	var bag := _bag("bag", ["####", "####", "####"])

	# 磨刀石：星格在右邻，点亮后【填充者】增伤（FILLER 方向）
	var whetstone := _item("whetstone", ["#"])
	var ws := SocketProfile.new()
	ws.star_cells = [Vector2i(1, 0)]
	ws.star_filter = [&"weapon"] as Array[StringName]
	ws.star_direction = SocketProfile.Direction.FILLER
	ws.star_mods = [_mod(BattleStats.DAMAGE, B.SHARP, 50)]
	whetstone.sockets = ws

	# 饭盒：三个星格，点亮几个【自己】就加几份（HOLDER 方向）
	var lunchbox := _weapon("lunchbox", ["#"], 10.0, 2.0)
	var lb := SocketProfile.new()
	lb.star_cells = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	lb.star_direction = SocketProfile.Direction.HOLDER
	lb.star_mods = [_mod(BattleStats.DAMAGE, B.EMPOWER, 20)]
	lunchbox.sockets = lb

	var sword := _weapon("sword", ["#"], 10.0, 2.0, ["weapon"])
	var shield := _weapon("shield", ["#"], 4.0, 3.0, ["gear"])
	var longbar := _item("longbar", ["###"], ["food"])
	var dot := _item("dot", ["#"], ["food"])

	# --- FILLER：磨刀石让右邻的武器增伤 ---
	var board := _board(Vector2i(8, 6))
	board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	board.place(ItemInstance.create(whetstone), Vector2i(0, 0), 0)
	var s := ItemInstance.create(sword)
	board.place(s, Vector2i(1, 0), 0)

	t.eq(_dmg(BattleCompiler.compile(board), s.uid), 15, "磨刀石让右邻武器 10 → 15")

	# --- 过滤器：非 weapon 填不亮 ---
	var board2 := _board(Vector2i(8, 6))
	board2.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	board2.place(ItemInstance.create(whetstone), Vector2i(0, 0), 0)
	var sh := ItemInstance.create(shield)
	board2.place(sh, Vector2i(1, 0), 0)
	t.eq(
		_dmg(BattleCompiler.compile(board2), sh.uid),
		4,
		"gear 标签不满足 weapon 过滤器，不受加成"
	)

	# --- HOLDER：点亮几个加几份 ---
	var board3 := _board(Vector2i(8, 6))
	board3.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var lunch := ItemInstance.create(lunchbox)
	board3.place(lunch, Vector2i(0, 0), 0)
	t.eq(
		_dmg(BattleCompiler.compile(board3), lunch.uid),
		10,
		"无人填星时不加成"
	)

	board3.place(ItemInstance.create(dot), Vector2i(1, 0), 0)
	t.eq(
		_dmg(BattleCompiler.compile(board3), lunch.uid),
		12,
		"点亮 1 个星：10 × 1.2 = 12"
	)

	board3.place(ItemInstance.create(dot), Vector2i(2, 0), 0)
	board3.place(ItemInstance.create(dot), Vector2i(3, 0), 0)
	t.eq(
		_dmg(BattleCompiler.compile(board3), lunch.uid),
		16,
		"点亮 3 个星：同区 +60%，10 × 1.6 = 16"
	)

	# --- 去重：一件物品压住 3 个星格也只算 1 个 ---
	var board4 := _board(Vector2i(8, 6))
	board4.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var lunch4 := ItemInstance.create(lunchbox)
	board4.place(lunch4, Vector2i(0, 0), 0)
	var bar := ItemInstance.create(longbar)   # 1x3 横条，正好盖住三个星格
	board4.place(bar, Vector2i(1, 0), 0)
	t.eq(board4.cell_uid(Vector2i(1, 0)), bar.uid, "长条压住第一个星格")
	t.eq(board4.cell_uid(Vector2i(3, 0)), bar.uid, "长条压住第三个星格")
	t.eq(
		_dmg(BattleCompiler.compile(board4), lunch4.uid),
		12,
		"一件物品压住 3 个星格只算 1 份：10 × 1.2 = 12"
	)

	# --- 插槽随物品旋转 ---
	# 磨刀石是 1x1，星格 (1,0) 在右邻；转 1 步后应变成下邻 (0,1)
	var board5 := _board(Vector2i(8, 6))
	board5.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	var ws_inst := ItemInstance.create(whetstone)
	board5.place(ws_inst, Vector2i(0, 0), 0)
	var below := ItemInstance.create(sword)
	board5.place(below, Vector2i(0, 1), 0)
	t.eq(
		_dmg(BattleCompiler.compile(board5), below.uid),
		10,
		"rot0 时下邻不在星格上，不受加成"
	)
	t.check(board5.rotate_item(ws_inst.uid, 1), "磨刀石旋转一步")
	t.eq(
		_dmg(BattleCompiler.compile(board5), below.uid),
		15,
		"rot1 后星格转到下邻，加成生效"
	)


static func run_determinism(t: TestCase) -> void:
	t.begin("编译阶段 · 确定性")

	var B := StatMath.Buff
	var bag := _bag("bag", ["####", "####"], [_mod(BattleStats.DAMAGE, B.EMPOWER, 10)])
	var sword := _weapon("sword", ["#"], 10.0, 2.0, ["weapon"])
	var axe := _weapon("axe", ["#"], 7.0, 1.5, ["weapon"])
	var stone := _item("stone", ["#"], ["weapon"])
	var sp := SocketProfile.new()
	sp.star_cells = [Vector2i(1, 0), Vector2i(-1, 0)]
	sp.star_filter = [&"weapon"] as Array[StringName]
	sp.star_direction = SocketProfile.Direction.FILLER
	sp.star_mods = [_mod(BattleStats.DAMAGE, B.SHARP, 25)]
	stone.sockets = sp

	## 摆同一个局面，只改放置调用的先后
	var build := func(order: Array) -> Array:
		ItemInstance.reset_uid_counter()
		var board := _board(Vector2i(6, 4))
		board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
		for entry in order:
			board.place(ItemInstance.create(entry[0]), entry[1], 0)
		var spec := BattleCompiler.compile(board)
		var rows: Array = []
		for ability in spec.abilities:
			rows.append([
				String(ability.def_id), ability.damage(), ability.cooldown(), ability.haste()
			])
		rows.sort_custom(func(a, b): return str(a) < str(b))
		return [spec.max_hp, rows]

	var forward: Array = build.call([
		[sword, Vector2i(0, 0)], [stone, Vector2i(1, 0)], [axe, Vector2i(2, 0)]
	])
	var backward: Array = build.call([
		[axe, Vector2i(2, 0)], [stone, Vector2i(1, 0)], [sword, Vector2i(0, 0)]
	])
	t.eq(forward, backward, "同一局面、不同放置顺序，必须编译出完全相同的结果")

	# 磨刀石两侧各一把武器，两把都应吃到 +25%
	var rows: Array = forward[1]
	t.eq(rows.size(), 2, "两把武器各一个能力")
	for row in rows:
		var expected := StatMath.mul(
			StatMath.from_float(10.0 if row[0] == "sword" else 7.0),
			StatMath.ONE + StatMath.from_percent(10)
		)
		expected = StatMath.mul(expected, StatMath.ONE + StatMath.from_percent(25))
		t.eq(row[1], expected, "%s 应吃到包体 +10%% 与插槽 +25%% 两个乘区" % row[0])

	# 同一棋盘反复编译结果一致
	ItemInstance.reset_uid_counter()
	var board := _board(Vector2i(6, 4))
	board.place(ItemInstance.create(bag), Vector2i(0, 0), 0)
	board.place(ItemInstance.create(sword), Vector2i(0, 0), 0)
	board.place(ItemInstance.create(stone), Vector2i(1, 0), 0)
	var a := BattleCompiler.compile(board)
	var b := BattleCompiler.compile(board)
	t.eq(a.max_hp, b.max_hp, "重复编译生命值一致")
	t.eq(a.abilities.size(), b.abilities.size(), "重复编译能力数一致")
	for i in a.abilities.size():
		t.eq(a.abilities[i].damage(), b.abilities[i].damage(), "重复编译伤害一致")
		t.eq(a.abilities[i].source_uid, b.abilities[i].source_uid, "重复编译来源顺序一致")

	# 能力按 uid 升序，顺序稳定
	var uids: Array = []
	for ability in a.abilities:
		uids.append(ability.source_uid)
	var sorted_uids := uids.duplicate()
	sorted_uids.sort()
	t.eq(uids, sorted_uids, "能力列表按 source_uid 升序")
