## 校验磁盘上的真实资产，而不是代码里造的假数据。
## 内容做错了（形状为空、id 重复、id 与文件名不符）应该在这里被挡住。
extends RefCounted

const EXPECTED_COUNT := 10


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

	# 资产能真正装进容器
	var inv := GridInventory.new(Vector2i(8, 6), 1)
	var placed := 0
	for id in db.ids():
		if inv.try_add(ItemInstance.create(db.get_def(id))):
			placed += 1
	t.check(placed >= 6, "8x6 背包至少应装得下 6 件示例物品，实际 %d" % placed)

	# 装进去的内容能完整往返
	var back := GridInventory.from_dict(inv.to_dict(), db)
	t.eq(back.item_count(), inv.item_count(), "真实资产的序列化往返应无损")
	t.eq(back.free_cell_count(), inv.free_cell_count(), "往返后占格数应一致")
