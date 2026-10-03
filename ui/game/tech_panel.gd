## 基地的「科技」页（110，作者定）：左边仓库格子（带滚动），右边每项科技一张卡 —— 等级、要多少钱、每种材料已交 / 需要、【升级】。
##
## 交材料两条路，和出售页一样：**双击**仓库里的一件，或**拖**进右边的「上交区」。不是下一级要的就提示「下一级不需要「X」」。
## **上交即消耗**（交了不能退，卡上写明）；钱在按【升级】时一次扣，材料交齐且钱够按钮才亮。逻辑全在 [TechService]。
extends MarginContainer

signal changed()

## 上交区几格
const ZONE_SIZE := Vector2i(4, 2)

var _flow: GameFlow = null
var _meta: MetaState = null
var _font: Font
var _drag: DragLayer
var _warehouse_view: InventoryView
## 上交区：一块空的自由格子，只收下一级还差的材料；落进来的那件当场记账、从这里拿走
var _zone: GridInventory
var _zone_view: InventoryView
var _cards: VBoxContainer
var _line: Label
## 科技 id → 【升级】按钮（测试看）
var _upgrade_btns: Dictionary = {}


func setup(flow: GameFlow, font: Font) -> void:
	_flow = flow
	_meta = flow.meta
	_font = font
	_build()
	_meta.changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	left.add_child(_label("仓库　双击一件上交，或拖进右边的上交区", 13, UiPalette.DIM))
	_warehouse_view = InventoryView.new()
	_warehouse_view.label_font = _font
	_warehouse_view.inventory = _meta.warehouse
	_warehouse_view.show_adjacency = false
	_warehouse_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_warehouse_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): submit(uid))
	left.add_child(ScrollBox.wrap(_warehouse_view))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	right.add_child(_cards)
	right.add_child(_label("上交区　拖进来就交（上交即消耗，交了不能退）", 13, UiPalette.DIM))
	_zone = GridInventory.new(ZONE_SIZE, 0, false)
	_zone.accept_filter = _wanted
	_zone.changed.connect(_on_zone_changed)
	_zone_view = InventoryView.new()
	_zone_view.label_font = _font
	_zone_view.inventory = _zone
	_zone_view.show_adjacency = false
	_zone_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(_zone_view)
	_line = _label("", 13, UiPalette.STAMINA)
	right.add_child(_line)

	_drag = DragLayer.new()
	_drag.label_font = _font
	add_child(_drag)     # 铺满，盖在仓库与上交区上
	_drag.register_view(_warehouse_view)
	_drag.register_view(_zone_view)
	_drag.drag_finished.connect(_on_drag_finished)


#region 公开动作
## 交仓库里的一件给第一项还要它的科技。返回交没交成
func submit(uid: int) -> bool:
	var inst := _meta.warehouse.get_item(uid)
	if inst == null:
		return false
	var def := _taker(inst.def)
	if def == null:
		_line.text = "下一级不需要「%s」" % Names.of(inst.def)
		return false
	var ok := _flow.submit_tech(def.id, uid)
	if ok:
		_line.text = "交了「%s」" % Names.of(inst.def)
		changed.emit()
	return ok


func upgrade(id: StringName) -> bool:
	var ok := _flow.upgrade_tech(id)
	if ok:
		var def := _flow.tech_of(id)
		_line.text = "%s 升到 Lv %d" % [Names.of(def), TechService.level(_meta, id)]
		changed.emit()
	return ok


## 【升级】按钮（测试看）；没有这项 null
func upgrade_button(id: StringName) -> Button:
	return _upgrade_btns.get(id, null)


func line_text() -> String:
	return _line.text


func zone() -> GridInventory:
	return _zone


func drag_layer() -> DragLayer:
	return _drag
#endregion


## 第一项下一级还要这件的科技；都不要 null
func _taker(item_def: ItemDef) -> TechDef:
	for def in _flow.tech_defs:
		if TechService.can_submit(_meta, def, item_def):
			return def
	return null


func _wanted(item_def: ItemDef) -> bool:
	return _taker(item_def) != null


## 上交区里落进来的：记账、拿走（东西已离开仓库，只差记一笔）
func _on_zone_changed() -> void:
	for inst in _zone.items():
		var it := inst as ItemInstance
		var def := _taker(it.def)
		if def == null:
			continue     # 不该发生（accept_filter 拦着）；留在区里，拖走即回仓库
		_zone.remove(it.uid)
		if TechService.deposit(_meta, def, it.def):
			_flow.save_meta()
			_line.text = "交了「%s」" % Names.of(it.def)
			changed.emit()


## 拖到上交区却没放进去 = 这件不是下一级要的：说一句
func _on_drag_finished(uid: int, dropped: bool) -> void:
	if dropped:
		return
	var inst := _meta.warehouse.get_item(uid)
	if inst != null and DragLayer.visible_rect(_zone_view).has_point(_zone_view.get_global_mouse_position()):
		_line.text = "下一级不需要「%s」" % Names.of(inst.def)


func _refresh() -> void:
	if _cards == null:
		return
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_upgrade_btns.clear()
	if _flow.tech_defs.is_empty():
		_cards.add_child(_label("（没有科技的内容：data/authoring/techs/）", 12, UiPalette.DIM))
		return
	for def in _flow.tech_defs:
		_cards.add_child(_card(def))


func _card(def: TechDef) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.PANEL
	box.border_color = UiPalette.LINE
	box.set_border_width_all(1)
	box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var lv := TechService.level(_meta, def.id)
	var tier := TechService.next_tier(_meta, def)
	var head := "%s　Lv %d / %d" % [Names.of(def), lv, def.max_level()]
	if tier == null:
		head += "　已满级"
	elif def.effect != null and def.effect.describe() != "":
		head += "　下一级：%s" % def.effect.describe()
	col.add_child(_label(head, 16, UiPalette.FG))
	if tier != null:
		var rich := _meta.funds >= tier.funds
		col.add_child(_label("钱　%d / 持有 %d" % [tier.funds, _meta.funds], 13, UiPalette.HEAL if rich else UiPalette.DIM))
		var keys: Array = tier.items.keys()
		keys.sort()
		for key in keys:
			var need := int(tier.items[key])
			var have := TechService.deposited(_meta, def.id, StringName(String(key)))
			var item_def := _flow.items.get_def(StringName(String(key))) if _flow.items != null else null
			var name := Names.of(item_def) if item_def != null else String(key)
			col.add_child(_label("%s　已交 %d / 需要 %d%s" % [name, have, need, "　✓" if have >= need else ""], 13,
				UiPalette.HEAL if have >= need else UiPalette.FG))
		var b := Button.new()
		b.text = "升级"
		b.add_theme_font_override("font", _font)
		UiPalette.style_button(b, UiPalette.Tier.PRIMARY, UiPalette.button_font_size(14, UiPalette.Tier.PRIMARY))
		b.disabled = not TechService.ready(_meta, def)
		var id := def.id
		b.pressed.connect(func(): upgrade(id))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(b)
		_upgrade_btns[def.id] = b
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
