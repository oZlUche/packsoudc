extends RefCounted


static func _def(id: String, rows: Array, tags: Array = []) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(rows)
	var t: Array[StringName] = []
	for tag in tags:
		t.append(StringName(tag))
	d.tags = t
	return d


static func run(t: TestCase) -> void:
	t.begin("InventoryService")

	ItemInstance.reset_uid_counter()
	var bar := _def("bar", ["#", "#", "#"])
	var single := _def("dot", ["#"])
	var big := _def("big", ["##", "##"])
	var weapon := _def("sword", ["#"], ["weapon"])

	# --- 跨容器移动 ---
	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	var a := ItemInstance.create(bar)
	src.place(a, Vector2i(0, 0), 0)

	t.check(InventoryService.move(src, a.uid, dst, Vector2i(1, 0), 0), "跨容器移动应成功")
	t.eq(src.item_count(), 0, "源容器应清空")
	t.eq(dst.item_count(), 1, "目标容器应有 1 件")
	t.eq(a.container_id, 2, "container_id 应更新为目标容器")
	t.eq(a.origin, Vector2i(1, 0), "origin 应更新")
	t.eq(src.cell_uid(Vector2i(0, 0)), GridInventory.EMPTY_UID, "源占用表应清空")
	t.eq(dst.cell_uid(Vector2i(1, 1)), a.uid, "目标占用表应写入")

	# --- 关键路径：目标放不下时必须完整回滚 ---
	var blocker := ItemInstance.create(big)
	dst.place(blocker, Vector2i(2, 2), 0)
	var b := ItemInstance.create(bar)
	src.place(b, Vector2i(3, 0), 0)
	t.check(
		not InventoryService.move(src, b.uid, dst, Vector2i(2, 2), 0),
		"目标位置被占，移动应失败"
	)
	t.eq(src.item_count(), 1, "失败后物品必须仍在源容器 —— 不能凭空消失")
	t.check(src.has_item(b.uid), "源容器应仍持有该 uid")
	t.eq(b.origin, Vector2i(3, 0), "失败后 origin 应保持原值")
	t.eq(b.container_id, 1, "失败后 container_id 应保持源容器")
	t.eq(src.cell_uid(Vector2i(3, 2)), b.uid, "失败后源占用表应完好")
	# dst 此时持有先前移入的 a 与刚放入的 blocker，失败的移动不应改变这个件数
	t.eq(dst.item_count(), 2, "失败后目标容器件数不变，不应有残留")
	t.check(not dst.has_item(b.uid), "失败后目标容器不应持有被移动的 uid")

	# --- 越界失败同样回滚 ---
	t.check(
		not InventoryService.move(src, b.uid, dst, Vector2i(3, 3), 0),
		"越界移动应失败"
	)
	t.check(src.has_item(b.uid), "越界失败后物品仍在源容器")

	# --- 准入不过失败同样回滚 ---
	var slot := GridInventory.new(Vector2i(2, 2), 3)
	slot.accept_filter = func(d: ItemDef) -> bool: return d.tags.has(&"weapon")
	t.check(
		not InventoryService.move(src, b.uid, slot, Vector2i(0, 0), 0),
		"标签不匹配应失败"
	)
	t.check(src.has_item(b.uid), "标签失败后物品仍在源容器")

	var w := ItemInstance.create(weapon)
	src.place(w, Vector2i(0, 0), 0)
	t.check(InventoryService.move(src, w.uid, slot, Vector2i(0, 0), 0), "标签匹配应成功")

	# --- 移动不存在的 uid ---
	t.check(not InventoryService.move(src, 9999, dst, Vector2i(0, 0), 0), "未知 uid 应失败")
	t.check(not InventoryService.move(null, 1, dst, Vector2i(0, 0), 0), "空容器参数应失败")

	# --- 容器内挪位 ---
	var inv := GridInventory.new(Vector2i(4, 4), 4)
	var c := ItemInstance.create(bar)
	inv.place(c, Vector2i(0, 0), 0)
	t.check(InventoryService.move_within(inv, c.uid, Vector2i(3, 1), 0), "容器内挪位应成功")
	t.eq(c.origin, Vector2i(3, 1), "挪位后 origin 更新")
	t.eq(inv.item_count(), 1, "挪位不改变件数")
	t.eq(inv.cell_uid(Vector2i(0, 0)), GridInventory.EMPTY_UID, "旧位置应释放")

	# --- 挪位到自身重叠的位置（必须允许，因为已先移除）---
	t.check(InventoryService.move_within(inv, c.uid, Vector2i(3, 0), 0), "挪到与自身重叠的位置应成功")
	t.eq(c.origin, Vector2i(3, 0), "重叠挪位后 origin 更新")

	# --- 挪位失败回滚 ---
	var d2 := ItemInstance.create(big)
	inv.place(d2, Vector2i(0, 0), 0)
	t.check(not InventoryService.move_within(inv, c.uid, Vector2i(0, 0), 0), "挪到被占位置应失败")
	t.eq(c.origin, Vector2i(3, 0), "挪位失败后 origin 不变")
	t.eq(inv.cell_uid(Vector2i(3, 2)), c.uid, "挪位失败后占用表完好")

	# --- 带旋转的移动 ---
	var narrow := GridInventory.new(Vector2i(3, 1), 5)
	var src2 := GridInventory.new(Vector2i(4, 4), 6)
	var e := ItemInstance.create(bar)
	src2.place(e, Vector2i(0, 0), 0)
	t.check(
		not InventoryService.move(src2, e.uid, narrow, Vector2i(0, 0), 0),
		"竖条 rot0 放不进 3x1"
	)
	t.check(src2.has_item(e.uid), "失败后仍在源容器")
	t.check(
		InventoryService.move(src2, e.uid, narrow, Vector2i(0, 0), 1),
		"竖条 rot1 可放进 3x1"
	)
	t.eq(e.rotation, 1, "移动时指定的旋转应生效")

	# --- 自动装填移动 ---
	var from3 := GridInventory.new(Vector2i(4, 4), 7)
	var to3 := GridInventory.new(Vector2i(4, 4), 8)
	var f := ItemInstance.create(bar)
	from3.place(f, Vector2i(1, 1), 0)
	t.check(InventoryService.transfer_auto(from3, f.uid, to3), "自动装填应成功")
	t.eq(f.origin, Vector2i(0, 0), "自动装填应落在第一个可用位置")
	t.eq(from3.item_count(), 0, "源应清空")

	# --- 全部搬运：装不下的留在原处 ---
	var loot := GridInventory.new(Vector2i(4, 4), 9)
	var pack := GridInventory.new(Vector2i(2, 2), 10)
	var big1 := ItemInstance.create(big)     # 2x2，占满 pack
	var dot1 := ItemInstance.create(single)
	var dot2 := ItemInstance.create(single)
	loot.place(big1, Vector2i(0, 0), 0)
	loot.place(dot1, Vector2i(2, 0), 0)
	loot.place(dot2, Vector2i(3, 0), 0)
	var moved := InventoryService.transfer_all(loot, pack)
	t.eq(moved, 1, "2x2 背包只装得下那件大的")
	t.eq(pack.item_count(), 1, "目标应有 1 件")
	t.eq(loot.item_count(), 2, "装不下的 2 件应留在源容器")
	t.check(pack.has_item(big1.uid), "先搬大件：应装入 2x2 那件而非小件")

	# --- 移动期间信号只发一次 ---
	var s1 := GridInventory.new(Vector2i(4, 4), 11)
	var s2 := GridInventory.new(Vector2i(4, 4), 12)
	var counts := {"a": 0, "b": 0}
	s1.changed.connect(func(): counts["a"] += 1)
	s2.changed.connect(func(): counts["b"] += 1)
	var g := ItemInstance.create(single)
	s1.place(g, Vector2i(0, 0), 0)
	counts["a"] = 0
	counts["b"] = 0
	InventoryService.move(s1, g.uid, s2, Vector2i(1, 1), 0)
	t.eq(counts["a"], 1, "源容器应只发一次 changed")
	t.eq(counts["b"], 1, "目标容器应只发一次 changed")

	# --- 失败的移动也只发一次（且状态已还原）---
	var h := ItemInstance.create(big)
	s2.place(h, Vector2i(2, 2), 0)
	var i2 := ItemInstance.create(big)
	s1.place(i2, Vector2i(0, 0), 0)
	counts["a"] = 0
	counts["b"] = 0
	InventoryService.move(s1, i2.uid, s2, Vector2i(2, 2), 0)
	t.eq(counts["a"], 1, "回滚后源容器仍只发一次 changed")
	t.check(s1.has_item(i2.uid), "回滚后物品仍在源容器")
