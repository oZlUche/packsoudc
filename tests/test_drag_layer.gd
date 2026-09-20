## 拖拽状态机的逻辑测试。
##
## 视图不进场景树，直接设 position / size；鼠标位置由测试给定。
## 这样整条「抓取 → 预览 → 旋转 → 放手 / 取消」的链路都能自动验证，
## 不必靠手工拖拽去撞那些失败路径。
extends RefCounted

const CELL := 48.0


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


static func _view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


## 某格中心的全局坐标
static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func run(t: TestCase) -> void:
	t.begin("DragLayer")

	ItemInstance.reset_uid_counter()
	var bar := _def("bar", ["#", "#", "#"])
	var big := _def("big", ["##", "##"])
	var gun := _def("gun", ["#"], ["weapon"])

	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)

	# --- 命中测试 ---
	t.check(drag.view_at(Vector2(10, 10)) == view_a, "左侧坐标应命中 view_a")
	t.check(drag.view_at(Vector2(410, 10)) == view_b, "右侧坐标应命中 view_b")
	t.is_null(drag.view_at(Vector2(300, 10)), "两者之间的空白不应命中任何视图")

	# --- 抓取：物品立刻离开源容器 ---
	var a := ItemInstance.create(bar)
	src.place(a, Vector2i(0, 0), 0)
	t.check(not drag.is_dragging(), "初始不在拖拽中")
	view_a.grab_requested.emit(view_a, a.uid, Vector2(24, 24))  # 抓住 (0,0) 格
	t.check(drag.is_dragging(), "抓取后应进入拖拽态")
	t.eq(src.item_count(), 0, "抓取时物品即从源容器移除")
	t.eq(src.cell_uid(Vector2i(0, 1)), GridInventory.EMPTY_UID, "源占用表已清空")

	# --- 跨容器放手 ---
	t.check(drag.drop_at(_center(view_b, Vector2i(1, 0))), "放到 view_b 应成功")
	t.check(not drag.is_dragging(), "放手后退出拖拽态")
	t.eq(dst.item_count(), 1, "目标容器应有 1 件")
	t.eq(a.origin, Vector2i(1, 0), "落点应为抓取格所在位置")
	t.eq(a.container_id, 2, "container_id 应更新")

	# --- 抓取偏移：抓住长条中段，落点要相应前移 ---
	var b := ItemInstance.create(bar)
	src.place(b, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, b.uid, Vector2(24, 24 + CELL))  # 抓住 (0,1)，即中段
	drag.drop_at(_center(view_a, Vector2i(2, 2)))
	t.eq(b.origin, Vector2i(2, 1), "抓中段放到 (2,2)，物品原点应落在 (2,1)")

	# --- 放到容器外：退回源容器原位 ---
	var c := ItemInstance.create(big)
	src.place(c, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, c.uid, Vector2(24, 24))
	t.check(not drag.drop_at(Vector2(300, 300)), "放到空白处应判为未落入容器")
	t.check(src.has_item(c.uid), "应退回源容器")
	t.eq(c.origin, Vector2i(0, 0), "应退回原位")
	t.eq(c.rotation, 0, "应退回原朝向")

	# --- 放到非法位置：同样退回 ---
	view_a.grab_requested.emit(view_a, c.uid, Vector2(24, 24))
	t.check(not drag.drop_at(_center(view_a, Vector2i(3, 3))), "2x2 放在 (3,3) 会越界")
	t.check(src.has_item(c.uid), "越界后应退回源容器")
	t.eq(c.origin, Vector2i(0, 0), "越界后应退回原位")

	# --- 取消拖拽 ---
	view_a.grab_requested.emit(view_a, c.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "取消前处于拖拽态")
	drag.cancel()
	t.check(not drag.is_dragging(), "取消后退出拖拽态")
	t.check(src.has_item(c.uid), "取消后物品退回源容器")
	t.eq(c.origin, Vector2i(0, 0), "取消后回到原位")

	# --- 拖拽中旋转 ---
	var narrow := GridInventory.new(Vector2i(3, 1), 3)
	var view_c := _view(narrow, Vector2(0, 400))
	drag.register_view(view_c)

	var d := ItemInstance.create(bar)
	src.remove(c.uid)
	src.place(d, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, d.uid, Vector2(24, 24))
	t.check(not drag.drop_at(_center(view_c, Vector2i(0, 0))), "竖条直接放进 3x1 应失败")
	t.check(src.has_item(d.uid), "失败后退回源容器")

	view_a.grab_requested.emit(view_a, d.uid, Vector2(24, 24))
	drag.rotate_dragged()
	t.check(drag.drop_at(_center(view_c, Vector2i(0, 0))), "旋转后放进 3x1 应成功")
	t.eq(d.rotation, 1, "落地后朝向应为旋转后的值")
	t.eq(narrow.item_count(), 1, "3x1 容器应收下这件")

	# --- 标签过滤 ---
	var slot := GridInventory.new(Vector2i(1, 1), 4)
	slot.accept_tags = [&"weapon"] as Array[StringName]
	var view_d := _view(slot, Vector2(400, 400))
	drag.register_view(view_d)

	var e := ItemInstance.create(big)
	src.place(e, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, e.uid, Vector2(24, 24))
	t.check(not drag.drop_at(_center(view_d, Vector2i(0, 0))), "无标签物品放不进武器槽")
	t.check(src.has_item(e.uid), "被拒后退回源容器")

	var g := ItemInstance.create(gun)
	src.remove(e.uid)
	src.place(g, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, g.uid, Vector2(24, 24))
	t.check(drag.drop_at(_center(view_d, Vector2i(0, 0))), "带 weapon 标签可放进武器槽")

	# --- 落点预览的合法性判定 ---
	var h := ItemInstance.create(big)
	src.place(h, Vector2i(0, 0), 0)
	var occupied := ItemInstance.create(big)
	dst.place(occupied, Vector2i(0, 0), 0)

	view_a.grab_requested.emit(view_a, h.uid, Vector2(24, 24))
	drag.update_preview(_center(view_b, Vector2i(2, 2)))
	t.check(view_b._preview_on, "光标所在视图应显示预览")
	t.check(view_b._preview_valid, "空位处预览应为合法")
	t.check(not view_a._preview_on, "非光标所在视图应清除预览")

	drag.update_preview(_center(view_b, Vector2i(0, 0)))
	t.check(not view_b._preview_valid, "被占位置预览应为非法")

	drag.update_preview(_center(view_d, Vector2i(0, 0)))
	t.check(not view_d._preview_valid, "标签不符时预览应为非法")

	drag.update_preview(Vector2(300, 300))
	t.check(not view_b._preview_on, "光标离开视图后预览应清除")

	drag.cancel()
	t.check(not view_b._preview_on, "结束拖拽应清掉所有预览")

	# --- 拖拽期间不接受第二次抓取 ---
	var i := ItemInstance.create(gun)
	src.place(i, Vector2i(3, 3), 0)
	view_a.grab_requested.emit(view_a, h.uid, Vector2(24, 24))
	var dragging_uid := h.uid
	view_a.grab_requested.emit(view_a, i.uid, Vector2(24 + CELL * 3, 24 + CELL * 3))
	t.check(src.has_item(i.uid), "已在拖拽中时，第二件不应被抓起")
	drag.drop_at(_center(view_a, Vector2i(0, 0)))
	t.check(src.has_item(dragging_uid), "第一件正常落地")

	# 释放节点，避免无头进程退出时报泄漏
	for v in [view_a, view_b, view_c, view_d]:
		v.free()
	drag.free()
