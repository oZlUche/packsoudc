## 阶段 1 的验收场景：可玩的整理沙盒。
##
## 三个容器共用同一个 [GridInventory] 实现，演示修正后的空间模型（架构文档 3.2）：
##
## - **作战棋盘**：`requires_bag = true`。开局一格都不能用，可用区来自玩家自己放上去的包。
##   包本身是异形物品，可拖可转，拖动时内容物跟着走。只有这里的物品会参战。
## - **暂存区**：自由容器。东西放这儿保留但不参战 —— 「背着但没装进包 = 占位置不出力」。
## - **战利品**：自由容器，模拟敌人尸体。
##
## 没有装备栏：武器护甲药水统统占棋盘格子，空间是唯一的约束。
extends Control

const BOARD_SIZE := Vector2i(7, 9)
const LOOT_SIZE := Vector2i(6, 5)
## 暂存区是列表，只有宽度
const STORAGE_WIDTH := 240

const BG := Color("101216")
const FG := Color("dfe3ea")
const DIM := Color("8b93a1")

var _db: ItemDatabase
var _board: GridInventory
var _storage: ItemStash
var _loot: GridInventory
var _drag: DragLayer
var _status: Label
var _font: Font


func _ready() -> void:
	_font = _make_cjk_font()
	UiTheme.install(self)     # 121：界面主题挂在窗口上
	_db = ItemDatabase.new()
	if _db.load_dir() == 0:
		push_error("没有加载到任何物品定义，先跑 tools/import_content.gd 把作者数据导成资产")

	ItemInstance.reset_uid_counter()
	_board = GridInventory.new(BOARD_SIZE, 1, true)
	_storage = ItemStash.new(2)
	_loot = GridInventory.new(LOOT_SIZE, 3)

	_build_ui()
	_seed_start()
	_refill_loot()
	_update_status()

	for inv in [_board, _storage, _loot]:
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
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_heading("背包整理沙盒", 22, FG))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(row)

	row.add_child(_labeled_grid("作战棋盘 7x9　只有放进包里的才参战", _board, true))

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 16)
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(side)
	side.add_child(_labeled_stash("暂存区　保留但不参战　一行一件，不占格子", _storage))
	side.add_child(_labeled_grid("战利品", _loot))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	buttons.add_child(_button("全部拾取到暂存区", _on_take_all))
	buttons.add_child(_button("刷新战利品", _on_refill))
	buttons.add_child(_button("清空棋盘", _on_clear_board))

	_status = _heading("", 14, DIM)
	root.add_child(_status)
	root.add_child(
		_heading(
			"左键拖动　R 旋转　右键 / Esc 取消　　拖包时内容物跟着走；包转了之后"
			+ "依附不上的东西会脱落进暂存区　　压着别人放手会把人顶出来：一件直接上手，多件进暂存区",
			14, DIM
		)
	)

	# 拖拽层最后加入，才能盖在所有容器之上
	_drag = DragLayer.new()
	_drag.label_font = _font
	_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.stash = _storage
	for view in _grid_views():
		_drag.register_view(view)


## [param adjacency] 只对棋盘开。暂存区与战利品里的东西不参战，
## 那里的邻接「点亮」什么也不代表 —— 画出来只会让人以为摆对了。
func _labeled_grid(caption: String, inv: GridInventory, adjacency: bool = false) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(_heading(caption, 13, DIM))

	var view := InventoryView.new()
	view.label_font = _font
	view.inventory = inv
	view.show_adjacency = adjacency
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(view)
	return box


## 暂存区不是网格，单独搭一列。
func _labeled_stash(caption: String, s: ItemStash) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(_heading(caption, 13, DIM))

	var view := StashView.new()
	view.label_font = _font
	view.stash = s
	view.custom_minimum_size.x = STORAGE_WIDTH
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(view)
	return box


func _grid_views() -> Array[ContainerView]:
	var found: Array[ContainerView] = []
	_collect_views(self, found)
	return found


func _collect_views(node: Node, out: Array[ContainerView]) -> void:
	for child in node.get_children():
		if child is ContainerView:
			out.append(child)
		_collect_views(child, out)


func _heading(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.label(l, font_size, color)     # 121：字体在主题里，颜色先选变体
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b


#region 操作
## 开局给一个起始包并往里塞两件东西，否则玩家面对的是一整片不可用的空盘。
func _seed_start() -> void:
	var leather := _db.get_def(&"bag_leather")
	if leather == null:
		return
	_board.begin_batch()
	_board.place(ItemInstance.create(leather), Vector2i(0, 0), 0)
	for id in [&"pistol", &"mag"]:
		var def := _db.get_def(id)
		if def != null:
			_board.try_add(ItemInstance.create(def))
	_board.end_batch()


func _refill_loot() -> void:
	_loot.clear()
	var ids := _db.ids()
	if ids.is_empty():
		return
	ids.shuffle()
	_loot.begin_batch()
	for i in mini(7, ids.size()):
		_loot.try_add(ItemInstance.create(_db.get_def(ids[i])))
	_loot.end_batch()


func _on_take_all() -> void:
	var moved := InventoryService.transfer_all(_loot, _storage)
	_flash("拾取 %d 件到暂存区，剩 %d 件" % [moved, _loot.item_count()])


func _on_refill() -> void:
	_refill_loot()
	_flash("战利品已刷新")


func _on_clear_board() -> void:
	_board.clear()
	_flash("棋盘已清空，重新放包才能装东西")


## 截图工具的钩子：把界面填成有东西可看的状态。
func demo_fill() -> void:
	_board.begin_batch()
	var long_bag := _db.get_def(&"bag_long")
	if long_bag != null:
		_board.place(ItemInstance.create(long_bag), Vector2i(2, 0), 0)
	var belt := _db.get_def(&"belt_potion")
	if belt != null:
		_board.place(ItemInstance.create(belt), Vector2i(2, 2), 0)
	for id in [&"rifle", &"crowbar", &"battery", &"stim"]:
		var def := _db.get_def(id)
		if def != null:
			_board.try_add(ItemInstance.create(def))
	_board.end_batch()

	InventoryService.transfer_all(_loot, _storage)
	_refill_loot()
	_update_status()
	_demo_hover_displacing()


## 抓一件东西悬在别人身上，把「会顶掉它」的落点预览摆出来。
##
## 顶替是这个场景里唯一一个**只在拖拽途中**才看得见的状态，
## 不摆出来，截图就永远证明不了它画对了。
func _demo_hover_displacing() -> void:
	var views := _grid_views()
	if views.size() < 2:
		return
	var board_view := views[0] as InventoryView
	var storage_view := views[1] as StashView
	if board_view == null or storage_view == null:
		return

	var list := _storage.items()
	if list.is_empty():
		return
	var picked := list[0] as ItemInstance
	storage_view.grab_requested.emit(
		storage_view, picked.uid,
		storage_view.row_origin_px(0) + Vector2(20, StashView.ROW_H * 0.5)
	)

	for inst in _board.items():
		var item := inst as ItemInstance
		if _board.acts_as_bag(item.def):
			continue
		_drag.update_preview(
			board_view.global_position + board_view.cell_origin_px(item.origin)
			+ Vector2(InventoryView.CELL, InventoryView.CELL) * 0.5
		)
		return


func _update_status() -> void:
	if _status == null:
		return
	var bag_count := _board.bags().size()
	_status.text = "棋盘 %d 件　可用格 %d（空闲 %d）　包 %d 个　　暂存区 %d 件　　战利品 %d 件" % [
		_board.item_count() - bag_count,
		_board.usable_cell_count(),
		_board.free_cell_count(),
		bag_count,
		_storage.item_count(),
		_loot.item_count(),
	]


func _flash(msg: String) -> void:
	_update_status()
	if _status != null:
		_status.text += "　　— " + msg
#endregion
