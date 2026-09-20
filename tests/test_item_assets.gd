## 校验磁盘上的真实资产，而不是代码里造的假数据。
## 内容做错了（形状为空、id 重复、id 与文件名不符）应该在这里被挡住。
extends RefCounted

const EXPECTED_COUNT := 15
const EXPECTED_BAGS := 4


static func run(t: TestCase) -> void:
	t.begin("物品资产")

	var db := ItemDatabase.new()
	var loaded := db.load_dir(ItemDatabase.DEFAULT_DIR)
	t.eq(loaded, EXPECTED_COUNT, "应从 data/items 加载到 %d 个定义" % EXPECTED_COUNT)
	t.eq(db.size(), EXPECTED_COUNT, "数据库条目数应一致")

	for id in db.ids():
		var def := db.get_def(id)
		t.check(def.is_valid(), "定义 '%s' 应合法" % id)
		t.check(def.display_name != "", "定义 '%s' 应有显示名" % id)
		t.check(def.shape != null and def.shape.cell_count() > 0, "定义 '%s' 应有非空形状" % id)
		t.check(def.rarity >= 0, "定义 '%s' 稀有度应非负" % id)

	# 抽查几个已知资产，防止生成脚本被改坏
	var rifle := db.get_def(&"rifle")
	t.not_null(rifle, "应存在 rifle")
	t.eq(rifle.display_name, "步枪", "rifle 显示名")
	t.eq(rifle.shape.cell_count(), 3, "步枪占 3 格")
	t.eq(rifle.shape.size_rotated(0), Vector2i(1, 3), "步枪 rot0 为 1x3")
	t.eq(rifle.shape.size_rotated(1), Vector2i(3, 1), "步枪 rot1 为 3x1")
	t.check(rifle.tags.has(&"weapon"), "步枪应带 weapon 标签")

	var core := db.get_def(&"core")
	t.not_null(core, "应存在 core")
	t.eq(core.shape.cell_count(), 5, "能量核心为十字五格")
	t.eq(core.shape.size_rotated(0), Vector2i(3, 3), "十字包围盒 3x3")
	t.eq(core.shape.distinct_rotation_count(), 1, "十字四向对称，只有 1 种可辨朝向")

	var crowbar := db.get_def(&"crowbar")
	t.eq(crowbar.shape.distinct_rotation_count(), 4, "L 形撬棍有 4 种可辨朝向")

	# --- 包体资产 ---
	var bag_count := 0
	for id in db.ids():
		if db.get_def(id).is_bag:
			bag_count += 1
	t.eq(bag_count, EXPECTED_BAGS, "应有 %d 个包体定义" % EXPECTED_BAGS)

	var leather := db.get_def(&"bag_leather")
	t.not_null(leather, "应存在皮革包")
	t.check(leather.is_bag, "皮革包应标记为包体")
	t.eq(leather.shape.cell_count(), 6, "皮革包提供 6 格")
	t.check(leather.bag_accept_tags.is_empty(), "皮革包不限内容")

	var belt := db.get_def(&"belt_potion")
	t.check(belt.is_bag, "药水带应标记为包体")
	t.check(belt.bag_accept_tags.has(&"consumable"), "药水带只收 consumable")
	t.check(not db.get_def(&"rifle").is_bag, "步枪不是包体")

	# --- 真实资产在棋盘上跑一遍完整流程 ---
	var board := GridInventory.new(Vector2i(7, 9), 1, true)
	t.eq(board.usable_cell_count(), 0, "空棋盘没有可用格")
	t.check(board.try_add(ItemInstance.create(leather)), "皮革包可放上棋盘")
	t.eq(board.usable_cell_count(), 6, "放包后有 6 格可用")

	# 显式摆放，不靠遍历顺序 —— 自动装填是贪心的，先遇到 3x2 的防弹衣
	# 就会旋转后填满整个 2x3 的包，后面什么都塞不进，那样测不出东西
	t.check(board.try_add(ItemInstance.create(db.get_def(&"mag"))), "弹匣 1 格可入包")
	t.check(board.try_add(ItemInstance.create(db.get_def(&"battery"))), "电池 1 格可入包")
	t.check(board.try_add(ItemInstance.create(db.get_def(&"pistol"))), "手枪 2 格可入包")
	t.eq(board.free_cell_count(), 2, "6 格用掉 4 格，剩 2 格")
	t.check(
		not board.try_add(ItemInstance.create(db.get_def(&"armor"))),
		"3x2 的防弹衣在只剩 2 格时放不进"
	)

	# --- 包体准入：药水带只收 consumable ---
	var belt_inst := ItemInstance.create(belt)
	t.check(board.place(belt_inst, Vector2i(4, 0), 0), "药水带放在棋盘空处")
	t.eq(board.usable_cell_count(), 9, "两个包共 9 格")
	t.check(
		not board.place(ItemInstance.create(db.get_def(&"mag")), Vector2i(4, 0), 0),
		"弹匣不带 consumable，进不了药水带"
	)
	t.check(
		board.place(ItemInstance.create(db.get_def(&"stim")), Vector2i(4, 0), 0),
		"兴奋剂带 consumable，可进药水带"
	)
	t.check(
		not board.place(ItemInstance.create(db.get_def(&"medkit")), Vector2i(4, 1), 0),
		"医疗包 2x2 会伸出 1 格宽的药水带，应被拒绝"
	)

	# 装进去的内容能完整往返
	var back := GridInventory.from_dict(board.to_dict(), db)
	t.eq(back.item_count(), board.item_count(), "真实资产的序列化往返应无损")
	t.eq(back.usable_cell_count(), board.usable_cell_count(), "往返后可用格数应一致")
	t.eq(back.free_cell_count(), board.free_cell_count(), "往返后空闲格数应一致")
