## 基地的「科技」页（110；118 作者定改成「左树右板」）：
## [codeblock]
## 左：科技树（TechTreeView）—— 深度 0 在最下面、往上点亮；点一个节点，右板切到它
## 右：说明面板，从上到下 ——  名称　Lv n / m（单级写已点亮 / 未点亮）
##                          效果：一句总述；「现在：……」「下一级：……」
##                          费用：钱 需要 / 持有；材料每种一行 已交 / 需要；锁住的写「需要先点亮：……」；满级写「已满级」
##                          【点亮】/【升级】
##     下面：上交区（只给**选中的节点**）+ 折叠的仓库格子（双击一件上交）
## [endcodeblock]
## **上交即消耗**（交了不能退）；钱在按按钮时一次扣，前置点亮、材料交齐且钱够按钮才亮。逻辑全在 [TechService]。
extends MarginContainer

signal changed()

## 上交区几格
const ZONE_SIZE := Vector2i(4, 2)
const PANEL_WIDTH := 420.0

var _flow: GameFlow = null
var _meta: MetaState = null
var _font: Font
var _drag: DragLayer
var _tree: TechTreeView
var _warehouse_view: InventoryView
var _warehouse_box: Control
var _warehouse_toggle: Button
## 上交区：一块空的自由格子，只收**选中节点**下一级还差的材料；落进来的那件当场记账、从这里拿走
var _zone: GridInventory
var _zone_view: InventoryView
var _name: Label
var _effect: VBoxContainer
var _cost: VBoxContainer
var _action: Button
var _line: Label
var _selected: StringName = &""


func setup(flow: GameFlow, font: Font) -> void:
	_flow = flow
	_meta = flow.meta
	_font = font
	_build()
	_meta.changed.connect(_refresh)
	var first := _default_selection()
	if first != &"":
		select(first)
	_refresh()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_label("科技树　从下往上点亮；点一个节点看右边", 13, UiPalette.DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 520)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_tree = TechTreeView.new()
	scroll.add_child(_tree)
	_tree.setup(_meta, _flow.tech_defs, _font)
	_tree.selected.connect(_on_tree_selected)
	if _flow.tech_defs.is_empty():
		left.add_child(_label("（没有科技的内容：data/authoring/techs/）", 12, UiPalette.DIM))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size.x = PANEL_WIDTH
	row.add_child(right)
	_name = _label("", 20, UiPalette.FG)
	right.add_child(_name)
	right.add_child(HSeparator.new())
	right.add_child(_label("效果", 13, UiPalette.DIM))
	_effect = _vbox(4)
	right.add_child(_effect)
	right.add_child(HSeparator.new())
	right.add_child(_label("费用", 13, UiPalette.DIM))
	_cost = _vbox(4)
	right.add_child(_cost)
	_action = Button.new()
	UiPalette.style_button(_action, UiPalette.Tier.PRIMARY, UiPalette.button_font_size(14, UiPalette.Tier.PRIMARY))
	_action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_action.pressed.connect(func(): upgrade(_selected))
	right.add_child(_action)
	right.add_child(HSeparator.new())

	right.add_child(_label("上交区　交给选中的节点：拖进来或在仓库里双击（上交即消耗，交了不能退）", 13, UiPalette.DIM))
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
	_warehouse_toggle = Button.new()
	_warehouse_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_warehouse_toggle.pressed.connect(toggle_warehouse)
	right.add_child(_warehouse_toggle)
	_warehouse_view = InventoryView.new()
	_warehouse_view.label_font = _font
	_warehouse_view.inventory = _meta.warehouse
	_warehouse_view.show_adjacency = false
	_warehouse_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_warehouse_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): submit(uid))
	_warehouse_box = ScrollBox.wrap(_warehouse_view, 6)
	_warehouse_box.visible = false     # 默认收起，点开才占地方
	right.add_child(_warehouse_box)

	_drag = DragLayer.new()
	_drag.label_font = _font
	add_child(_drag)     # 铺满，盖在仓库与上交区上
	_drag.register_view(_warehouse_view)
	_drag.register_view(_zone_view)
	_drag.drag_finished.connect(_on_drag_finished)


#region 公开动作
## 选中一个节点（右板切到它）。没有这项返回 false
func select(id: StringName) -> bool:
	if _flow.tech_of(id) == null:
		return false
	if _tree.selected_id() != id:
		return _tree.select(id)     # 树会发 selected，回到 _on_tree_selected
	_selected = id
	_refresh()
	return true


func selected() -> StringName:
	return _selected


## 交仓库里的一件给**选中的节点**。返回交没交成
func submit(uid: int) -> bool:
	var inst := _meta.warehouse.get_item(uid)
	if inst == null:
		return false
	var def := _flow.tech_of(_selected)
	if def == null:
		_line.text = "先在左边选一个科技"
		return false
	if not TechService.prereqs_met(_meta, def):
		_line.text = "「%s」还锁着：先点亮前置" % Names.of(def)
		return false
	if not TechService.can_submit(_meta, def, inst.def):
		_line.text = "「%s」不是它下一级要的" % Names.of(inst.def)
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
		_line.text = "%s %s" % [Names.of(def), "点亮了" if def.max_level() <= 1 else "升到 Lv %d" % TechService.level(_meta, id)]
		changed.emit()
	return ok


## 【点亮 / 升级】按钮 —— 只有选中的那个节点有（测试看）；不是选中的 null
func upgrade_button(id: StringName) -> Button:
	return _action if id == _selected and _action.visible else null


## 右板三区的文字（测试看）：{name, effect, cost}
func panel_texts() -> Dictionary:
	return {"name": _name.text, "effect": _texts_of(_effect), "cost": _texts_of(_cost)}


func toggle_warehouse() -> void:
	_warehouse_box.visible = not _warehouse_box.visible
	_sync_toggle()


func tree() -> TechTreeView:
	return _tree


func line_text() -> String:
	return _line.text


func zone() -> GridInventory:
	return _zone


func drag_layer() -> DragLayer:
	return _drag
#endregion


## 一开始选谁：第一个能点的（前置满足、没满级）；都不能就第一个
func _default_selection() -> StringName:
	for def in _flow.tech_defs:
		if TechService.prereqs_met(_meta, def) and TechService.next_tier(_meta, def) != null:
			return def.id
	return _flow.tech_defs[0].id if not _flow.tech_defs.is_empty() else &""


func _on_tree_selected(id: StringName) -> void:
	_selected = id
	_line.text = ""
	_refresh()


## 上交区收不收这件：选中的节点前置满足、下一级还差它
func _wanted(item_def: ItemDef) -> bool:
	var def := _flow.tech_of(_selected)
	return def != null and TechService.prereqs_met(_meta, def) and TechService.can_submit(_meta, def, item_def)


## 上交区里落进来的：记给选中的节点、拿走（东西已离开仓库，只差记一笔）
func _on_zone_changed() -> void:
	var def := _flow.tech_of(_selected)
	for inst in _zone.items():
		var it := inst as ItemInstance
		if def == null or not TechService.can_submit(_meta, def, it.def):
			continue     # 不该发生（accept_filter 拦着）；留在区里，拖走即回仓库
		_zone.remove(it.uid)
		if TechService.deposit(_meta, def, it.def):
			_flow.save_meta()
			_line.text = "交了「%s」" % Names.of(it.def)
			changed.emit()


## 拖到上交区却没放进去 = 这件不是选中节点下一级要的：说一句
func _on_drag_finished(uid: int, dropped: bool) -> void:
	if dropped:
		return
	var inst := _meta.warehouse.get_item(uid)
	if inst != null and DragLayer.visible_rect(_zone_view).has_point(_zone_view.get_global_mouse_position()):
		var def := _flow.tech_of(_selected)
		_line.text = "先在左边选一个科技" if def == null else "「%s」不是它下一级要的" % Names.of(inst.def)


func _refresh() -> void:
	if _tree == null:
		return
	_tree.rebuild()     # 等级变了节点样子跟着变；选中的那圈边 rebuild 时照旧画
	_sync_toggle()
	_clear(_effect)
	_clear(_cost)
	var def := _flow.tech_of(_selected)
	_zone_view.modulate = Color(1, 1, 1, 1) if def != null and TechService.prereqs_met(_meta, def) and TechService.next_tier(_meta, def) != null \
		else Color(1, 1, 1, 0.35)     # 没选 / 锁住 / 满级：上交区灰着
	if def == null:
		_name.text = "（选一个科技）"
		_action.visible = false
		return
	var lv := TechService.level(_meta, def.id)
	var tier := TechService.next_tier(_meta, def)
	_name.text = "%s　%s" % [Names.of(def), TechTreeView.level_text(_meta, def)]

	# 效果：一句总述 + 现在 / 下一级
	if def.description.strip_edges() != "":
		_effect.add_child(_wrapped(TextTemplate.plain(def.description, {}), 14, UiPalette.FG))
	if def.effect != null:
		if lv >= 1:
			_effect.add_child(_wrapped("现在：" + def.effect.describe_level(lv, _flow.buff_defs), 13, UiPalette.HEAL))
		if tier != null:
			_effect.add_child(_wrapped("下一级：" + def.effect.describe_level(lv + 1, _flow.buff_defs), 13, UiPalette.FG))

	# 费用
	if tier == null:
		_cost.add_child(_label("已满级", 14, UiPalette.HEAL))
		_action.visible = false
		return
	var missing := TechService.missing_prereqs(_meta, def, _flow.tech_defs)
	if not missing.is_empty():
		var names: Array[String] = []
		for m in missing:
			names.append(Names.of(m))
		_cost.add_child(_wrapped("需要先点亮：%s" % "、".join(names), 13, UiPalette.DIM))
	var rich := _meta.funds >= tier.funds
	_cost.add_child(_label("钱　需要 %d / 持有 %d" % [tier.funds, _meta.funds], 13, UiPalette.HEAL if rich else UiPalette.DIM))
	var keys: Array = tier.items.keys()
	keys.sort()
	for key in keys:
		var need := int(tier.items[key])
		var have := TechService.deposited(_meta, def.id, StringName(String(key)))
		var item_def := _flow.items.get_def(StringName(String(key))) if _flow.items != null else null
		var name := Names.of(item_def) if item_def != null else String(key)
		_cost.add_child(_label("%s　已交 %d / 需要 %d%s" % [name, have, need, "　✓" if have >= need else ""], 13,
			UiPalette.HEAL if have >= need else UiPalette.FG))
	_action.visible = true
	_action.text = "点亮" if def.max_level() <= 1 else "升级"     # 单级「点亮」、多级「升级」
	_action.disabled = not TechService.ready(_meta, def)


func _sync_toggle() -> void:
	_warehouse_toggle.text = ("仓库 ▾　（双击一件交给选中的节点）" if _warehouse_box.visible else "仓库 ▸　展开")


static func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


static func _texts_of(box: Container) -> String:
	var parts: Array[String] = []
	for c in box.get_children():
		if c is Label:
			parts.append((c as Label).text)
	return "\n".join(parts)


func _vbox(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.label(l, font_size, color)     # 121：字体在主题里，颜色先选变体
	return l


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = PANEL_WIDTH
	return l
