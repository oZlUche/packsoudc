## 阶段 1 的验收场景：可玩的整理沙盒。
##
## 三个容器共用同一个 [GridInventory] 实现 —— 背包（含封禁格的非矩形容器）、
## 战利品、武器槽（带准入标签）。可在其间任意拖拽，验证异形占格、旋转、
## 跨容器原子移动与标签过滤。
extends Control

const PACK_SIZE := Vector2i(8, 6)
const LOOT_SIZE := Vector2i(6, 5)
const SLOT_SIZE := Vector2i(1, 3)

const BG := Color("101216")
const FG := Color("dfe3ea")
const DIM := Color("8b93a1")

var _db: ItemDatabase
var _pack: GridInventory
var _loot: GridInventory
var _slot: GridInventory
var _drag: DragLayer
var _status: Label
var _font: Font


func _ready() -> void:
	_font = _make_cjk_font()
	_db = ItemDatabase.new()
	var n := _db.load_dir()
	if n == 0:
		push_error("没有加载到任何物品定义，先跑 tools/gen_sample_items.gd")

	ItemInstance.reset_uid_counter()
	_pack = GridInventory.new(PACK_SIZE, 1)
	# 挖掉右下两格，演示非矩形容器
	_pack.set_blocked(Vector2i(PACK_SIZE.x - 1, PACK_SIZE.y - 1), true)
	_pack.set_blocked(Vector2i(PACK_SIZE.x - 2, PACK_SIZE.y - 1), true)
	_loot = GridInventory.new(LOOT_SIZE, 2)
	_slot = GridInventory.new(SLOT_SIZE, 3)
	_slot.accept_tags = [&"weapon"] as Array[StringName]

	_build_ui()
	_refill_loot()
	_update_status()

	for inv in [_pack, _loot, _slot]:
		inv.changed.connect(_update_status)


func _make_cjk_font() -> Font:
	# Godot 内置字体不含 CJK 字形，中文会显示成方块
	var f := SystemFont.new()
	f.font_names = PackedStringArray(
		["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"]
	)
	return f


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_heading("背包整理沙盒", 22, FG))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(row)

	row.add_child(_labeled_grid("背包 8x6（右下两格不可用）", _pack))
	row.add_child(_labeled_grid("战利品 6x5", _loot))
	row.add_child(_labeled_grid("武器槽（只收 weapon）", _slot))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	buttons.add_child(_button("全部拾取", _on_take_all))
	buttons.add_child(_button("刷新战利品", _on_refill))
	buttons.add_child(_button("清空背包", _on_clear_pack))

	_status = _heading("", 14, DIM)
	root.add_child(_status)

	var hint := _heading("左键拖动　R 旋转　右键 / Esc 取消", 14, DIM)
	root.add_child(hint)

	# 拖拽层最后加入，才能盖在所有容器之上
	_drag = DragLayer.new()
	_drag.label_font = _font
	_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	for view in _grid_views():
		_drag.register_view(view)


func _labeled_grid(caption: String, inv: GridInventory) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(_heading(caption, 14, DIM))

	var view := InventoryView.new()
	view.label_font = _font
	view.inventory = inv
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(view)
	return box


func _grid_views() -> Array[InventoryView]:
	var found: Array[InventoryView] = []
	_collect_views(self, found)
	return found


func _collect_views(node: Node, out: Array[InventoryView]) -> void:
	for child in node.get_children():
		if child is InventoryView:
			out.append(child)
		_collect_views(child, out)


func _heading(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.pressed.connect(handler)
	return b


#region 操作
func _refill_loot() -> void:
	_loot.clear()
	var ids := _db.ids()
	if ids.is_empty():
		return
	ids.shuffle()
	_loot.begin_batch()
	var tries := mini(8, ids.size())
	for i in tries:
		_loot.try_add(ItemInstance.create(_db.get_def(ids[i])))
	_loot.end_batch()


func _on_take_all() -> void:
	var moved := InventoryService.transfer_all(_loot, _pack)
	_flash("拾取了 %d 件，%d 件装不下" % [moved, _loot.item_count()])


func _on_refill() -> void:
	_refill_loot()
	_flash("战利品已刷新")


func _on_clear_pack() -> void:
	_pack.clear()
	_flash("背包已清空")


## 截图工具的钩子：把界面填成有东西可看的状态。
func demo_fill() -> void:
	InventoryService.transfer_all(_loot, _pack)
	_refill_loot()
	# 只有真装进去了才能停 —— 狙击枪是 1x4，放不进 1x3 的武器槽
	for inst in _pack.items():
		var item := inst as ItemInstance
		if not item.def.tags.has(&"weapon"):
			continue
		if InventoryService.transfer_auto(_pack, item.uid, _slot):
			break
	_update_status()


func _update_status() -> void:
	if _status == null:
		return
	_status.text = "背包 %d 件 / 空格 %d　　战利品 %d 件　　武器槽 %d 件" % [
		_pack.item_count(), _pack.free_cell_count(),
		_loot.item_count(), _slot.item_count(),
	]


func _flash(msg: String) -> void:
	_update_status()
	if _status != null:
		_status.text += "　　— " + msg
#endregion
