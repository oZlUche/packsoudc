## 193 §4（作者 2026-10-18）：拿起道具（含旋转）时，落点预览上照样画它的增益 / 受益 / 装载格，点亮按现在棋盘上的邻居算
extends RefCounted

const CELL := InventoryView.CELL


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


## 一格宽两格长的件：右边一格给增益（只给带 metal 的）、下面一格受益
static func _giver() -> ItemDef:
	var d := _def("giver", ["11"])
	var p := AdjacencyProfile.new()
	p.grant_cells.assign([Vector2i(2, 0)])
	p.grant_filter.assign([&"metal"])
	var m := StatModifier.new()
	p.grant_mods.assign([m])
	p.receive_cells.assign([Vector2i(0, 1)])
	p.receive_mods.assign([StatModifier.new()])
	d.adjacency = p
	return d


static func _view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func run_markers_offsets(t: TestCase) -> void:
	t.begin("193 §4 · 格位按朝向转（和棋盘上的件同一套旋转）")
	var d := _giver()
	for rot in 4:
		var got := InventoryView.marker_offsets(d, rot)
		t.eq(got.size(), 2, "朝向 %d：两枚" % rot)
		t.eq(got[0][0], d.shape.transform_point(Vector2i(2, 0), rot), "朝向 %d：增益格跟着转" % rot)
		t.eq(String(got[1][1]), "receive", "第二枚是受益")


static func run_drag_preview(t: TestCase) -> void:
	t.begin("193 §4 · 拖着走：落点预览带上手上这件的格位；邻居对得上就亮；转一下格位跟着转；松手 / 收预览后不画")
	ItemInstance.reset_uid_counter()
	var giver := _giver()
	var src := GridInventory.new(Vector2i(6, 6), 1)
	var dst := GridInventory.new(Vector2i(6, 6), 2)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))
	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)
	var inst := ItemInstance.create(giver)
	src.place(inst, Vector2i(0, 0), 0)
	var ore := ItemInstance.create(_def("ore", ["1"], ["metal"]))
	dst.place(ore, Vector2i(3, 1), 0)
	view_a.grab_requested.emit(view_a, inst.uid, Vector2(24, 24))
	drag.update_preview(_center(view_b, Vector2i(1, 1)))
	var marks: Array = view_b.preview_markers()
	var by_cell := {}
	for m in marks:
		by_cell[m[0]] = [m[1], m[2]]
	t.check(by_cell.has(Vector2i(3, 1)) and by_cell[Vector2i(3, 1)][0] == "grant", "增益格画在落点右边（%s）" % str(marks))
	t.check(by_cell.has(Vector2i(3, 1)) and bool(by_cell[Vector2i(3, 1)][1]), "那一格上是金属：亮")
	t.check(by_cell.has(Vector2i(1, 2)) and not bool(by_cell[Vector2i(1, 2)][1]), "受益格空着：不亮")
	drag.rotate_dragged()
	drag.update_preview(_center(view_b, Vector2i(1, 1)))
	var after: Array = view_b.preview_markers()
	var origin: Vector2i = view_b._preview_origin
	t.check(after.any(func(m): return m[0] == origin + giver.shape.transform_point(Vector2i(2, 0), 1) and m[1] == "grant"), "转一下：增益格跟着转（%s）" % str(after))
	t.check(not after.any(func(m): return m[0] == Vector2i(3, 1) and m[1] == "grant") or origin + giver.shape.transform_point(Vector2i(2, 0), 1) == Vector2i(3, 1), "原来那格不再是增益格")
	drag.update_preview(_center(view_a, Vector2i(4, 4)))
	t.eq(view_b.preview_markers(), [], "挪到别的视图：这块不画了")
	t.check(not view_a.preview_markers().is_empty(), "画到新的落点上")
	drag.cancel()
	t.eq(view_a.preview_markers(), [], "收了：不画")
